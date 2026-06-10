import pytest
from fastapi.testclient import TestClient
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
