import io
import os
import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient
from PIL import Image
from main import app, denormalize, rules_decision, PARAM_NORM, THRESHOLDS

client = TestClient(app)


def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert data["model_loaded"] is True


def test_predict_no_file():
    resp = client.post("/predict")
    assert resp.status_code == 422


def test_predict_empty_file():
    resp = client.post("/predict", files={"file": ("empty.jpg", b"", "image/jpeg")})
    assert resp.status_code == 400
    assert "empty" in resp.json()["detail"].lower()


def test_predict_invalid_file():
    resp = client.post("/predict", files={"file": ("test.txt", b"not an image", "text/plain")})
    assert resp.status_code == 400


def test_denormalize():
    val = denormalize("hemoglobin", 0.5)
    expected = 0.5 * (PARAM_NORM["hemoglobin"][1] - PARAM_NORM["hemoglobin"][0]) + PARAM_NORM["hemoglobin"][0]
    assert abs(val - expected) < 0.01


def test_rules_decision_all_normal():
    values = {}
    for param in THRESHOLDS:
        mn, mx = THRESHOLDS[param][0], THRESHOLDS[param][1]
        values[param] = mn if mx is None else (mn + mx) / 2
    result, reasons = rules_decision(values)
    assert result == "Eligible"
    assert reasons == []


def test_rules_decision_low_hemoglobin():
    values = {"hemoglobin": 8.0}
    result, reasons = rules_decision(values)
    assert result == "Deferred"
    assert len(reasons) > 0
    assert "below" in reasons[0].lower()


def test_rules_decision_high_bp():
    values = {"systolic_bp": 180.0}
    result, reasons = rules_decision(values)
    assert result == "Deferred"
    assert len(reasons) > 0


def test_denormalize_all_params():
    for param, (mn, mx) in PARAM_NORM.items():
        normalized = 0.5
        val = denormalize(param, normalized)
        expected = 0.5 * (mx - mn) + mn
        assert abs(val - expected) < 0.01


def test_thresholds_structure():
    for param, (min_val, max_val, unit, label) in THRESHOLDS.items():
        assert param in PARAM_NORM
        assert isinstance(unit, str)
        assert isinstance(label, str)
        if max_val is not None:
            assert min_val < max_val


def test_rules_check_each_param():
    for param, (min_val, max_val, _unit, _label) in THRESHOLDS.items():
        if min_val is not None:
            values = {param: min_val - 1}
            result, _ = rules_decision(values)
            assert result == "Deferred", f"{param} below range should defer"
        if max_val is not None:
            values = {param: max_val + 1}
            result, _ = rules_decision(values)
            assert result == "Deferred", f"{param} above range should defer"


# ── AI Service Integration Tests ──────────────────────────────────────

def _synthetic_test_image():
    """Create a small RGB image buffer for predict endpoint tests."""
    img = Image.new("RGB", (224, 224), color=(128, 128, 128))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)
    return buf


def test_predict_with_synthetic_image_returns_15_params_and_logit():
    """Upload a synthetic test image and assert output shape."""
    buf = _synthetic_test_image()
    resp = client.post("/predict", files={"file": ("test.jpg", buf, "image/jpeg")})
    assert resp.status_code == 200
    data = resp.json()

    # 15 regression parameters
    reg_norm = data["regression_normalized"]
    assert isinstance(reg_norm, list)
    assert len(reg_norm) == 15

    reg_denorm = data["regression_denormalized"]
    assert isinstance(reg_denorm, dict)
    assert len(reg_denorm) == 15

    # 1 logit (eligibility confidence)
    assert "confidence" in data
    assert "raw_probability" in data
    assert isinstance(data["confidence"], (int, float))
    assert isinstance(data["raw_probability"], (int, float))

    # Shape assertions
    assert "result" in data
    assert "eligible" in data
    assert "reasons" in data
    assert isinstance(data["reasons"], list)


def test_predict_synthetic_image_different_formats():
    """Test predict with PNG format as well."""
    img = Image.new("RGB", (224, 224), color=(64, 128, 192))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    resp = client.post("/predict", files={"file": ("test.png", buf, "image/png")})
    assert resp.status_code == 200
    assert len(resp.json()["regression_normalized"]) == 15


def test_assistant_chat_with_valid_data_returns_reply():
    """Chat with valid donor_data — assert non-empty reply on success."""
    with patch.dict(os.environ, {"AI_ASSISTANT_API_KEY": "test-key"}, clear=False):
        payload = {
            "messages": [{"role": "user", "content": "Why was I deferred?"}],
            "donor_data": {
                "hemoglobin": 9.0,
                "reasons": ["Hemoglobin is below the safe range"],
                "confidence": 85.0,
            },
        }
        with patch("main.requests.post") as mock_post:
            mock_post.return_value.status_code = 200
            mock_post.return_value.json.return_value = {
                "choices": [{"message": {"content": "Your hemoglobin is slightly low. This is very common."}}]
            }
            resp = client.post("/assistant/chat", json=payload)
            assert resp.status_code == 200
            reply = resp.json()["reply"]
            assert isinstance(reply, str)
            assert len(reply) > 0
            assert "hemoglobin" in reply.lower()


def test_assistant_chat_missing_api_key_returns_500():
    """Chat with no API key configured — assert 500."""
    with patch.dict(os.environ, {}, clear=True):
        payload = {
            "messages": [{"role": "user", "content": "Hello"}],
            "donor_data": {"hemoglobin": 12.0},
        }
        resp = client.post("/assistant/chat", json=payload)
        assert resp.status_code == 500
        assert "not configured" in resp.json()["detail"].lower()


def test_assistant_chat_exceeds_max_messages():
    """Chat with more than 30 messages — assert 400."""
    with patch.dict(os.environ, {"AI_ASSISTANT_API_KEY": "test-key"}, clear=False):
        many_messages = [{"role": "user", "content": f"msg {i}"} for i in range(31)]
        payload = {
            "messages": many_messages,
            "donor_data": {"hemoglobin": 12.0},
        }
        resp = client.post("/assistant/chat", json=payload)
        assert resp.status_code == 400
        assert "too long" in resp.json()["detail"].lower()
