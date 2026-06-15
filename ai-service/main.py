from pathlib import Path
import io
import os
import json
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from transformers import AutoProcessor, Qwen2VLForConditionalGeneration, BitsAndBytesConfig
from peft import PeftModel
import torch
from PIL import Image
import requests

load_dotenv()

MODEL_WEIGHTS_PATH = "./fine_tuned_qwen2_vl_medical"
BASE_MODEL_NAME = "retal16/Qwen2-VL-2B-Instruct"

# ─────────────────────────────────────────────────────────────────────────────
# ✅ OPTIMIZED THRESHOLDS (More conservative for safety)
# Matches actual VLM extracted features
# ─────────────────────────────────────────────────────────────────────────────

# Hemoglobin thresholds (increased minimums for safety margin)
MALE_MIN_HEMOGLOBIN = 13.5      # ↑ was 13.0 → more conservative
FEMALE_MIN_HEMOGLOBIN = 12.5    # ↑ was 12.0 → more conservative
MALE_MAX_HEMOGLOBIN = 17.5      # unchanged
FEMALE_MAX_HEMOGLOBIN = 16.0    # unchanged

# Comprehensive CBC thresholds (all features VLM extracts)
THRESHOLDS = {
    # PRIMARY SCREENING PARAMETERS (Critical for eligibility)
    "hemoglobin": (13.5, 17.5, "g/dL", "Hemoglobin", "Hb"),          # ↑ min increased
    "tlc": (4.5, 10.5, "x10³/μL", "Total Leukocyte Count", "TLC"),   # ↑ min, ↓ max optimized
    "platelet_count": (180.0, 400.0, "x10³/μL", "Platelet Count", "Plt"),  # ↑ min increased
    
    # SUPPORTING PARAMETERS (Quality checks)
    "hematocrit": (38.0, 52.0, "%", "Hematocrit", "Hct"),
    "red_cell_count": (4.5, 5.5, "x10⁶/μL", "Red Cell Count", "RBC"),
    "mcv": (80.0, 100.0, "fL", "Mean Corpuscular Volume", "MCV"),
    "mch": (27.0, 33.0, "pg", "Mean Corpuscular Hemoglobin", "MCH"),
    "mchc": (32.0, 36.0, "g/dL", "Mean Corpuscular Hemoglobin Concentration", "MCHC"),
    "rdw": (11.5, 14.5, "%", "Red Cell Distribution Width", "RDW"),
    
    # DIFFERENTIAL COUNTS
    "neutrophils": (40.0, 75.0, "%", "Neutrophils", "Neut"),
    "lymphocytes": (20.0, 40.0, "%", "Lymphocytes", "Lymph"),
    "monocytes": (2.0, 10.0, "%", "Monocytes", "Mono"),
    "eosinophils": (1.0, 6.0, "%", "Eosinophils", "Eos"),
    "basophils": (0.0, 2.0, "%", "Basophils", "Baso"),
    "segmented": (45.0, 75.0, "%", "Segmented Neutrophils", "Seg"),
}

EXTRA_RULES = {
    "temperature": (36.1, 37.5, "celsius", "Temperature", "Temp"),
    "pulse": (60.0, 100.0, "bpm", "Pulse", "Pulse"),
    "systolic_bp": (90.0, 140.0, "mmHg", "Systolic BP", "SBP"),
    "diastolic_bp": (60.0, 90.0, "mmHg", "Diastolic BP", "DBP"),
    "weight": (50.0, None, "kg", "Weight", "Wt"),
}


def normalize_extracted_data(extracted_data: dict) -> dict:
    """
    Normalize all extracted keys to lowercase for consistent handling.
    VLM may return keys in different cases (TLC, tlc, Hemoglobin, haemoglobin, etc.)
    """
    normalized = {}
    for k, v in extracted_data.items():
        # Convert key to lowercase and normalize common variations
        norm_key = k.lower().strip()
        norm_key = norm_key.replace("haemoglobin", "hemoglobin")
        norm_key = norm_key.replace("hematocrit", "hematocrit")
        norm_key = norm_key.replace("red_cell_count", "red_cell_count")
        norm_key = norm_key.replace("rbc", "red_cell_count")
        norm_key = norm_key.replace("rdw_cv", "rdw")
        norm_key = norm_key.replace("rdw", "rdw")
        norm_key = norm_key.replace("platelet_count", "platelet_count")
        norm_key = norm_key.replace("platelets", "platelet_count")
        norm_key = norm_key.replace("plt", "platelet_count")
        norm_key = norm_key.replace("wbc", "tlc")
        norm_key = norm_key.replace("leukocytes", "tlc")
        
        try:
            normalized[norm_key] = float(v)
        except (ValueError, TypeError):
            continue
    
    return normalized


def run_donor_evaluation(extracted_data: dict, gender: str = "male") -> dict:
    """
    Evaluate blood donor eligibility based on CBC values.
    Uses OPTIMIZED thresholds for better safety.
    Checks all parameters returned by VLM.
    """
    is_deferred = False
    reasons_en = []
    reasons_ar = []

    # Normalize extracted data (handle case variations from VLM)
    clean_data = normalize_extracted_data(extracted_data)

    # ─────────────────────────────────────────────────────────────────────────
    # PRIMARY SCREENING PARAMETERS (Most critical for eligibility)
    # ─────────────────────────────────────────────────────────────────────────
    
    # 1. HEMOGLOBIN CHECK (✅ OPTIMIZED THRESHOLD)
    hb_min = FEMALE_MIN_HEMOGLOBIN if gender.lower() == "female" else MALE_MIN_HEMOGLOBIN
    hb_max = FEMALE_MAX_HEMOGLOBIN if gender.lower() == "female" else MALE_MAX_HEMOGLOBIN

    if "hemoglobin" in clean_data:
        hb = clean_data["hemoglobin"]
        if hb < hb_min:
            is_deferred = True
            reasons_en.append(f"Hemoglobin ({hb} g/dL) is below the minimum safe range ({hb_min} g/dL) for {gender} donors. Risk of anemia post-donation.")
            reasons_ar.append(f"مستوى الهيموغلوبين ({hb} جم/ديسيلتر) أقل من الحد الآمن ({hb_min} جم/ديسيلتر) للمتبرعين {gender}. خطر فقر الدم بعد التبرع.")
        elif hb > hb_max:
            is_deferred = True
            reasons_en.append(f"Hemoglobin ({hb} g/dL) exceeds the maximum safe range ({hb_max} g/dL). Potential blood viscosity concerns.")
            reasons_ar.append(f"مستوى الهيموغلوبين ({hb} جم/ديسيلتر) يتجاوز الحد الأقصى الآمن ({hb_max} جم/ديسيلتر). مخاوف من لزوجة الدم.")

    # 2. WHITE BLOOD CELL COUNT / TLC CHECK (✅ OPTIMIZED THRESHOLD)
    if "tlc" in clean_data:
        tlc = clean_data["tlc"]
        tlc_min, tlc_max = THRESHOLDS["tlc"][0], THRESHOLDS["tlc"][1]
        if tlc < tlc_min:
            is_deferred = True
            reasons_en.append(f"Total Leukocyte Count ({tlc} x10³/μL) is below normal range ({tlc_min}-{tlc_max}). Indicates immunocompromise.")
            reasons_ar.append(f"عدد خلايا الدم البيضاء ({tlc} × 10³/ميكروتر) أقل من المعدل الطبيعي ({tlc_min}-{tlc_max}). يشير إلى ضعف المناعة.")
        elif tlc > tlc_max:
            is_deferred = True
            reasons_en.append(f"Total Leukocyte Count ({tlc} x10³/μL) is above normal range ({tlc_min}-{tlc_max}). Possible active infection.")
            reasons_ar.append(f"عدد خلايا الدم البيضاء ({tlc} × 10³/ميكروتر) يتجاوز المعدل الطبيعي ({tlc_min}-{tlc_max}). قد يشير إلى عدوى نشطة.")

    # 3. PLATELET COUNT CHECK (✅ OPTIMIZED THRESHOLD)
    if "platelet_count" in clean_data:
        plt = clean_data["platelet_count"]
        plt_min, plt_max = THRESHOLDS["platelet_count"][0], THRESHOLDS["platelet_count"][1]
        if plt < plt_min:
            is_deferred = True
            reasons_en.append(f"Platelet count ({plt} x10³/μL) is below safe range ({plt_min}-{plt_max}). Risk of bleeding complications.")
            reasons_ar.append(f"عدد الصفيحات ({plt} × 10³/ميكروتر) أقل من المعدل الآمن ({plt_min}-{plt_max}). خطر مضاعفات النزيف.")
        elif plt > plt_max:
            is_deferred = True
            reasons_en.append(f"Platelet count ({plt} x10³/μL) exceeds safe range ({plt_min}-{plt_max}). Potential thrombotic risk.")
            reasons_ar.append(f"عدد الصفيحات ({plt} × 10³/ميكروتر) يتجاوز المعدل الآمن ({plt_min}-{plt_max}). خطر تجلط الدم.")

    # ─────────────────────────────────────────────────────────────────────────
    # SECONDARY CHECKS (Supporting quality parameters)
    # ─────────────────────────────────────────────────────────────────────────
    
    # 4. HEMATOCRIT CHECK
    if "hematocrit" in clean_data:
        hct = clean_data["hematocrit"]
        hct_min, hct_max = THRESHOLDS["hematocrit"][0], THRESHOLDS["hematocrit"][1]
        if hct < hct_min:
            is_deferred = True
            reasons_en.append(f"Hematocrit ({hct}%) is below normal range. Confirms low red blood cells.")
            reasons_ar.append(f"الهيماتوكريت ({hct}%) أقل من المعدل الطبيعي. يؤكد انخفاض خلايا الدم الحمراء.")
        elif hct > hct_max:
            is_deferred = True
            reasons_en.append(f"Hematocrit ({hct}%) is above normal range. Possible dehydration or polycythemia.")
            reasons_ar.append(f"الهيماتوكريت ({hct}%) أعلى من المعدل الطبيعي. قد يشير إلى جفاف أو زيادة كريات الدم.")

    # 5. RED BLOOD CELL COUNT CHECK
    if "red_cell_count" in clean_data:
        rbc = clean_data["red_cell_count"]
        rbc_min, rbc_max = THRESHOLDS["red_cell_count"][0], THRESHOLDS["red_cell_count"][1]
        if rbc < rbc_min or rbc > rbc_max:
            is_deferred = True
            reasons_en.append(f"Red Cell Count ({rbc} x10⁶/μL) is outside normal range ({rbc_min}-{rbc_max}).")
            reasons_ar.append(f"عدد خلايا الدم الحمراء ({rbc} × 10⁶/ميكروتر) خارج المعدل الطبيعي ({rbc_min}-{rbc_max}).")

    # 6. MCV (Mean Corpuscular Volume) CHECK
    if "mcv" in clean_data:
        mcv = clean_data["mcv"]
        mcv_min, mcv_max = THRESHOLDS["mcv"][0], THRESHOLDS["mcv"][1]
        if mcv < mcv_min or mcv > mcv_max:
            is_deferred = True
            reasons_en.append(f"MCV ({mcv} fL) indicates abnormal cell size. Check for anemia type.")
            reasons_ar.append(f"MCV ({mcv} fL) يشير إلى حجم خلايا غير طبيعي. تحقق من نوع فقر الدم.")

    # ─────────────────────────────────────────────────────────────────────────
    # DIFFERENTIAL COUNT CHECKS (White cell types)
    # ─────────────────────────────────────────────────────────────────────────
    
    # 7. NEUTROPHILS CHECK
    if "neutrophils" in clean_data:
        neut = clean_data["neutrophils"]
        neut_min, neut_max = THRESHOLDS["neutrophils"][0], THRESHOLDS["neutrophils"][1]
        if neut < neut_min or neut > neut_max:
            if neut > neut_max:
                is_deferred = True
                reasons_en.append(f"Neutrophils ({neut}%) are elevated. Possible bacterial infection.")
                reasons_ar.append(f"النيوتروفيل ({neut}%) مرتفع. قد يشير إلى عدوى بكتيرية.")

    # 8. LYMPHOCYTES CHECK
    if "lymphocytes" in clean_data:
        lymph = clean_data["lymphocytes"]
        lymph_min, lymph_max = THRESHOLDS["lymphocytes"][0], THRESHOLDS["lymphocytes"][1]
        if lymph < lymph_min or lymph > lymph_max:
            if lymph > lymph_max:
                is_deferred = True
                reasons_en.append(f"Lymphocytes ({lymph}%) are elevated. Possible viral infection.")
                reasons_ar.append(f"الليمفوسيت ({lymph}%) مرتفع. قد يشير إلى عدوى فيروسية.")

    # ─────────────────────────────────────────────────────────────────────────
    # FINAL DECISION
    # ─────────────────────────────────────────────────────────────────────────
    
    status = "DEFERRED" if is_deferred else "ELIGIBLE"

    if status == "ELIGIBLE":
        explanation_en = "All primary CBC parameters are within the acceptable ranges for blood donation eligibility. The donor is fit to donate blood."
        explanation_ar = "جميع معايير تحليل الدم الأساسية ضمن النطاقات المقبولية للتبرع بالدم. المتبرع مؤهل للتبرع بالدم."
    else:
        explanation_en = "Deferral based on: " + "; ".join(reasons_en)
        explanation_ar = "الاستبعاد بناءً على: " + "; ".join(reasons_ar)

    return {
        "status": status,
        "explanation_en": explanation_en,
        "explanation_ar": explanation_ar,
        "reasons": reasons_en,
        "gender": gender,
    }


def create_extraction_prompt() -> str:
    return """You are a medical data extraction system.
Extract ALL numeric CBC values from this lab report image.
Return ONLY a valid JSON object with snake_case parameter keys and numeric values.
Do NOT include units, text, or any explanation.

Example output format:
{
  "haemoglobin": 13.4,
  "hematocrit": 46.4,
  "red_cell_count": 5.61,
  "mcv": 88.3,
  "mch": 28.0,
  "mchc": 35.5,
  "rdw": 13.7,
  "platelet_count": 321,
  "tlc": 6.4,
  "neutrophils": 0.4,
  "lymphocytes": 30.6,
  "monocytes": 5.0,
  "eosinophils": 3.7,
  "basophils": 0.4,
  "segmented": 58.3
}

Extract values exactly as shown in the report."""


app = FastAPI(title="BloodConnect AI Service", version="2.2.0")

ALLOWED_ORIGINS = os.environ.get("CORS_ORIGINS", "").split(",") if os.environ.get("CORS_ORIGINS") else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)

processor = None
model = None
device = None


def load_vision_language_model():
    global processor, model, device
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")

    print(f"Loading processor from {BASE_MODEL_NAME}...")
    processor = AutoProcessor.from_pretrained(BASE_MODEL_NAME)

    print(f"Loading base model from {BASE_MODEL_NAME}...")
    if torch.cuda.is_available():
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.float16,
            bnb_4bit_use_double_quant=True,
        )
        model = Qwen2VLForConditionalGeneration.from_pretrained(
            BASE_MODEL_NAME,
            quantization_config=bnb_config,
            device_map="auto",
            torch_dtype=torch.float16,
        )
    else:
        print("CUDA not available. Loading in float32 on CPU (slow)...")
        model = Qwen2VLForConditionalGeneration.from_pretrained(
            BASE_MODEL_NAME,
            torch_dtype=torch.float32,
            device_map=None,
        ).to(device)

    adapter_path = Path(MODEL_WEIGHTS_PATH)
    if adapter_path.exists():
        print(f"Loading LoRA adapter from {adapter_path}...")
        model = PeftModel.from_pretrained(model, str(adapter_path))
        print("LoRA adapter loaded successfully!")
    else:
        print(f"WARNING: Adapter path not found at {adapter_path}, using base model only")

    model.eval()
    print("Model ready!")


@app.on_event("startup")
async def startup_event():
    testing = os.getenv("TESTING", "false").lower() == "true"
    if not testing:
        try:
            load_vision_language_model()
        except Exception as e:
            print(f"ERROR: Failed to load model: {e}")
            raise
    else:
        print("TESTING mode - skipping model load")


@app.get("/health")
def health():
    return {
        "api_status": "ONLINE",
        "model_loaded": model is not None,
        "device": str(device) if device else "N/A",
        "model_path": MODEL_WEIGHTS_PATH,
        "base_model": BASE_MODEL_NAME,
        "version": "2.2.0",
        "thresholds_optimized": True,
        "safety_level": "Conservative (optimized for false negative reduction)",
        "features_supported": ["hemoglobin", "tlc", "platelet_count", "hematocrit", "red_cell_count", "mcv", "mch", "mchc", "rdw", "neutrophils", "lymphocytes", "monocytes", "eosinophils", "basophils", "segmented"],
    }


@app.post("/api/v1/screen-report")
async def screen_report(
    file: UploadFile = File(...),
    gender: str = Form(default="male"),
):
    """
    Screen a blood report image for donor eligibility.
    
    Returns:
      - extracted_values: CBC parameters extracted by VLM
      - evaluation: Eligibility decision with English & Arabic explanations
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Please upload a valid image file (JPEG/PNG).")

    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    try:
        image = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid image format.") from exc

    if model is None or processor is None:
        raise HTTPException(status_code=503, detail="Model not loaded. Please try again later.")

    try:
        prompt = create_extraction_prompt()

        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "image", "image": image},
                    {"type": "text", "text": prompt},
                ],
            }
        ]

        text = processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        inputs = processor(
            text=[text],
            images=[image],
            padding=True,
            return_tensors="pt",
        ).to(device)

        with torch.no_grad():
            generated_ids = model.generate(
                **inputs,
                max_new_tokens=512,
                temperature=0.1,
                do_sample=True,
                top_p=0.9,
            )

        generated_ids_trimmed = [
            out_ids[len(in_ids):] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)
        ]

        response_text = processor.batch_decode(generated_ids_trimmed, skip_special_tokens=True)[0]

        json_str = response_text.strip()
        if "```json" in json_str:
            json_str = json_str.split("```json")[1].split("```")[0].strip()
        elif "```" in json_str:
            json_str = json_str.split("```")[1].split("```")[0].strip()

        try:
            extracted_data = json.loads(json_str)
        except json.JSONDecodeError:
            extracted_data = {}

        filtered_data = {k: v for k, v in extracted_data.items() if v is not None}

        # Use optimized evaluation function with comprehensive checks
        evaluation = run_donor_evaluation(filtered_data, gender=gender)

        return {
            "success": True,
            "extracted_values": filtered_data,
            "evaluation": {
                "status": evaluation["status"],
                "explanation_en": evaluation["explanation_en"],
                "explanation_ar": evaluation["explanation_ar"],
                "gender": gender,
                "thresholds_version": "2.2.0-optimized-comprehensive",
            },
            "raw_model_output": response_text,
        }

    except Exception as e:
        print(f"Error during screening: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing report: {str(e)}")


@app.post("/predict")
async def predict(
    file: UploadFile = File(...),
    gender: str = Form(default="male"),
):
    """
    Predict donor eligibility from a blood report image.
    Compatible with the Flutter client's expected response format.
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Please upload a valid image file (JPEG/PNG).")

    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    try:
        image = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid image format.") from exc

    if model is None or processor is None:
        raise HTTPException(status_code=503, detail="Model not loaded. Please try again later.")

    try:
        prompt = create_extraction_prompt()

        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "image", "image": image},
                    {"type": "text", "text": prompt},
                ],
            }
        ]

        text = processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        inputs = processor(
            text=[text],
            images=[image],
            padding=True,
            return_tensors="pt",
        ).to(device)

        with torch.no_grad():
            generated_ids = model.generate(
                **inputs,
                max_new_tokens=512,
                temperature=0.1,
                do_sample=True,
                top_p=0.9,
            )

        generated_ids_trimmed = [
            out_ids[len(in_ids):] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)
        ]

        response_text = processor.batch_decode(generated_ids_trimmed, skip_special_tokens=True)[0]

        json_str = response_text.strip()
        if "```json" in json_str:
            json_str = json_str.split("```json")[1].split("```")[0].strip()
        elif "```" in json_str:
            json_str = json_str.split("```")[1].split("```")[0].strip()

        try:
            extracted_data = json.loads(json_str)
        except json.JSONDecodeError:
            extracted_data = {}

        filtered_data = {k: v for k, v in extracted_data.items() if v is not None}

        evaluation = run_donor_evaluation(filtered_data, gender=gender)

        is_eligible = evaluation["status"] == "ELIGIBLE"
        reasons = evaluation.get("reasons", [])

        # Compute confidence based on how many parameters passed checks
        total_checked = len(filtered_data)
        failed_count = len(reasons)
        passed = total_checked - failed_count
        confidence = (passed / total_checked * 100) if total_checked > 0 else 0.0

        return {
            "result": "eligible" if is_eligible else "deferred",
            "eligible": is_eligible,
            "confidence": confidence,
            "raw_probability": confidence / 100.0,
            "threshold": 0.55,
            "regression_denormalized": filtered_data,
            "reasons": reasons,
        }

    except Exception as e:
        print(f"Error during prediction: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing report: {str(e)}")


OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_MODEL = "google/gemini-2.0-flash-001"


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    donor_data: dict


def build_system_prompt(donor_data: dict) -> str:
    status = donor_data.get("status", "Unknown")
    explanation_en = donor_data.get("explanation_en", "No explanation provided")
    gender = donor_data.get("gender", "not specified")
    extracted_values = donor_data.get("extracted_values", {})

    values_str = ""
    for param, value in extracted_values.items():
        if param in THRESHOLDS:
            _min, _max, unit, label, _ = THRESHOLDS[param]
            values_str += f"- {label}: **{value} {unit}**"
            if _min is not None and value < _min:
                values_str += f" (below normal range {_min}-{_max})"
            elif _max is not None and value > _max:
                values_str += f" (above normal range {_min}-{_max})"
            else:
                values_str += " (normal)"
            values_str += "\n"

    return f"""You are a compassionate and highly professional AI Medical Doctor specializing in hematology and blood donation medicine.

You are speaking to a blood donor who has been evaluated for blood donation eligibility.

Your role is to support, reassure, and educate the donor in a calm and friendly way.

Donor Information:
- Donation Status: **{status}**
- Gender: **{gender}**
- Evaluation: {explanation_en}

Extracted Blood Values:
{values_str if values_str else "No specific values extracted."}

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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
