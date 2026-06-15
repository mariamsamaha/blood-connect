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

MALE_MIN_HEMOGLOBIN = 13.5
FEMALE_MIN_HEMOGLOBIN = 12.5
MALE_MAX_HEMOGLOBIN = 17.5
FEMALE_MAX_HEMOGLOBIN = 16.0

THRESHOLDS = {
    "hemoglobin": (13.5, 17.5, "g/dL", "Hemoglobin", "Hb"),
    "tlc": (4.5, 10.5, "x10³/μL", "Total Leukocyte Count", "TLC"),
    "platelet_count": (180.0, 400.0, "x10³/μL", "Platelet Count", "Plt"),
    "hematocrit": (38.0, 52.0, "%", "Hematocrit", "Hct"),
    "red_cell_count": (4.5, 5.5, "x10⁶/μL", "Red Cell Count", "RBC"),
    "mcv": (80.0, 100.0, "fL", "Mean Corpuscular Volume", "MCV"),
    "mch": (27.0, 33.0, "pg", "Mean Corpuscular Hemoglobin", "MCH"),
    "mchc": (32.0, 36.0, "g/dL", "Mean Corpuscular Hemoglobin Concentration", "MCHC"),
    "rdw": (11.5, 14.5, "%", "Red Cell Distribution Width", "RDW"),
    "neutrophils": (40.0, 75.0, "%", "Neutrophils", "Neut"),
    "lymphocytes": (20.0, 45.0, "%", "Lymphocytes", "Lymph"),
    "monocytes": (2.0, 10.0, "%", "Monocytes", "Mono"),
    "eosinophils": (1.0, 6.0, "%", "Eosinophils", "Eos"),
    "basophils": (0.0, 2.0, "%", "Basophils", "Baso"),
    "segmented": (40.0, 75.0, "%", "Segmented Neutrophils", "Seg"),
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
    Normalize all extracted keys to lowercase.
    Fix decimal vs percentage for differential counts.
    """
    normalized = {}

    DIFFERENTIAL_KEYS = {
        "neutrophils", "lymphocytes", "monocytes",
        "eosinophils", "basophils", "segmented"
    }

    for k, v in extracted_data.items():
        norm_key = k.lower().strip()

        # Key normalization
        norm_key = norm_key.replace("haemoglobin", "hemoglobin")
        norm_key = norm_key.replace("hb", "hemoglobin") if norm_key == "hb" else norm_key
        norm_key = norm_key.replace("rbc", "red_cell_count") if norm_key == "rbc" else norm_key
        norm_key = norm_key.replace("red cell count", "red_cell_count")
        norm_key = norm_key.replace("rdw_cv", "rdw")
        norm_key = norm_key.replace("platelets", "platelet_count") if norm_key == "platelets" else norm_key
        norm_key = norm_key.replace("plt", "platelet_count") if norm_key == "plt" else norm_key
        norm_key = norm_key.replace("platelet count", "platelet_count")
        norm_key = norm_key.replace("wbc", "tlc") if norm_key == "wbc" else norm_key
        norm_key = norm_key.replace("leukocytes", "tlc") if norm_key == "leukocytes" else norm_key
        norm_key = norm_key.replace("total leukocyte count", "tlc")
        norm_key = norm_key.replace("total leucocyte count", "tlc")
        norm_key = norm_key.replace("t.l.c", "tlc")
        norm_key = norm_key.replace("tlc", "tlc")

        try:
            val = float(v)

            # Fix differential counts: convert decimal to percentage if needed
            if norm_key in DIFFERENTIAL_KEYS and val < 2.0:
                val = val * 100

            normalized[norm_key] = val
        except (ValueError, TypeError):
            continue

    return normalized


def run_donor_evaluation(extracted_data: dict, gender: str = "male") -> dict:
    is_deferred = False
    reasons_en = []
    reasons_ar = []

    clean_data = normalize_extracted_data(extracted_data)

    # DEBUG — print what was extracted
    print(f"[DEBUG] Gender: {gender}")
    print(f"[DEBUG] Normalized data: {json.dumps(clean_data, indent=2)}")

    # 1. HEMOGLOBIN
    hb_min = FEMALE_MIN_HEMOGLOBIN if gender.lower() == "female" else MALE_MIN_HEMOGLOBIN
    hb_max = FEMALE_MAX_HEMOGLOBIN if gender.lower() == "female" else MALE_MAX_HEMOGLOBIN

    if "hemoglobin" in clean_data:
        hb = clean_data["hemoglobin"]
        if hb < hb_min:
            is_deferred = True
            reasons_en.append(f"Hemoglobin ({hb} g/dL) is below the minimum safe range ({hb_min} g/dL) for {gender} donors. Risk of anemia post-donation.")
            reasons_ar.append(f"مستوى الهيموغلوبين ({hb} جم/ديسيلتر) أقل من الحد الآمن ({hb_min} جم/ديسيلتر). خطر فقر الدم بعد التبرع.")
        elif hb > hb_max:
            is_deferred = True
            reasons_en.append(f"Hemoglobin ({hb} g/dL) exceeds the maximum safe range ({hb_max} g/dL). Potential blood viscosity concerns.")
            reasons_ar.append(f"مستوى الهيموغلوبين ({hb} جم/ديسيلتر) يتجاوز الحد الأقصى الآمن ({hb_max} جم/ديسيلتر).")
    else:
        # If hemoglobin not extracted at all — defer for safety
        is_deferred = True
        reasons_en.append("Hemoglobin value could not be extracted from the report. Manual review required.")
        reasons_ar.append("لم يتم استخراج قيمة الهيموغلوبين من التقرير. يلزم المراجعة اليدوية.")

    # 2. TLC
    if "tlc" in clean_data:
        tlc = clean_data["tlc"]
        tlc_min, tlc_max = THRESHOLDS["tlc"][0], THRESHOLDS["tlc"][1]
        if tlc < tlc_min:
            is_deferred = True
            reasons_en.append(f"Total Leukocyte Count ({tlc} x10³/μL) is below normal range ({tlc_min}-{tlc_max}). Indicates immunocompromise.")
            reasons_ar.append(f"عدد خلايا الدم البيضاء ({tlc}) أقل من المعدل الطبيعي.")
        elif tlc > tlc_max:
            is_deferred = True
            reasons_en.append(f"Total Leukocyte Count ({tlc} x10³/μL) is above normal range ({tlc_min}-{tlc_max}). Possible active infection.")
            reasons_ar.append(f"عدد خلايا الدم البيضاء ({tlc}) يتجاوز المعدل الطبيعي.")

    # 3. PLATELET COUNT
    if "platelet_count" in clean_data:
        plt = clean_data["platelet_count"]
        plt_min, plt_max = THRESHOLDS["platelet_count"][0], THRESHOLDS["platelet_count"][1]
        if plt < plt_min:
            is_deferred = True
            reasons_en.append(f"Platelet count ({plt} x10³/μL) is below safe range ({plt_min}-{plt_max}). Risk of bleeding complications.")
            reasons_ar.append(f"عدد الصفيحات ({plt}) أقل من المعدل الآمن.")
        elif plt > plt_max:
            is_deferred = True
            reasons_en.append(f"Platelet count ({plt} x10³/μL) exceeds safe range ({plt_min}-{plt_max}). Potential thrombotic risk.")
            reasons_ar.append(f"عدد الصفيحات ({plt}) يتجاوز المعدل الآمن.")

    # 4. HEMATOCRIT
    if "hematocrit" in clean_data:
        hct = clean_data["hematocrit"]
        hct_min, hct_max = THRESHOLDS["hematocrit"][0], THRESHOLDS["hematocrit"][1]
        if hct < hct_min:
            is_deferred = True
            reasons_en.append(f"Hematocrit ({hct}%) is below normal range ({hct_min}-{hct_max}%). Confirms low red blood cells.")
            reasons_ar.append(f"الهيماتوكريت ({hct}%) أقل من المعدل الطبيعي.")
        elif hct > hct_max:
            is_deferred = True
            reasons_en.append(f"Hematocrit ({hct}%) is above normal range ({hct_min}-{hct_max}%). Possible dehydration.")
            reasons_ar.append(f"الهيماتوكريت ({hct}%) أعلى من المعدل الطبيعي.")

    # 5. RED BLOOD CELL COUNT
    if "red_cell_count" in clean_data:
        rbc = clean_data["red_cell_count"]
        rbc_min, rbc_max = THRESHOLDS["red_cell_count"][0], THRESHOLDS["red_cell_count"][1]
        if rbc < rbc_min or rbc > rbc_max:
            is_deferred = True
            reasons_en.append(f"Red Cell Count ({rbc} x10⁶/μL) is outside normal range ({rbc_min}-{rbc_max}).")
            reasons_ar.append(f"عدد خلايا الدم الحمراء ({rbc}) خارج المعدل الطبيعي.")

    # 6. MCHC — important flag in this report
    if "mchc" in clean_data:
        mchc = clean_data["mchc"]
        mchc_min, mchc_max = THRESHOLDS["mchc"][0], THRESHOLDS["mchc"][1]
        if mchc < mchc_min:
            is_deferred = True
            reasons_en.append(f"MCHC ({mchc} g/dL) is below normal range ({mchc_min}-{mchc_max}). Consistent with hypochromic anaemia.")
            reasons_ar.append(f"MCHC ({mchc} جم/ديسيلتر) أقل من المعدل الطبيعي. يتوافق مع فقر الدم نقص الصبغة.")
        elif mchc > mchc_max:
            is_deferred = True
            reasons_en.append(f"MCHC ({mchc} g/dL) is above normal range ({mchc_min}-{mchc_max}).")
            reasons_ar.append(f"MCHC ({mchc} جم/ديسيلتر) يتجاوز المعدل الطبيعي.")

    # 7. MCV
    if "mcv" in clean_data:
        mcv = clean_data["mcv"]
        mcv_min, mcv_max = THRESHOLDS["mcv"][0], THRESHOLDS["mcv"][1]
        if mcv < mcv_min or mcv > mcv_max:
            is_deferred = True
            reasons_en.append(f"MCV ({mcv} fL) indicates abnormal cell size.")
            reasons_ar.append(f"MCV ({mcv} fL) يشير إلى حجم خلايا غير طبيعي.")

    # 8. NEUTROPHILS
    if "neutrophils" in clean_data:
        neut = clean_data["neutrophils"]
        neut_min, neut_max = THRESHOLDS["neutrophils"][0], THRESHOLDS["neutrophils"][1]
        if neut > neut_max:
            is_deferred = True
            reasons_en.append(f"Neutrophils ({neut}%) are elevated. Possible bacterial infection.")
            reasons_ar.append(f"النيوتروفيل ({neut}%) مرتفع.")
        elif neut < neut_min:
            is_deferred = True
            reasons_en.append(f"Neutrophils ({neut}%) are low. Possible immunodeficiency.")
            reasons_ar.append(f"النيوتروفيل ({neut}%) منخفض.")

    # 9. LYMPHOCYTES
    if "lymphocytes" in clean_data:
        lymph = clean_data["lymphocytes"]
        lymph_min, lymph_max = THRESHOLDS["lymphocytes"][0], THRESHOLDS["lymphocytes"][1]
        if lymph > lymph_max:
            is_deferred = True
            reasons_en.append(f"Lymphocytes ({lymph}%) are elevated. Possible viral infection.")
            reasons_ar.append(f"الليمفوسيت ({lymph}%) مرتفع.")

    # FINAL DECISION
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
Return ONLY a valid JSON object with snake_case lowercase parameter keys and numeric values.
Do NOT include units, text, or any explanation.
Use these exact key names:
- haemoglobin (or hemoglobin)
- hematocrit
- red_cell_count
- mcv
- mch
- mchc
- rdw
- platelet_count
- tlc
- neutrophils (percentage, not absolute)
- lymphocytes (percentage, not absolute)
- monocytes (percentage, not absolute)
- eosinophils (percentage, not absolute)
- basophils (percentage, not absolute)
- segmented (percentage, not absolute)

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
  "neutrophils": 58.3,
  "lymphocytes": 30.6,
  "monocytes": 5.0,
  "eosinophils": 3.7,
  "basophils": 0.8,
  "segmented": 56.7
}

IMPORTANT: Extract percentage values for differential counts, NOT absolute counts.
Extract values exactly as shown in the report."""


app = FastAPI(title="BloodConnect AI Service", version="2.3.0")

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
        "version": "2.3.0",
        "thresholds_optimized": True,
    }


@app.post("/api/v1/screen-report")
async def screen_report(
    file: UploadFile = File(...),
    gender: str = Form(default="male"),
):
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
        print(f"[DEBUG] Raw model output: {response_text}")

        json_str = response_text.strip()
        if "```json" in json_str:
            json_str = json_str.split("```json")[1].split("```")[0].strip()
        elif "```" in json_str:
            json_str = json_str.split("```")[1].split("```")[0].strip()

        try:
            extracted_data = json.loads(json_str)
        except json.JSONDecodeError:
            print(f"[DEBUG] JSON parse failed: {json_str}")
            extracted_data = {}

        filtered_data = {k: v for k, v in extracted_data.items() if v is not None}
        print(f"[DEBUG] Filtered extracted data: {json.dumps(filtered_data, indent=2)}")

        evaluation = run_donor_evaluation(filtered_data, gender=gender)
        print(f"[DEBUG] Final decision: {evaluation['status']}")

        return {
            "success": True,
            "extracted_values": filtered_data,
            "evaluation": {
                "status": evaluation["status"],
                "explanation_en": evaluation["explanation_en"],
                "explanation_ar": evaluation["explanation_ar"],
                "gender": gender,
                "thresholds_version": "2.3.0",
            },
            "raw_model_output": response_text,
        }

    except Exception as e:
        print(f"Error during screening: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing report: {str(e)}")


# ── Predict alias endpoint ────────────────────────────────────────────────────
@app.post("/predict")
async def predict(
    file: UploadFile = File(...),
    gender: str = Form(default="male"),
):
    return await screen_report(file=file, gender=gender)


OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_MODEL = "google/gemini-2.5-flash"


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