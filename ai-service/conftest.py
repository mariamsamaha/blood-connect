# ai-service/conftest.py
# ─────────────────────────────────────────────────────────────────────────────
# Patches the ViT model loading so ALL pytest tests run in CI without a GPU
# or real model file. Must patch before main.py is imported — pytest loads
# conftest.py first, so session-scoped autouse fixtures achieve this.
# ─────────────────────────────────────────────────────────────────────────────
import pytest
import torch
import torch.nn as nn
from pathlib import Path
from unittest.mock import MagicMock, patch


@pytest.fixture(autouse=True, scope="session")
def mock_model_loading():
    """
    Intercepts the three things main.py does at import time:
      1. MODEL_PATH.exists()  — returns True so the guard doesn't raise
      2. torch.load()         — returns a fake state_dict
      3. MedicalViT(state_dict) + load_state_dict + eval + to(device)
         → returns a stub whose forward() produces the right output shape
    """

    # Fake state_dict — keys matching what MedicalViT.__init__ reads
    fake_state_dict = {
        "regression_head.block1.0.weight": torch.zeros(128, 768),
        "regression_head.block1.0.bias":   torch.zeros(128),
        "regression_head.block2.0.weight": torch.zeros(64, 128),
        "regression_head.block2.0.bias":   torch.zeros(64),
        "regression_head.block3.0.weight": torch.zeros(32, 64),
        "regression_head.block3.0.bias":   torch.zeros(32),
        "regression_head.output.weight":   torch.zeros(15, 32),
        "regression_head.output.bias":     torch.zeros(15),
        "classify_head.0.weight":          torch.zeros(64, 768),
        "classify_head.0.bias":            torch.zeros(64),
    }

    # Stub model — forward() returns (reg_out, cls_logits) matching real shape
    stub_model = MagicMock(spec=nn.Module)
    stub_model.eval.return_value = stub_model
    stub_model.to.return_value = stub_model
    stub_model.load_state_dict.return_value = None
    stub_model.forward.return_value = (
        torch.zeros(1, 15),  # reg_out — 15 regression parameters
        torch.zeros(1, 1),   # cls_logits — 1 logit (eligible / deferred)
    )

    with patch("pathlib.Path.exists", return_value=True), \
         patch("torch.load", return_value=fake_state_dict), \
         patch("main.MedicalViT", return_value=stub_model):
        yield stub_model
