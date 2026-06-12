from pathlib import Path
import io
import os
import json
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from transformers import ViTModel, ViTConfig
import torch
import torch.nn as nn
from torchvision import transforms
from PIL import Image
import requests

load_dotenv()

PARAM_ORDER = [
    "hemoglobin", "hematocrit", "rbc", "wbc", "platelets",
    "mcv", "mchc", "pulse", "temperature", "weight",
    "systolic_bp", "diastolic_bp", "ferritin", "vdrl", "chronic_condition",
]

PARAM_NORM = {
    "hemoglobin": (7.0, 18.0),
    "hematocrit": (20.0, 55.0),
    "rbc": (2.5, 7.0),
    "wbc": (2.0, 16.0),
    "platelets": (80.0, 500.0),
    "mcv": (60.0, 110.0),
    "mchc": (28.0, 38.0),
    "pulse": (45.0, 120.0),
    "temperature": (35.5, 40.0),
    "weight": (40.0, 130.0),
    "systolic_bp": (80.0, 190.0),
    "diastolic_bp": (45.0, 115.0),
    "ferritin": (2.0, 300.0),
    "vdrl": (0.0, 1.0),
    "chronic_condition": (0.0, 1.0),
}

THRESHOLDS = {
    "hemoglobin": (11.0, 18.5, "g/dL", "Hemoglobin"),
    "hematocrit": (33.0, 52.0, "%", "Hematocrit"),
    "rbc": (3.5, 6.5, "x10(6)/uL", "RBC"),
    "wbc": (3.0, 13.0, "x10(3)/uL", "WBC"),
    "platelets": (100.0, 500.0, "x10(3)/uL", "Platelets"),
    "mcv": (72.0, 108.0, "fL", "MCV"),
    "mchc": (30.0, 38.0, "g/dL", "MCHC"),
    "pulse": (50.0, 110.0, "bpm", "Pulse"),
    "temperature": (35.5, 38.0, "celsius", "Temperature"),
    "weight": (45.0, None, "kg", "Weight"),
    "systolic_bp": (85.0, 175.0, "mmHg", "Systolic BP"),
    "diastolic_bp": (55.0, 105.0, "mmHg", "Diastolic BP"),
    "ferritin": (8.0, 350.0, "ng/mL", "Ferritin"),
    "vdrl": (0.0, 0.80, "binary", "VDRL Syphilis"),
    "chronic_condition": (0.0, 0.80, "binary", "Chronic Condition"),
}

CLS_CONFIDENCE_THRESHOLD = 0.55


def denormalize(param: str, value: float) -> float:
    mn, mx = PARAM_NORM[param]
    return value * (mx - mn) + mn


def rules_decision(values: dict[str, float]) -> tuple[str, list[str]]:
    reasons = []
    for param, value in values.items():
        if param not in THRESHOLDS:
            continue
        min_val, max_val, _unit, label = THRESHOLDS[param]
        if min_val is not None and value < min_val:
            reasons.append(f"{label} is below the safe range")
        elif max_val is not None and value > max_val:
            reasons.append(f"{label} is above the safe range")
    return ("Deferred", reasons) if reasons else ("Eligible", [])


class MedicalViT(nn.Module):
    def __init__(self, state_dict):
        super().__init__()
        self.vit = ViTModel(ViTConfig())

        b1_in = state_dict["regression_head.block1.0.weight"].shape[1]
        b1_out = state_dict["regression_head.block1.0.weight"].shape[0]
        b2_out = state_dict["regression_head.block2.0.weight"].shape[0]
        b3_out = state_dict["regression_head.block3.0.weight"].shape[0]
        n_params = state_dict["regression_head.output.weight"].shape[0]
        cls_mid = state_dict["classify_head.0.weight"].shape[0]

        self.regression_head = nn.ModuleDict({
            "block1": nn.Sequential(
                nn.Linear(b1_in, b1_out),
                nn.LayerNorm(b1_out),
                nn.GELU(),
                nn.Dropout(0.3),
            ),
            "block2": nn.Sequential(
                nn.Linear(b1_out, b2_out),
                nn.LayerNorm(b2_out),
                nn.GELU(),
                nn.Dropout(0.2),
            ),
            "block3": nn.Sequential(
                nn.Linear(b2_out, b3_out),
                nn.LayerNorm(b3_out),
                nn.GELU(),
                nn.Dropout(0.1),
            ),
            "output": nn.Linear(b3_out, n_params),
            "residual": nn.Linear(b1_in, b3_out),
        })

        self.classify_head = nn.Sequential(
            nn.Linear(b1_in, cls_mid),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(cls_mid, 1),
        )

    def forward(self, x):
        outputs = self.vit(pixel_values=x)
        if hasattr(outputs, "pooler_output") and outputs.pooler_output is not None:
            features = outputs.pooler_output
        else:
            features = outputs.last_hidden_state[:, 0, :]

        reg = self.regression_head["block1"](features)
        reg = self.regression_head["block2"](reg)
        reg = self.regression_head["block3"](reg)
        reg = self.regression_head["output"](reg + self.regression_head["residual"](features))
        cls = self.classify_head(features)
        return reg, cls


# ── FastAPI app ────────────────────────────────────────────────────────
app = FastAPI()

ALLOWED_ORIGINS = os.environ.get("CORS_ORIGINS", "").split(",") if os.environ.get("CORS_ORIGINS") else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Load model once at startup ─────────────────────────────────────────
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "vit_medical_best.pt"

print("Loading model weights...")
if not MODEL_PATH.exists():
    raise RuntimeError(f"Model file not found at: {MODEL_PATH}")
state_dict = torch.load(MODEL_PATH, map_location=device, weights_only=False)

print("Building model...")
model = MedicalViT(state_dict)
model.load_state_dict(state_dict, strict=True)
model.eval()
model.to(device)
print("Model ready!")

# ── Same transforms used in your training notebook ─────────────────────
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std =[0.229, 0.224, 0.225],
    ),
])


# ── Endpoints ──────────────────────────────────────────────────────────
@app.get("/health")
def health():
    return {
        "status": "ok",
        "model_loaded": True,
        "device": str(device),
        "model_path": str(MODEL_PATH),
        "outputs": len(PARAM_ORDER),
    }


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Please upload a valid image file.")

    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    try:
        image = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid image format.") from exc

    tensor = transform(image).unsqueeze(0).to(device)

    with torch.no_grad():
        reg_out, cls_logits = model(tensor)
        reg_out = torch.clamp(reg_out, 0.0, 1.0)
        conf = torch.sigmoid(cls_logits).item()

    reg_denorm = {
        PARAM_ORDER[i]: round(denormalize(PARAM_ORDER[i], reg_out[0, i].item()), 1)
        for i in range(len(PARAM_ORDER))
    }

    if conf >= CLS_CONFIDENCE_THRESHOLD:
        result = "Eligible"
        reasons = []
    elif conf <= (1 - CLS_CONFIDENCE_THRESHOLD):
        result = "Deferred"
        reasons = ["Classification head confidence strongly indicates deferral"]
    else:
        result, reasons = rules_decision(reg_denorm)

    eligible = result == "Eligible"

    return {
        "result": result,
        "eligible": eligible,
        "confidence": round(conf * 100, 2),
        "raw_probability": round(conf, 4),
        "threshold": CLS_CONFIDENCE_THRESHOLD,
        "regression_normalized": [round(float(v), 4) for v in reg_out.squeeze(0).cpu().tolist()],
        "regression_denormalized": reg_denorm,
        "reasons": reasons,
    }


# ── AI Assistant Endpoint ──────────────────────────────────────────────
OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_MODEL = "google/gemini-2.0-flash-001"


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    donor_data: dict


def build_system_prompt(donor_data: dict) -> str:
    values_str = ""
    for param, value in donor_data.items():
        if param in THRESHOLDS:
            _min, _max, unit, label = THRESHOLDS[param]
            values_str += f"- {label}: **{value} {unit}**"
            if _min is not None and value < _min:
                values_str += f" (below normal range {_min}-{_max})"
            elif _max is not None and value > _max:
                values_str += f" (above normal range {_min}-{_max})"
            else:
                values_str += " (normal)"
            values_str += "\n"

    reasons = donor_data.get("reasons", [])
    reasons_str = "\n".join(f"- {r}" for r in reasons) if reasons else "No specific reasons provided."

    confidence = donor_data.get("confidence", "N/A")

    return f"""You are a compassionate and highly professional AI Medical Doctor specializing in hematology and blood donation medicine.

You are speaking to a blood donor who has been temporarily deferred from donating blood.

Your role is to support, reassure, and educate the donor in a calm and friendly way.

Donor Information:
- Donation Status: **Temporarily Deferred**
- AI Confidence: **{confidence}%**

Predicted Blood Values:
{values_str}
Deferral Reasons:
{reasons_str}

Instructions:
- Always be calm, warm, and reassuring
- Explain medical terms in simple everyday language
- Reference the donor's actual medical values in your answers
- Emphasize that temporary deferral is common and usually not serious
- Provide practical and actionable advice when possible
- Use **bold text** for important values or key points
- Keep responses structured and easy to read
- Never be alarming or dramatic
- Always encourage consulting a real doctor for serious concerns
"""


@app.post("/assistant/chat")
async def assistant_chat(request: ChatRequest):
    api_key = os.environ.get("AI_ASSISTANT_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="AI assistant is not configured.")

    if len(request.messages) > 30:
        raise HTTPException(status_code=400, detail="Conversation too long. Please start a new chat.")

    system_prompt = build_system_prompt(request.donor_data)

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://bloodconnect.app",
        "X-Title": "BloodConnect AI Assistant",
    }

    openrouter_messages = [{"role": "system", "content": system_prompt}]
    for msg in request.messages:
        openrouter_messages.append({"role": msg.role, "content": msg.content})

    payload = {
        "model": OPENROUTER_MODEL,
        "messages": openrouter_messages,
        "max_tokens": 800,
        "temperature": 0.7,
    }

    try:
        resp = requests.post(OPENROUTER_API_URL, headers=headers, json=payload, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        reply = data["choices"][0]["message"]["content"].strip()
        return {"reply": reply}
    except requests.exceptions.Timeout:
        raise HTTPException(status_code=504, detail="AI assistant request timed out. Please try again.")
    except requests.exceptions.RequestException as e:
        print(f"OpenRouter error: {e}")
        raise HTTPException(status_code=502, detail="Failed to reach AI assistant service. Please try again.")
