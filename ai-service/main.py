"""
BloodConnect AI Service  v3.0.2 (Production)
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

Architecture note:
  CBCViT matches the training notebook (Cell 6) exactly:
    - cls_head: LayerNorm → Dropout(0.3) → Linear(768,256) → GELU → Dropout(0.2) → Linear(256,2)
    - reg_head: LayerNorm → Dropout(0.3) → Linear(768,512) → GELU → Dropout(0.2) → Linear(512,256) → GELU → Linear(256,15)
"""

from pathlib import Path
import io
import os
import json
import re
import cv2
import hashlib
import time
import logging
import numpy as np
import requests
from contextlib import asynccontextmanager
from prompts import pick_variant, ab_variant_stats

import torch
import torch.nn as nn
from torchvision import transforms
from PIL import Image
import pytesseract

from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from pydantic import BaseModel, Field
from dotenv import load_dotenv

logger = logging.getLogger("bloodconnect-ai")

load_dotenv()

# ─────────────────────────────────────────────────────────────────────────────
# Tesseract Configuration (WINDOWS / LINUX)
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
        pytesseract.pytesseract.tesseract_cmd = tess_path
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

MALE_MIN_HB   = 13.5
FEMALE_MIN_HB = 12.5
MALE_MAX_HB   = 17.5
FEMALE_MAX_HB = 16.0

print(f"[CONFIG] ViT weights: {Path(VIT_WEIGHTS_PATH).resolve()}")
print(f"[CONFIG] Weights exist: {Path(VIT_WEIGHTS_PATH).exists()}")

# ─────────────────────────────────────────────────────────────────────────────
# Image transforms (identical to notebook VAL_TRANSFORM)
# ─────────────────────────────────────────────────────────────────────────────

VAL_TRANSFORM = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                         std=[0.229, 0.224, 0.225]),
])

# ─────────────────────────────────────────────────────────────────────────────
# OCR Helpers
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


# ─────────────────────────────────────────────────────────────────────────────
# PII Redaction (A1)
# ─────────────────────────────────────────────────────────────────────────────

_PII_PATTERNS = [
    (r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b", "[IP_REDACTED]"),           # IP
    (r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b", "[EMAIL_REDACTED]"),  # email
    (r"(?:\+\d{1,3}\s?)?\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b", "[PHONE_REDACTED]"),   # phone (with optional country code)
    (r"\b\d{9,12}\b", "[ID_REDACTED]"),                                       # numeric ID
    (r"\b(?:M|F|Mr|Mrs|Ms|Dr|Prof)\.?\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b", "[NAME_REDACTED]"),  # name prefix
    (r"\b\d{1,2}/\d{1,2}/(?:\d{2}|\d{4})\b", "[DATE_REDACTED]"),             # date
]


def redact_pii(text: str) -> str:
    """Strip PII (IPs, emails, phones, IDs, names, dates) from text."""
    for pat, replacement in _PII_PATTERNS:
        text = re.sub(pat, replacement, text)
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
# Plausibility clamp — fixes OCR decimal-drop errors (e.g. "316" → 31.6)
# ─────────────────────────────────────────────────────────────────────────────

# Physiological limits: values outside these are OCR misreads, not real results.
_PLAUSIBLE = {
    "haemoglobin":    (4.0,   25.0),
    "hematocrit":     (10.0,  70.0),
    "rbc_count":      (1.0,   10.0),
    "MCV":            (50.0,  130.0),
    "MCH":            (10.0,  50.0),
    "MCHC":           (20.0,  45.0),   # e.g. "316" → 31.6
    "RDW":            (5.0,   30.0),
    "platelet_count": (10.0,  2000.0), # wide range — don't auto-fix
    "TLC":            (0.5,   30.0),   # e.g. "49" → 4.9
}

def _plausibility_fix(key: str, value):
    """
    If extracted value is outside physiological range, try dividing by 10.
    Returns fixed value, or None if still implausible (triggers NEEDS_REVIEW).
    """
    if value is None or key not in _PLAUSIBLE:
        return value
    lo, hi = _PLAUSIBLE[key]
    if lo <= value <= hi:
        return value
    fixed = round(value / 10, 2)
    if lo <= fixed <= hi:
        print(f"[PLAUSIBILITY] {key}: {value} → {fixed} (OCR dropped decimal)")
        return fixed
    print(f"[PLAUSIBILITY] {key}: {value} implausible even after /10 → None")
    return None


# ─────────────────────────────────────────────────────────────────────────────
# CBC Parser
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
        "haemoglobin":    first_float(r"H[ae]{1,2}m[oa]globin(?:\s*\([^)]*\))?\s+(\d+\.?\d*)"),
        "hematocrit":     first_float(r"H[ae]{1,2}matocrit(?:\s*\([^)]*\))?\s+(\d+\.?\d*)"),
        "rbc_count":      first_float(r"(?:RBC[s]?\s*Count|Red\s*cell\s*count)(?:\s*\([^)]*\))?\s+(\d+\.?\d*)"),
        "MCV":            first_float(r"MCV\s+(\d+\.?\d*)"),
        "MCH":            first_float(r"\bMCH\b\s+(\d+\.?\d*)"),
        "MCHC":           first_float(r"MCHC\s+(\d+\.?\d*)"),
        "RDW":            first_float(r"RDW(?:-CV)?\s+(\d+\.?\d*)"),
        "platelet_count": first_float(r"Platelet(?:s)?\s*(?:Count)?\s*(?:\([^)]*\))?\s+(\d+\.?\d*)"),
        "TLC":            first_float(r"(?:T\.?L\.?C|Total\s+Leuc[oa]cytic\s+Count(?:\s*\([^)]*\))?|WBC)\s+(\d+\.?\d*)"),
    }
    # Apply plausibility fix to catch OCR decimal-drop errors (e.g. "316"→31.6, "49"→4.9)
    rbc_indices = {k: _plausibility_fix(k, v) for k, v in rbc_indices.items()}

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
# Rule engine
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
    issues += _check(diff_abs,    RANGES_DIFF_ABS, "absolute (×10⁹/L)", "×10⁹/L")
    issues += _check(diff_pct,    RANGES_DIFF_PCT, "percentage (%)",     "%")
    return issues


# ─────────────────────────────────────────────────────────────────────────────
# Donor eligibility engine
# ─────────────────────────────────────────────────────────────────────────────

def run_donor_evaluation(rbc_indices: dict, diff_pct: dict, gender: str = "male") -> dict:
    """Evaluate donor eligibility from CBC values."""
    is_deferred = False
    reasons_en  = []
    reasons_ar  = []

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
        "status":         status,
        "reasons":        reasons_en,
        "reasons_ar":     reasons_ar,
        "explanation_en": explanation_en,
        "explanation_ar": explanation_ar,
        "gender":         gender,
    }


# ─────────────────────────────────────────────────────────────────────────────
# CBCViT Model — EXACT match to notebook Cell 6
# ─────────────────────────────────────────────────────────────────────────────

class CBCViT(nn.Module):
    """
    ViT-B/16 backbone with two task heads.

    Architecture
    ─────────────
    image (3×224×224)
      └─ ViT-B/16 → [CLS] token (d=768)
            ├─ cls_head  → 2   (Normal / Abnormal)
            └─ reg_head  → 15  (CBC metric values)

    CBC fields (in order):
        haemoglobin, hematocrit, red_cell_count,
        MCV, MCH, MCHC, RDW,
        platelet_count, TLC,
        neutrophils, lymphocytes, monocytes,
        eosinophils, basophils, segmented
    """

    CBC_FIELDS = [
        "haemoglobin", "hematocrit", "red_cell_count",
        "MCV", "MCH", "MCHC", "RDW",
        "platelet_count", "TLC",
        "neutrophils", "lymphocytes", "monocytes",
        "eosinophils", "basophils", "segmented",
    ]
    NUM_METRICS = len(CBC_FIELDS)  # 15

    def __init__(self, freeze_blocks: int = 8, pretrained: bool = False):
        super().__init__()
        import timm

        # Backbone — identical call to notebook
        self.backbone = timm.create_model(
            "vit_base_patch16_224",
            pretrained=pretrained,
            num_classes=0,        # returns [CLS] embedding (d=768)
        )
        embed_dim = self.backbone.embed_dim  # 768

        # Freeze patch embed + early blocks (mirrors notebook)
        for p in self.backbone.patch_embed.parameters():
            p.requires_grad = False
        for block in self.backbone.blocks[:freeze_blocks]:
            for p in block.parameters():
                p.requires_grad = False

        # Head A — binary classification
        # Notebook: LayerNorm → Dropout(0.3) → Linear(768,256) → GELU → Dropout(0.2) → Linear(256,2)
        self.cls_head = nn.Sequential(
            nn.LayerNorm(embed_dim),
            nn.Dropout(0.3),
            nn.Linear(embed_dim, 256),
            nn.GELU(),
            nn.Dropout(0.2),
            nn.Linear(256, 2),
        )

        # Head B — 15-value regression
        # Notebook: LayerNorm → Dropout(0.3) → Linear(768,512) → GELU → Dropout(0.2) → Linear(512,256) → GELU → Linear(256,15)
        self.reg_head = nn.Sequential(
            nn.LayerNorm(embed_dim),
            nn.Dropout(0.3),
            nn.Linear(embed_dim, 512),
            nn.GELU(),
            nn.Dropout(0.2),
            nn.Linear(512, 256),
            nn.GELU(),
            nn.Linear(256, self.NUM_METRICS),
        )

    def forward(self, x):
        features   = self.backbone(x)           # (B, 768)
        cls_logits = self.cls_head(features)    # (B, 2)
        cbc_values = self.reg_head(features)    # (B, 15)
        return cls_logits, cbc_values


# ─────────────────────────────────────────────────────────────────────────────
# Model loading
# ─────────────────────────────────────────────────────────────────────────────

vit_model  = None
vit_device = None


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

    # Notebook saves: {"epoch", "model_state_dict", "optimizer_state_dict", "val_acc", "val_f1"}
    if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
        state_dict = checkpoint["model_state_dict"]
        print(f"[ViT] Checkpoint epoch={checkpoint.get('epoch')} "
              f"val_acc={checkpoint.get('val_acc', '?'):.4f} "
              f"val_f1={checkpoint.get('val_f1', '?'):.4f}")
    elif isinstance(checkpoint, dict) and "state_dict" in checkpoint:
        state_dict = checkpoint["state_dict"]
    else:
        state_dict = checkpoint  # bare state dict

    model = CBCViT(freeze_blocks=8, pretrained=False)
    missing, unexpected = model.load_state_dict(state_dict, strict=True)

    if missing:
        print(f"[ViT] WARNING — missing keys ({len(missing)}): {missing[:5]}")
    if unexpected:
        print(f"[ViT] WARNING — unexpected keys ({len(unexpected)}): {unexpected[:5]}")

    model.to(vit_device)
    model.eval()
    vit_model = model
    total     = sum(p.numel() for p in model.parameters())
    print(f"[ViT] OK Loaded — {total:,} params")


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
        print("[STARTUP] Testing mode — model not loaded")
    yield
    print("[SHUTDOWN] Cleanup")


# ─────────────────────────────────────────────────────────────────────────────
# Prometheus Metrics (A5)
# ─────────────────────────────────────────────────────────────────────────────

_PREDICTION_COUNT = 0
_PREDICTION_SUCCESS = 0
_PREDICTION_FAILURE = 0
_OCR_FAILURE_COUNT = 0
_CHAT_REQUEST_COUNT = 0
_CHAT_FAILURE_COUNT = 0
_TOTAL_LATENCY_MS = 0
_TOTAL_PREDICTIONS = 0


def _predict_metric(success: bool, latency_ms: float, ocr_failed: bool = False):
    global _PREDICTION_COUNT, _PREDICTION_SUCCESS, _PREDICTION_FAILURE, _OCR_FAILURE_COUNT, _TOTAL_LATENCY_MS, _TOTAL_PREDICTIONS
    _PREDICTION_COUNT += 1
    _TOTAL_LATENCY_MS += latency_ms
    _TOTAL_PREDICTIONS += 1
    if success:
        _PREDICTION_SUCCESS += 1
    else:
        _PREDICTION_FAILURE += 1
    if ocr_failed:
        _OCR_FAILURE_COUNT += 1


def _chat_metric(success: bool):
    global _CHAT_REQUEST_COUNT, _CHAT_FAILURE_COUNT
    _CHAT_REQUEST_COUNT += 1
    if not success:
        _CHAT_FAILURE_COUNT += 1


app = FastAPI(
    title="BloodConnect AI Service",
    version="3.0.2",
    lifespan=lifespan,
)

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=(
        os.environ.get("CORS_ORIGINS", "*").split(",")
        if os.environ.get("CORS_ORIGINS")
        else ["*"]
    ),
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Metrics endpoint (A5)
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/metrics")
@limiter.limit("60/minute")
def metrics(request: Request):
    return {
        "predictions_total": _PREDICTION_COUNT,
        "predictions_success": _PREDICTION_SUCCESS,
        "predictions_failure": _PREDICTION_FAILURE,
        "ocr_failures_total": _OCR_FAILURE_COUNT,
        "chat_requests_total": _CHAT_REQUEST_COUNT,
        "chat_failures_total": _CHAT_FAILURE_COUNT,
        "avg_latency_ms": round(_TOTAL_LATENCY_MS / max(_TOTAL_PREDICTIONS, 1), 2),
        "vit_loaded": vit_model is not None,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Prediction Feedback Store (A6 — in-memory, survives restarts as log)
# ─────────────────────────────────────────────────────────────────────────────

_PREDICTION_FEEDBACK = []  # list of dicts: {image_hash, prediction, actual, timestamp}


@app.post("/api/v1/predictions/feedback")
@limiter.limit("60/minute")
async def record_prediction_feedback(request: Request, body: dict):
    """Record user/clinician feedback on a prediction for accuracy tracking."""
    image_hash = body.get("image_hash", "")
    prediction = body.get("prediction", "")
    actual = body.get("actual", "")  # "Normal" or "Abnormal" from clinician review
    correct = prediction == actual

    record = {
        "image_hash": image_hash[:16],
        "prediction": prediction,
        "actual": actual,
        "correct": correct,
        "timestamp": time.time(),
    }
    _PREDICTION_FEEDBACK.append(record)
    logger.info(f"feedback image={image_hash[:16]} pred={prediction} actual={actual} correct={correct}")

    # Keep only last 10k records in memory
    if len(_PREDICTION_FEEDBACK) > 10000:
        _PREDICTION_FEEDBACK[:1000] = []

    return {"ok": True, "correct": correct}


@app.get("/api/v1/predictions/accuracy")
async def prediction_accuracy():
    """Return accuracy metrics from collected feedback."""
    total = len(_PREDICTION_FEEDBACK)
    if total == 0:
        return {"total": 0, "accuracy": None, "correct": 0}

    correct_count = sum(1 for r in _PREDICTION_FEEDBACK if r["correct"])
    return {
        "total": total,
        "correct": correct_count,
        "accuracy": round(correct_count / total, 4),
    }


@app.get("/health")
def health():
    total_feedback = len(_PREDICTION_FEEDBACK)
    correct_feedback = sum(1 for r in _PREDICTION_FEEDBACK if r["correct"])
    accuracy = round(correct_feedback / total_feedback, 4) if total_feedback > 0 else None

    return {
        "status":           "ONLINE",
        "vit_loaded":       vit_model is not None,
        "vit_model_loaded": vit_model is not None,
        "model_loaded":     vit_model is not None,
        "device":           str(vit_device),
        "weights_exist":    Path(VIT_WEIGHTS_PATH).exists(),
        "tesseract_found":  TESSERACT_FOUND,
        "version":          "3.0.2",
        "metrics": {
            "total_predictions": _PREDICTION_COUNT,
            "success": _PREDICTION_SUCCESS,
            "failure": _PREDICTION_FAILURE,
            "ocr_failures": _OCR_FAILURE_COUNT,
            "chat_requests": _CHAT_REQUEST_COUNT,
            "chat_failures": _CHAT_FAILURE_COUNT,
        },
        "feedback": {
            "total": total_feedback,
            "accuracy": accuracy,
        },
        "ab_testing": ab_variant_stats(),
    }


@app.get("/status")
def status():
    return {
        "service":    "BloodConnect AI v3.0.2",
        "vit_loaded": vit_model is not None,
        "device":     str(vit_device),
        "weights":    str(Path(VIT_WEIGHTS_PATH).resolve()),
        "tesseract":  TESSERACT_FOUND,
    }


@app.post("/predict")
@app.post("/api/v1/screen-report")
@limiter.limit("30/minute")
async def predict(
    request: Request,
    file:   UploadFile = File(...),
    gender: str        = Form(default="male"),
):
    """
    Main prediction endpoint.

    Stage 1: ViT classification (Normal/Abnormal)
    Stage 2: OCR + CBC parsing  (only if Abnormal)
    Stage 3: Donor eligibility evaluation
    """
    start_time = time.time()
    image_hash = ""
    prediction_error = False
    ocr_failed = False

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Upload valid image (JPEG/PNG).")

    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="File is empty.")

    image_hash = hashlib.sha256(contents).hexdigest()[:16]

    try:
        pil_image = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid image: {exc}")

    if vit_model is None:
        raise HTTPException(status_code=503, detail="ViT model not loaded.")

    # ── STAGE 1: ViT Classification ──────────────────────────────────────────
    try:
        tensor = VAL_TRANSFORM(pil_image).unsqueeze(0).to(vit_device)
        with torch.no_grad():
            cls_logits, _cbc_values = vit_model(tensor)
            probs = torch.softmax(cls_logits, dim=1)[0]
            pred  = torch.argmax(probs).item()
            conf  = float(probs[pred]) * 100
    except Exception as e:
        _predict_metric(success=False, latency_ms=(time.time() - start_time) * 1000)
        raise HTTPException(status_code=500, detail=f"ViT inference failed: {e}")

    vit_label = "Abnormal" if pred == 1 else "Normal"
    low_confidence = conf < VIT_THRESHOLD * 100

    if low_confidence:
        vit_label = "Uncertain"

    response = {
        "success":            True,
        "prediction":         vit_label,
        "confidence":         round(conf, 2),
        "eligible":           vit_label == "Normal",
        "result":             "ELIGIBLE" if vit_label == "Normal" else ("DEFERRED" if vit_label == "Abnormal" else "NEEDS_REVIEW"),
        "prediction_flagged": low_confidence,
        "raw_probability":    round(float(probs[1]), 4),
        "threshold":          VIT_THRESHOLD,
        "abnormal_findings":  [],
        "metrics":            {},
        "evaluation": {
            "status":         "ELIGIBLE" if vit_label == "Normal" else ("DEFERRED" if vit_label == "Abnormal" else "NEEDS_REVIEW"),
            "explanation_en": "ViT indicates normal CBC profile.",
            "explanation_ar": "يشير المصنف إلى صورة دم طبيعية.",
            "gender":         gender,
        },
        "reasons": [],
    }

    if vit_label == "Normal":
        elapsed = (time.time() - start_time) * 1000
        _predict_metric(success=True, latency_ms=elapsed)
        logger.info(f"prediction image={image_hash} result=Normal confidence={conf} latency_ms={elapsed:.0f}")
        return response

    # ── STAGE 2: OCR + CBC Parsing (Abnormal only) ───────────────────────────
    try:
        ocr_text = extract_text(pil_image)
        ocr_text_redacted = redact_pii(ocr_text)
        rbc_indices, diff_pct, diff_abs = parse_cbc(ocr_text_redacted)
        findings = analyze_all(rbc_indices, diff_pct, diff_abs)

        any_extracted = any(v is not None for v in rbc_indices.values())
        if not any_extracted:
            logger.warning(f"OCR extracted zero values image={image_hash}")
            ocr_failed = True

    except Exception as e:
        logger.warning(f"OCR failed image={image_hash} error={e}")
        ocr_text_redacted = ""
        rbc_indices = {}
        diff_pct    = {}
        diff_abs    = {}
        findings    = []
        ocr_failed  = True

    # ── STAGE 3: Donor Eligibility Evaluation ────────────────────────────────
    if ocr_failed:
        eval_result = {
            "status":         "NEEDS_REVIEW",
            "reasons":        ["CBC values could not be extracted from the image. Manual review required."],
            "reasons_ar":     ["تعذّر استخراج قيم الفحص من الصورة — يلزم المراجعة اليدوية."],
            "explanation_en": (
                "The AI classifier detected an abnormal CBC profile, but OCR could not extract "
                "numeric values from this image (image may be blurry, low-contrast, or the report "
                "format is unsupported). Please have a clinician review the original report."
            ),
            "explanation_ar": (
                "اكتشف المصنّف صورة دم غير طبيعية، لكن تعذّر استخراج القيم الرقمية من الصورة "
                "(قد تكون الصورة ضبابية أو منخفضة التباين أو بتنسيق غير مدعوم). "
                "يُرجى مراجعة التقرير الأصلي من قِبل أخصائي."
            ),
            "gender": gender,
        }
    else:
        eval_result = run_donor_evaluation(rbc_indices, diff_pct, gender=gender)

    flat_metrics = {**rbc_indices}
    for k, v in diff_pct.items():
        if v is not None:
            flat_metrics[f"{k}_pct"] = v
    for k, v in diff_abs.items():
        if v is not None:
            flat_metrics[f"{k}_abs"] = v

    final_status = eval_result["status"]

    # Override to NEEDS_REVIEW when ViT confidence is below threshold
    if low_confidence:
        final_status = "NEEDS_REVIEW"
        eval_result = {
            "status": "NEEDS_REVIEW",
            "reasons": [f"Low confidence ({conf:.1f}%) below threshold ({VIT_THRESHOLD*100:.0f}%). Manual review required."] + eval_result.get("reasons", []),
            "reasons_ar": [f"ثقة منخفضة ({conf:.1f}%) — يلزم المراجعة اليدوية."] + eval_result.get("reasons_ar", []),
            "explanation_en": (
                f"The AI classifier confidence ({conf:.1f}%) is below the safe threshold "
                f"({VIT_THRESHOLD*100:.0f}%). The result is flagged for manual review."
            ),
            "explanation_ar": (
                f"ثقة المصنّف ({conf:.1f}%) أقل من الحد الآمن ({VIT_THRESHOLD*100:.0f}%). "
                "تم وضع علامة على النتيجة للمراجعة اليدوية."
            ),
            "gender": gender,
        }

    response.update({
        "eligible":          final_status == "ELIGIBLE",
        "result":            final_status,
        "ocr_failed":        ocr_failed,
        "abnormal_findings": findings,
        "ocr_text":          (ocr_text_redacted[:500] if ocr_text_redacted else ""),
        "metrics": {
            "rbc_indices":       rbc_indices,
            "differential_pct":  diff_pct,
            "differential_abs":  diff_abs,
        },
        "reasons": eval_result["reasons"],
        "evaluation": {
            "status":         final_status,
            "explanation_en": eval_result["explanation_en"],
            "explanation_ar": eval_result["explanation_ar"],
            "gender":         gender,
        },
    })

    elapsed = (time.time() - start_time) * 1000
    _predict_metric(success=True, latency_ms=elapsed, ocr_failed=ocr_failed)
    logger.info(
        f"prediction image={image_hash} result={final_status} "
        f"vit={vit_label} confidence={conf:.1f} ocr_failed={ocr_failed} "
        f"findings={len(findings)} latency_ms={elapsed:.0f}"
    )

    return response


# ─────────────────────────────────────────────────────────────────────────────
# AI Assistant (OpenRouter)
# ─────────────────────────────────────────────────────────────────────────────

OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_MODEL   = "google/gemini-2.5-flash"


class ChatMessage(BaseModel):
    role:    str = Field(pattern=r"^(system|user|assistant)$")
    content: str = Field(max_length=2000)


class ChatRequest(BaseModel):
    messages:   list[ChatMessage] = Field(max_length=20)
    donor_data: dict = Field(default_factory=dict)


_MEDICAL_DISCLAIMER = (
    "\n\n---\n*This explanation is AI-generated and for informational purposes only. "
    "It does not constitute medical advice. Always consult a qualified healthcare "
    "professional for medical decisions regarding blood donation.*"
)

_HARMFUL_PATTERNS = [
    r"(?i)\bdonate\s+when\s+(?:you\s+)?have\s+(?:a\s+)?fever\b",
    r"(?i)\bdonate\s+with\s+low\s+hemoglobin\b",
    r"(?i)\b(?:ignore|disregard)\s+(?:\w+\s+)?(?:doctor|physician|medical)(?:'s)?\s+(?:advice|opinion)\b",
    r"(?i)\b(?:lie|falsify|fake)\s+(?:about|on)\s+(?:your\s+)?(?:health|symptoms|history)\b",
]


def _contains_harmful_content(text: str) -> bool:
    for pat in _HARMFUL_PATTERNS:
        if re.search(pat, text):
            return True
    return False


def _sanitize_user_input(text: str) -> str:
    """Strip prompt injection attempts: ignore content that tries to override system role."""
    stripped = re.sub(r"(?i)(?:(?<=[\n.;])|^)\s*(?:system|assistant)\s*:.*", "", text)
    return stripped.strip()[:2000]


@app.post("/assistant/chat")
@limiter.limit("20/minute")
async def assistant_chat(request: Request, chat_request: ChatRequest):
    """Conversational AI for explaining results."""
    start_time = time.time()
    api_key = os.environ.get("AI_ASSISTANT_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="AI assistant not configured.")

    # Input validation — reject empty message list
    if not chat_request.messages:
        raise HTTPException(status_code=400, detail="No messages provided.")

    # Sanitize user messages for prompt injection attempts (A3)
    sanitized = []
    for m in chat_request.messages:
        clean = _sanitize_user_input(m.content)
        if clean:
            sanitized.append({"role": m.role, "content": clean})

    if not sanitized:
        raise HTTPException(status_code=400, detail="No valid message content after sanitization.")

    # Build system context (A3: system context is server-controlled, not from user input)
    # A/B test: pick prompt variant (A8)
    variant = pick_variant()
    donor_data = chat_request.donor_data
    system_parts = [variant["system_prompt"]]
    if donor_data:
        system_parts.append(
            f"Donor Screening Result: {donor_data.get('status', 'N/A')}\n"
            f"Gender: {donor_data.get('gender', 'N/A')}\n"
            f"Confidence: {donor_data.get('confidence', 'N/A')}%\n"
            f"Explanation: {donor_data.get('explanation_en', 'N/A')}"
        )
        findings = donor_data.get("abnormal_findings", [])
        if findings:
            system_parts.append("Abnormal findings:")
            for f in findings:
                system_parts.append(
                    f"- {f.get('label', '?')}: {f.get('value', '?')} "
                    f"{f.get('unit', '')} ({f.get('status', '?')}, "
                    f"ref: {f.get('range', [None, None])[0]}-{f.get('range', [None, None])[1]})"
                )
        reasons = donor_data.get("reasons", [])
        if reasons:
            system_parts.append("Reasons:\n" + "\n".join(f"- {r}" for r in reasons))

    system_context = "\n\n".join(system_parts)
    sanitized.insert(0, {"role": "system", "content": system_context})

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type":  "application/json",
    }
    payload = {
        "model":       OPENROUTER_MODEL,
        "messages":    sanitized,
        "max_tokens":  variant["max_tokens"],
        "temperature": variant["temperature"],
    }

    try:
        resp = requests.post(OPENROUTER_API_URL, headers=headers, json=payload, timeout=30)
        resp.raise_for_status()
        reply = resp.json()["choices"][0]["message"]["content"].strip()

        # Content safety filter (A2): block harmful advice
        if _contains_harmful_content(reply):
            logger.warning(f"LLM output blocked as potentially harmful")
            reply = (
                "I'm unable to provide that information as it may conflict with "
                "safe blood donation practices. Please consult a healthcare professional "
                "for medical advice regarding your eligibility."
            )

        reply += _MEDICAL_DISCLAIMER
        elapsed = (time.time() - start_time) * 1000
        _chat_metric(success=True)
        logger.info(f"chat success variant={variant['id']} latency_ms={elapsed:.0f} messages={len(sanitized)}")

        return {"reply": reply}
    except Exception as e:
        logger.error(f"OpenRouter chat failed: {e}")
        _chat_metric(success=False)
        raise HTTPException(status_code=502, detail="AI assistant unavailable.")


# ─────────────────────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
