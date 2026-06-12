# ai-service/conftest.py
import os
os.environ["TESTING"] = "true"

import torch
import torch.nn as nn
from unittest.mock import MagicMock
import pytest

_stub = MagicMock(spec=nn.Module)
_stub.eval.return_value = _stub
_stub.to.return_value   = _stub
_stub.return_value = (torch.zeros(1, 15), torch.zeros(1, 1))


@pytest.fixture(autouse=True)
def inject_model(monkeypatch):
    import main
    monkeypatch.setattr(main, "model", _stub)
