"""
BloodConnect AI Service  v3.0.1 (Production)
================================
Complete 3-stage pipeline:
  Stage 1: ViT classifier  → Normal / Abnormal
  Stage 2: OCR + CBC parser → abnormal_findings (only when Abnormal)
  Stage 3: Donor eligibility → ELIGIBLE / DEFERRED + bilingual reasons

POST /predict            -- main endpoint (Flutter calls this)
POST /api/v1/screen-report -- alias
POST /assistant/chat     -- conversational AI (OpenRouter)
GET  /health
GET  /status            -- debugging
"""

from pathlib import Path
import io
import os
import json
import re
import cv2
import numpy as np
import requests
from contextlib import asynccontextmanager

import torch
from torchvision import transforms
from PIL import Image
import pytesseract

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────────────────────────────────────
# Tesseract Configuration (WINDOWS)
# ─────────────────────────────────────────────────────────────────────────────

TESSERACT_PATHS = [
    r'C:\Program Files\Tesseract-OCR\tesseract.exe',
    r'C:\Program Files (x86)\Tesseract-OCR\tesseract.exe',
    '/usr/bin/tesseract',
    '/usr/local/bin/tesseract',
]

TESSERACT_FOUND = False
for tess_path in TESSERACT_PATHS:
    if os.path.exists(tess_path):
        pytesseract.pytesseract.pytesseract_cmd = tess_path
        TESSERACT_FOUND = True
        print(f"[OK] Tesseract: {tess_path}")
        break

if not TESSERACT_FOUND:
    print("[WARN] Tesseract not found. Install from: https://github.com/UB-Mannheim/tesseract/wiki")

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

VIT_WEIGHTS_PATH = os.getenv(
    "VIT_WEIGHTS_PATH",
    str(Path(__file__).parent / "model_VIT" / "cbc_vit_best.pt")
)

IMG_SIZE = 224
VIT_THRESHOLD = 0.50

MALE_MIN_HB = 13.5
FEMALE_MIN_HB = 12.5
MALE_MAX_HB = 17.5
FEMALE_MAX_HB = 16.0

print(f"[CONFIG] ViT weights: {Path(VIT_WEIGHTS_PATH).resolve()}")
print(f"[CONFIG] Weights exist: {Path(VIT_WEIGHTS_PATH).exists()}")

# ─────────────────────────────────────────────────────────────────────────────
# Image transforms
# ─────────────────────────────────────────────────────────────────────────────

VAL_TRANSFORM = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                         std=[0.229, 0.224, 0.225]),
])

# ─────────────────────────────────────────────────────────────────────────────
# OCR Helpers (with bug fixes from production code)
# ─────────────────────────────────────────────────────────────────────────────

def extract_text(pil_image: Image.Image) -> str:
    """Run Tesseract OCR on PIL image in memory."""
    try:
        img_np = np.array(pil_image.convert("RGB"))
        gray = cv2.cvtColor(img_np, cv2.COLOR_RGB2GRAY)
        _, gray = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)
        text = pytesseract.image_to_string(gray)
        if not text.strip():
            print("[WARN] Tesseract returned empty string")
            return ""
        return text
    except Exception as e:
        print(f"[ERROR] OCR extraction failed: {e}")
        raise


def normalise_ocr(text: str) -> str:
    """Fix common Tesseract misreads (BUG-A, BUG-B)."""
    # BUG-B: decimal comma → decimal point
    text = re.sub(r"(\d),(\d)", r"\1.\2", text)
    # BUG-A: garbled unit separator
    text = re.sub(r"\bg[il|]dL\b", "g/dL", text, flags=re.I)
    return text


def safe_pct_value(token: str):
    """BUG-C: Validate percentage tokens (strip noise, validate 0-100)."""
    cleaned = re.sub(r"[^0-9.]", "", token)
    try:
        v = float(cleaned) if cleaned else None
        return v if v is not None and 0.0 <= v <= 100.0 else None
    except ValueError:
        return None


# ─────────────────────────────────────────────────────────────────────────────
# CBC Parser (with all bug fixes)
# ─────────────────────────────────────────────────────────────────────────────

DIFF_CELLS = ["neutrophils", "lymphocytes", "monocytes",
              "eosinophils", "basophils", "stab", "segmented"]

CELL_NAME_PATTERNS = {
    "neutrophils": r"Neutrophils",
    "lymphocytes": r"Lymphocytes",
    "monocytes":   r"Monocytes",
    "eosinophils": r"Eosinophils",
    "basophils":   r"Basophils",
    "stab":        r"Stab",
    "segmented":   r"Segmented",
}


def _line_for(cell_key: str, text: str) -> str:
    pat = CELL_NAME_PATTERNS[cell_key]
    m = re.search(rf"^.*{pat}.*$", text, re.IGNORECASE | re.MULTILINE)
    return m.group(0) if m else ""


def _extract_pct_and_abs(line: str):
    """
    Parse differential row → (pct_value, abs_value).
    BUG-F: Remove ref-range patterns before extracting absolute values.
    """
    pct_val = abs_val = None

    pct_match = re.search(r"([A-Za-z0-9.]+)\s*%", line)
    if pct_match:
        pct_val = safe_pct_value(pct_match.group(1))

    after_pct = line[pct_match.end():] if pct_match else line
    # Remove unit strings like "x10³/µL"
    after_pct = re.sub(r"x10[^a-zA-Z\s]*[uµ]?[Ll]?", " ", after_pct, flags=re.I)
    # BUG-F: Remove ref-range patterns "N-N"
    after_pct = re.sub(r"\d+\.?\d*\s*-\s*\d+\.?\d*", " ", after_pct)

    abs_candidates = [float(t) for t in re.findall(r"\d+\.\d+|\d+", after_pct)
                      if 0.0 < float(t) < 20.0]
    if abs_candidates:
        decimals = [v for v in abs_candidates if v != int(v)]
        abs_val = decimals[0] if decimals else abs_candidates[0]

    if pct_val is None and abs_val is None:
        all_nums = [float(t) for t in re.findall(r"\d+\.?\d*", line) if 0 < float(t) < 200]
        large = [n for n in all_nums if n > 1.0]
        small = [n for n in all_nums if 0 < n < 20]
        if large:
            pct_val = max(large)
        candidates = [n for n in small if n != pct_val]
        if candidates:
            abs_val = min(candidates)

    return pct_val, abs_val


def parse_cbc(raw_text: str):
    """Return (rbc_indices, diff_pct, diff_abs) dicts."""
    text = normalise_ocr(raw_text)

    def first_float(pattern):
        m = re.search(pattern, text, re.IGNORECASE)
        if not m:
            return None
        try:
            return float(m.group(1).replace(",", "."))
        except ValueError:
            return None

    # BUG-E: Use \s+ (one-or-more space) between name and value
    rbc_indices = {
        "haemoglobin":    first_float(r"H[ae]{1,2}m[oa]globin\s+(\d+\.?\d*)"),
        "hematocrit":     first_float(r"H[ae]{1,2}matocrit(?:\s*\(PCV\))?\s+(\d+\.?\d*)"),
        "rbc_count":      first_float(r"(?:RBC[s]?\s*Count|Red\s*cell\s*count)\s+(\d+\.?\d*)"),
        "MCV":            first_float(r"MCV\s+(\d+\.?\d*)"),
        "MCH":            first_float(r"\bMCH\b\s+(\d+\.?\d*)"),
        "MCHC":           first_float(r"MCHC\s+(\d+\.?\d*)"),
        "RDW":            first_float(r"RDW(?:-CV)?\s+(\d+\.?\d*)"),
        "platelet_count": first_float(r"Platelet(?:s)?\s*(?:Count)?\s*(?:\([^)]*\))?\s+(\d+\.?\d*)"),
        "TLC":            first_float(r"(?:T\.?L\.?C|Total\s+Leuc[oa]cytic\s+Count(?:\s*\([^)]*\))?|WBC)\s+(\d+\.?\d*)"),
    }

    diff_pct, diff_abs = {}, {}
    for cell in DIFF_CELLS:
        line = _line_for(cell, text)
        diff_pct[cell], diff_abs[cell] = _extract_pct_and_abs(line)

    # BUG-D: Use Segmented as neutrophil proxy
    if diff_pct.get("neutrophils") is None and diff_pct.get("segmented") is not None:
        diff_pct["neutrophils"] = diff_pct["segmented"]
    if diff_abs.get("neutrophils") is None and diff_abs.get("segmented") is not None:
        diff_abs["neutrophils"] = diff_abs["segmented"]

    return rbc_indices, diff_pct, diff_abs


# ─────────────────────────────────────────────────────────────────────────────
# Reference ranges & labels
# ─────────────────────────────────────────────────────────────────────────────

RANGES_RBC = {
    "haemoglobin":    (11.5, 17.0),
    "hematocrit":     (36.0, 50.0),
    "rbc_count":      (4.0,  6.2),
    "MCV":            (78.0, 100.0),
    "MCH":            (26.0, 33.0),
    "MCHC":           (31.0, 37.0),
    "RDW":            (11.5, 15.0),
    "platelet_count": (150,  450),
    "TLC":            (4.0,  11.0),
}

RANGES_DIFF_ABS = {
    "neutrophils": (2.0,  7.0),
    "lymphocytes": (1.0,  4.8),
    "monocytes":   (0.2,  1.0),
    "eosinophils": (0.0,  0.6),
    "basophils":   (0.0,  0.11),
}

RANGES_DIFF_PCT = {
    "neutrophils": (40.0, 75.0),
    "lymphocytes": (20.0, 45.0),
    "monocytes":   (1.0,  10.0),
    "eosinophils": (0.0,  6.0),
    "basophils":   (0.0,  1.0),
}

FEATURE_LABELS = {
    "haemoglobin": "Haemoglobin", "hematocrit": "Hematocrit (PCV)",
    "rbc_count": "Red Cell Count", "MCV": "MCV", "MCH": "MCH",
    "MCHC": "MCHC", "RDW": "RDW", "platelet_count": "Platelet Count",
    "TLC": "Total WBC Count", "neutrophils": "Neutrophils",
    "lymphocytes": "Lymphocytes", "monocytes": "Monocytes",
    "eosinophils": "Eosinophils", "basophils": "Basophils",
}

FEATURE_UNITS = {
    "haemoglobin": "g/dL", "hematocrit": "%", "rbc_count": "×10⁶/µL",
    "MCV": "fL", "MCH": "pg", "MCHC": "g/dL", "RDW": "%",
    "platelet_count": "×10³/µL", "TLC": "×10³/µL",
    "neutrophils": "×10⁹/L", "lymphocytes": "×10⁹/L",
    "monocytes": "×10⁹/L", "eosinophils": "×10⁹/L", "basophils": "×10⁹/L",
}


# ─────────────────────────────────────────────────────────────────────────────
# Rule engine - produces findings in exact format user expects
# ─────────────────────────────────────────────────────────────────────────────

def _check(metrics: dict, ranges: dict, value_label: str, unit: str = "") -> list:
    """Check metrics against ranges. Returns list of issues."""
    issues = []
    for k, v in metrics.items():
        if v is None or k not in ranges:
            continue
        low, high = ranges[k]
        status = None
        if v < low:
            status = "LOW"
        elif v > high:
            status = "HIGH"
        
        if status:
            issues.append({
                "feature": k,
                "label": FEATURE_LABELS.get(k, k),
                "value": round(v, 2) if isinstance(v, float) else v,
                "unit": FEATURE_UNITS.get(k, unit),
                "value_type": value_label,
                "status": status,
                "range": [low, high],
            })
    return issues


def analyze_all(rbc_indices, diff_pct, diff_abs) -> list:
    """Analyze all CBC metrics. Returns list of abnormal findings."""
    issues = []
    issues += _check(rbc_indices, RANGES_RBC, "absolute")
    issues += _check(diff_abs, RANGES_DIFF_ABS, "absolute (×10⁹/L)", "×10⁹/L")
    issues += _check(diff_pct, RANGES_DIFF_PCT, "percentage (%)", "%")
    return issues


# ─────────────────────────────────────────────────────────────────────────────
# Donor eligibility engine
# ─────────────────────────────────────────────────────────────────────────────

def run_donor_evaluation(rbc_indices: dict, diff_pct: dict, gender: str = "male") -> dict:
    """Evaluate donor eligibility from CBC values."""
    is_deferred = False
    reasons_en = []
    reasons_ar = []

    hb_min = FEMALE_MIN_HB if gender.lower() == "female" else MALE_MIN_HB
    hb_max = FEMALE_MAX_HB if gender.lower() == "female" else MALE_MAX_HB

    hb = rbc_indices.get("haemoglobin")
    if hb is None:
        is_deferred = True
        reasons_en.append("Haemoglobin not extracted — manual review required.")
        reasons_ar.append("لم يتم استخراج الهيموجلوبين — يلزم المراجعة اليدوية.")
    elif hb < hb_min:
        is_deferred = True
        reasons_en.append(f"Haemoglobin ({hb} g/dL) below safe minimum ({hb_min}) for {gender}.")
        reasons_ar.append(f"الهيموجلوبين ({hb}) أقل من الحد الآمن ({hb_min}).")
    elif hb > hb_max:
        is_deferred = True
        reasons_en.append(f"Haemoglobin ({hb} g/dL) exceeds safe maximum ({hb_max}).")
        reasons_ar.append(f"الهيموجلوبين ({hb}) يتجاوز الحد الأقصى ({hb_max}).")

    tlc = rbc_indices.get("TLC")
    if tlc is not None:
        if tlc < 4.5 or tlc > 10.5:
            is_deferred = True
            issue = "below" if tlc < 4.5 else "above"
            reasons_en.append(f"TLC ({tlc}) is {issue} normal range.")
            reasons_ar.append(f"عدد خلايا الدم البيضاء ({tlc}) {issue} المعدل.")

    plt = rbc_indices.get("platelet_count")
    if plt is not None:
        if plt < 150 or plt > 400:
            is_deferred = True
            issue = "below" if plt < 150 else "exceeds"
            reasons_en.append(f"Platelet count ({plt}) {issue} safe range.")
            reasons_ar.append(f"عدد الصفيحات ({plt}) {issue} المعدل الآمن.")

    status = "DEFERRED" if is_deferred else "ELIGIBLE"
    
    if status == "ELIGIBLE":
        explanation_en = "All CBC parameters within acceptable ranges."
        explanation_ar = "جميع المعايير ضمن النطاقات المقبولة."
    else:
        explanation_en = "Temporary deferral: " + "; ".join(reasons_en)
        explanation_ar = "تأجيل مؤقت: " + "; ".join(reasons_ar)

    return {
        "status": status,
        "reasons": reasons_en,
        "reasons_ar": reasons_ar,
        "explanation_en": explanation_en,
        "explanation_ar": explanation_ar,
        "gender": gender,
    }


# ─────────────────────────────────────────────────────────────────────────────
# ViT Model
# ─────────────────────────────────────────────────────────────────────────────

vit_model = None
vit_device = None


class MedicalViT(torch.nn.Module):
    def __init__(self, num_classes=2, num_reg=15):
        super().__init__()
        import timm
        self.backbone = timm.create_model(
            "vit_base_patch16_224", pretrained=False, num_classes=0,
        )
        embed_dim = self.backbone.num_features

        self.cls_head = torch.nn.Sequential(
            torch.nn.LayerNorm(embed_dim),
            torch.nn.Dropout(0.3),
            torch.nn.Linear(embed_dim, 256),
            torch.nn.ReLU(inplace=True),
            torch.nn.Dropout(0.3),
            torch.nn.Linear(256, num_classes),
        )

        self.reg_head = torch.nn.Sequential(
            torch.nn.LayerNorm(embed_dim),
            torch.nn.Dropout(0.3),
            torch.nn.Linear(embed_dim, 512),
            torch.nn.ReLU(inplace=True),
            torch.nn.Dropout(0.3),
            torch.nn.Linear(512, 256),
            torch.nn.Dropout(0.3),
            torch.nn.Linear(256, num_reg),
        )

    def forward(self, x):
        features = self.backbone(x)
        cls_out = self.cls_head(features)
        return cls_out, None


def load_vit_model():
    global vit_model, vit_device
    vit_device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"[ViT] Device: {vit_device}")

    weights_path = Path(VIT_WEIGHTS_PATH)
    print(f"[ViT] Path: {weights_path.resolve()}")
    
    if not weights_path.exists():
        raise FileNotFoundError(f"Weights not found: {weights_path.resolve()}")

    try:
        checkpoint = torch.load(str(weights_path), map_location=vit_device, weights_only=False)
    except Exception as e:
        raise RuntimeError(f"Failed to load checkpoint: {e}")

    if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
        state_dict = checkpoint["model_state_dict"]
    elif isinstance(checkpoint, dict) and "state_dict" in checkpoint:
        state_dict = checkpoint["state_dict"]
    else:
        state_dict = checkpoint

    model = MedicalViT()
    filtered = {}
    for k, v in state_dict.items():
        if k.startswith("backbone.") or k.startswith("cls_head.") or k.startswith("reg_head."):
            filtered[k] = v

    missing, unexpected = model.load_state_dict(filtered, strict=False)
    print(f"[ViT] Loaded {len(filtered)} keys | Missing: {len(missing)} | Unexpected: {len(unexpected)}")

    model.to(vit_device)
    model.eval()
    vit_model = model
    print("[ViT] OK Loaded")


# ─────────────────────────────────────────────────────────────────────────────
# FastAPI App
# ─────────────────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("[STARTUP] Loading models...")
    testing = os.getenv("TESTING", "false").lower() == "true"
    if not testing:
        try:
            load_vit_model()
            print("[STARTUP] OK Ready")
        except Exception as e:
            print(f"[STARTUP] FAIL Failed: {e}")
            raise
    else:
        print("[STARTUP] Testing mode")
    yield
    print("[SHUTDOWN] Cleanup")


app = FastAPI(
    title="BloodConnect AI Service",
    version="3.0.1",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.environ.get("CORS_ORIGINS", "*").split(",") if os.environ.get("CORS_ORIGINS") else ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {
        "status": "ONLINE",
        "vit_loaded": vit_model is not None,
        "vit_model_loaded": vit_model is not None,
        "model_loaded": vit_model is not None,
        "device": str(vit_device),
        "weights_exist": Path(VIT_WEIGHTS_PATH).exists(),
        "tesseract_found": TESSERACT_FOUND,
        "version": "3.0.1",
    }


@app.get("/status")
def status():
    return {
        "service": "BloodConnect AI v3.0.1",
        "vit_loaded": vit_model is not None,
        "device": str(vit_device),
        "weights": str(Path(VIT_WEIGHTS_PATH).resolve()),
        "tesseract": TESSERACT_FOUND,
    }


@app.post("/predict")
@app.post("/api/v1/screen-report")
async def predict(
    file: UploadFile = File(...),
    gender: str = Form(default="male"),
):
    """
    Main prediction endpoint.
    
    Stage 1: ViT classification (Normal/Abnormal)
    Stage 2: OCR + CBC parsing (only if Abnormal)
    Stage 3: Donor eligibility evaluation
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Upload valid image (JPEG/PNG).")

    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="File is empty.")

    try:
        pil_image = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid image: {exc}")

    if vit_model is None:
        raise HTTPException(status_code=503, detail="ViT model not loaded.")

    # ────────────────────────────────────────────────────────────────────────
    # STAGE 1: ViT Classification
    # ────────────────────────────────────────────────────────────────────────
    try:
        tensor = VAL_TRANSFORM(pil_image).unsqueeze(0).to(vit_device)
        with torch.no_grad():
            logits = vit_model(tensor)
            if isinstance(logits, tuple):
                logits = logits[0]
            probs = torch.softmax(logits, dim=1)[0]
            pred = torch.argmax(probs).item()
            conf = float(probs[pred]) * 100
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ViT inference failed: {e}")

    vit_label = "Abnormal" if pred == 1 else "Normal"

    # Build base response
    response = {
        "success": True,
        "prediction": vit_label,
        "confidence": round(conf, 2),
        "eligible": vit_label == "Normal",
        "result": "ELIGIBLE" if vit_label == "Normal" else "DEFERRED",
        "raw_probability": round(float(probs[1]), 4),
        "threshold": VIT_THRESHOLD,
        "abnormal_findings": [],
        "metrics": {},
        "evaluation": {
            "status": "ELIGIBLE" if vit_label == "Normal" else "DEFERRED",
            "explanation_en": "ViT indicates normal CBC profile.",
            "explanation_ar": "يشير المصنف إلى صورة دم طبيعية.",
            "gender": gender,
        },
        "reasons": [],
    }

    if vit_label == "Normal":
        return response

    # ────────────────────────────────────────────────────────────────────────
    # STAGE 2: OCR + CBC Parsing (only when Abnormal)
    # ────────────────────────────────────────────────────────────────────────
    try:
        ocr_text = extract_text(pil_image)
        rbc_indices, diff_pct, diff_abs = parse_cbc(ocr_text)
        findings = analyze_all(rbc_indices, diff_pct, diff_abs)
    except Exception as e:
        print(f"[WARN] OCR failed: {e}")
        ocr_text = ""
        rbc_indices = {}
        diff_pct = {}
        diff_abs = {}
        findings = []

    # ────────────────────────────────────────────────────────────────────────
    # STAGE 3: Donor Eligibility Evaluation
    # ────────────────────────────────────────────────────────────────────────
    eval_result = run_donor_evaluation(rbc_indices, diff_pct, gender=gender)

    flat_metrics = {**rbc_indices}
    for k, v in diff_pct.items():
        if v is not None:
            flat_metrics[f"{k}_pct"] = v
    for k, v in diff_abs.items():
        if v is not None:
            flat_metrics[f"{k}_abs"] = v

    # ────────────────────────────────────────────────────────────────────────
    # Final Response
    # ────────────────────────────────────────────────────────────────────────
    response.update({
        "eligible": eval_result["status"] == "ELIGIBLE",
        "result": eval_result["status"],
        "abnormal_findings": findings,  # List of {feature, label, value, unit, status, range}
        "ocr_text": ocr_text[:500] if ocr_text else "",
        "metrics": {
            "rbc_indices": rbc_indices,
            "differential_pct": diff_pct,
            "differential_abs": diff_abs,
        },
        "reasons": eval_result["reasons"],
        "evaluation": {
            "status": eval_result["status"],
            "explanation_en": eval_result["explanation_en"],
            "explanation_ar": eval_result["explanation_ar"],
            "gender": gender,
        },
    })

    return response


# ─────────────────────────────────────────────────────────────────────────────
# AI Assistant (OpenRouter)
# ─────────────────────────────────────────────────────────────────────────────

OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_MODEL = "google/gemini-2.5-flash"


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    donor_data: dict


@app.post("/assistant/chat")
async def assistant_chat(request: ChatRequest):
    """Conversational AI for explaining results."""
    api_key = os.environ.get("AI_ASSISTANT_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="AI assistant not configured.")

    messages = [{"role": m.role, "content": m.content} for m in request.messages]

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": OPENROUTER_MODEL,
        "messages": messages,
        "max_tokens": 800,
        "temperature": 0.7,
    }

    try:
        resp = requests.post(OPENROUTER_API_URL, headers=headers, json=payload, timeout=30)
        resp.raise_for_status()
        reply = resp.json()["choices"][0]["message"]["content"].strip()
        return {"reply": reply}
    except Exception as e:
        print(f"[ERROR] OpenRouter: {e}")
        raise HTTPException(status_code=502, detail="AI assistant unavailable.")


# ─────────────────────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
