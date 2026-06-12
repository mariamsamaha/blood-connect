# ai-service/conftest.py
from unittest.mock import patch, MagicMock
import torch
import torch.nn as nn

_stub = MagicMock(spec=nn.Module)
_stub.eval.return_value = _stub
_stub.to.return_value   = _stub
_stub.load_state_dict.return_value = None
_stub.return_value = (torch.zeros(1, 7), torch.zeros(1, 2))

_fake_state_dict = {
    "regression_head.block1.0.weight": torch.zeros(256, 768),
    "regression_head.block2.0.weight": torch.zeros(128, 256),
    "regression_head.block3.0.weight": torch.zeros(64, 128),
    "regression_head.output.weight":   torch.zeros(7, 64),
    "classify_head.0.weight":          torch.zeros(128, 768),
}


def pytest_configure(config):
    patch("pathlib.Path.exists", return_value=True).start()
    patch("torch.load", return_value=_fake_state_dict).start()
    patch("main.MedicalViT", return_value=_stub).start()
