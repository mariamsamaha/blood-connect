# ai-service/conftest.py
from unittest.mock import patch, MagicMock
import torch
import torch.nn as nn

# Build fake state_dict and stub model before anything imports main.py
_fake_state_dict = {
    "patch_embed.weight":                    torch.zeros(64, 3, 16, 16),
    "patch_embed.bias":                      torch.zeros(64),
    "transformer.layers.0.0.to_qkv.weight": torch.zeros(192, 64),
    "reg_head.0.weight":                     torch.zeros(32, 64),
    "reg_head.2.weight":                     torch.zeros(7, 32),
    "classify_head.0.weight":                torch.zeros(32, 64),
    "classify_head.2.weight":                torch.zeros(2, 32),
}

_stub = MagicMock(spec=nn.Module)
_stub.eval.return_value = _stub
_stub.to.return_value   = _stub
_stub.load_state_dict.return_value = None
_stub.return_value = (torch.zeros(1, 7), torch.zeros(1, 2))


def pytest_configure(config):
    """Runs before collection — patches are active when test_main.py imports main."""
    patch("pathlib.Path.exists", return_value=True).start()
    patch("torch.load",          return_value=_fake_state_dict).start()
    patch("torch.nn.Module.load_state_dict", return_value=None).start()
