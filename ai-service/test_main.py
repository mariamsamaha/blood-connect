# =============================================================================
# test_main.py — Clinical Safety & Risk Assessment Test Suite (v2.2.0)
# =============================================================================
import pytest
import json
import io
from fastapi.testclient import TestClient
from PIL import Image
from main import app

client = TestClient(app)


# ─── Helpers ──────────────────────────────────────────────────────────────────
def make_image_bytes(color=(200, 200, 200), size=(280, 280)) -> bytes:
    """Creates a blank RGB image as upload bytes."""
    img = Image.new("RGB", size, color=color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


# ─── 1. Health Check ──────────────────────────────────────────────────────────
def test_health_endpoint():
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert "api_status" in body
    assert body["api_status"] == "ONLINE"
    assert body["version"] == "2.2.0"
    assert body["thresholds_optimized"] is True


# ─── 2. Endpoint Contract ─────────────────────────────────────────────────────
def test_screen_report_returns_expected_keys():
    img_bytes = make_image_bytes()
    r = client.post(
        "/api/v1/screen-report",
        files={"file": ("report.jpg", img_bytes, "image/jpeg")},
        data={"gender": "male"},
    )
    if r.status_code == 503:
        pytest.skip("Model not loaded in test environment")
    assert r.status_code == 200
    body = r.json()
    assert "success" in body
    assert "evaluation" in body
    eval_block = body["evaluation"]
    assert "status" in eval_block
    assert "explanation_en" in eval_block
    assert "explanation_ar" in eval_block


def test_invalid_file_format_rejected():
    r = client.post(
        "/api/v1/screen-report",
        files={"file": ("report.pdf", b"%PDF fake", "application/pdf")},
        data={"gender": "male"},
    )
    body = r.json()
    if r.status_code == 200:
        assert body.get("success") is False
    else:
        assert r.status_code == 400


# ─── 3. Clinical Rule Engine — Unit Tests (v2.2.0 thresholds) ────────────────
from main import run_donor_evaluation


RULE_CASES = [
    # Normal cases
    ("Normal male",          {"hemoglobin": 15.0, "tlc": 7.0,  "platelet_count": 250}, "male",   "ELIGIBLE"),
    ("Normal female",        {"hemoglobin": 13.5, "tlc": 6.5,  "platelet_count": 220}, "female", "ELIGIBLE"),
    # Hemoglobin
    ("Low Hb male",          {"hemoglobin": 12.5, "tlc": 7.0,  "platelet_count": 250}, "male",   "DEFERRED"),
    ("Low Hb female",        {"hemoglobin": 11.5, "tlc": 7.0,  "platelet_count": 250}, "female", "DEFERRED"),
    ("High Hb male",         {"hemoglobin": 18.0, "tlc": 7.0,  "platelet_count": 250}, "male",   "DEFERRED"),
    # TLC
    ("High TLC (infection)", {"hemoglobin": 15.0, "tlc": 12.0, "platelet_count": 250}, "male",   "DEFERRED"),
    ("Low TLC (immunity)",   {"hemoglobin": 15.0, "tlc": 3.5,  "platelet_count": 250}, "male",   "DEFERRED"),
    # Platelets
    ("Low platelets",        {"hemoglobin": 15.0, "tlc": 7.0,  "platelet_count": 120}, "male",   "DEFERRED"),
    ("High platelets",       {"hemoglobin": 15.0, "tlc": 7.0,  "platelet_count": 500}, "male",   "DEFERRED"),
    # Boundaries (v2.2.0: hgb min is 13.5 for male, plt min is 180)
    ("Boundary Hb male",     {"hemoglobin": 13.5, "tlc": 7.0,  "platelet_count": 250}, "male",   "ELIGIBLE"),
    ("Below boundary Hb male", {"hemoglobin": 13.4, "tlc": 7.0, "platelet_count": 250}, "male", "DEFERRED"),
    ("Boundary platelets",   {"hemoglobin": 15.0, "tlc": 7.0,  "platelet_count": 180}, "male",   "ELIGIBLE"),
    ("Below boundary platelets", {"hemoglobin": 15.0, "tlc": 7.0, "platelet_count": 179}, "male", "DEFERRED"),
]


@pytest.mark.parametrize("desc,data,gender,expected", RULE_CASES)
def test_rule_engine_decisions(desc, data, gender, expected):
    result = run_donor_evaluation(data, gender=gender)
    assert result["status"] == expected, (
        f"FAILED [{desc}]: got {result['status']}, expected {expected}\n"
        f"  Reason: {result['explanation_en']}"
    )


# ─── 4. Safety Critical — False Negative Detection ───────────────────────────
ABNORMAL_CASES = [
    {"hemoglobin": 11.0, "tlc": 7.0,  "platelet_count": 250},   # Low Hb
    {"hemoglobin": 15.0, "tlc": 13.0, "platelet_count": 250},   # High TLC
    {"hemoglobin": 15.0, "tlc": 7.0,  "platelet_count": 100},   # Low PLT
    {"hemoglobin": 19.0, "tlc": 7.0,  "platelet_count": 250},   # High Hb
    {"hemoglobin": 15.0, "tlc": 3.0,  "platelet_count": 250},   # Low TLC
    {"hemoglobin": 15.0, "tlc": 7.0,  "platelet_count": 500},   # High PLT
    {"hemoglobin": 12.0, "tlc": 7.0,  "platelet_count": 250},   # Low Hb female
]

def test_zero_false_negatives_on_abnormal_cases():
    """
    CRITICAL SAFETY TEST:
    Every abnormal hematological profile MUST be deferred.
    Any ELIGIBLE result here = False Negative = patient safety failure.
    """
    false_negatives = []
    for case in ABNORMAL_CASES:
        result = run_donor_evaluation(case, gender="male")
        if result["status"] == "ELIGIBLE":
            false_negatives.append({"input": case, "output": result})

    assert len(false_negatives) == 0, (
        f"CRITICAL: {len(false_negatives)} False Negative(s) detected!\n"
        + json.dumps(false_negatives, indent=2)
    )


# ─── 5. Bilingual Output Validation ──────────────────────────────────────────
def test_arabic_explanation_present_on_deferral():
    result = run_donor_evaluation({"hemoglobin": 10.0}, gender="male")
    assert result["status"] == "DEFERRED"
    assert len(result["explanation_ar"]) > 10, "Arabic explanation missing on deferral"


def test_both_languages_present_on_eligibility():
    result = run_donor_evaluation(
        {"hemoglobin": 15.0, "tlc": 7.0, "platelet_count": 250}, gender="male"
    )
    assert result["status"] == "ELIGIBLE"
    assert len(result["explanation_en"]) > 10
    assert len(result["explanation_ar"]) > 10


# ─── 6. Gender-Specific Hemoglobin Thresholds (v2.2.0) ──────────────────────
def test_female_low_hb_deferred():
    result = run_donor_evaluation({"hemoglobin": 12.0}, gender="female")
    assert result["status"] == "DEFERRED"


def test_male_low_hb_deferred():
    result = run_donor_evaluation({"hemoglobin": 13.0}, gender="male")
    assert result["status"] == "DEFERRED"


def test_female_normal_hb_eligible():
    result = run_donor_evaluation({"hemoglobin": 13.5}, gender="female")
    assert result["status"] == "ELIGIBLE"


def test_male_normal_hb_eligible():
    result = run_donor_evaluation({"hemoglobin": 14.0}, gender="male")
    assert result["status"] == "ELIGIBLE"


# ─── 7. Key Normalization Tests ──────────────────────────────────────────────
def test_vlm_key_normalization():
    """Test that VLM output keys like 'haemoglobin', 'rbc', 'plt' are normalized."""
    result = run_donor_evaluation(
        {"haemoglobin": 15.0, "rbc": 5.0, "plt": 250, "wbc": 7.0}, gender="male"
    )
    assert result["status"] == "ELIGIBLE"


def test_vlm_abnormal_key_normalization():
    """Test that abnormal values with VLM-style keys are caught."""
    result = run_donor_evaluation(
        {"haemoglobin": 10.0, "wbc": 15.0}, gender="male"
    )
    assert result["status"] == "DEFERRED"
    assert len(result["reasons"]) >= 2
