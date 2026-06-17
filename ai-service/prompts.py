"""OpenRouter prompt variants for A/B testing (A8)."""

import random
import time
from typing import TypedDict


class PromptVariant(TypedDict):
    id: str
    description: str
    weight: float
    system_prompt: str
    temperature: float
    max_tokens: int


VARIANTS: list[PromptVariant] = [
    {
        "id": "v1",
        "description": "Baseline — detailed medical assistant",
        "weight": 0.7,
        "system_prompt": (
            "You are a medical information assistant for a blood donation center. "
            "You help explain blood test results and donation eligibility. "
            "Always include a disclaimer that this is not medical advice. "
            "Never tell a user to donate blood if they have been deferred by a clinician. "
            "Never encourage ignoring medical advice or falsifying health information."
        ),
        "temperature": 0.3,
        "max_tokens": 800,
    },
    {
        "id": "v2",
        "description": "Shorter — concise responses",
        "weight": 0.3,
        "system_prompt": (
            "You are a concise medical assistant for a blood donation center. "
            "Give brief, accurate explanations of blood test results. "
            "Always disclaim: this is not medical advice. "
            "Never encourage donating if deferred, ignoring doctors, or falsifying health info."
        ),
        "temperature": 0.2,
        "max_tokens": 400,
    },
]


_AB_COUNTER = 0
_AB_CHOSEN: str | None = None


def pick_variant() -> PromptVariant:
    """Select a prompt variant based on weighted random distribution."""
    global _AB_COUNTER, _AB_CHOSEN
    weights = [v["weight"] for v in VARIANTS]
    chosen = random.choices(VARIANTS, weights=weights, k=1)[0]
    _AB_COUNTER += 1
    _AB_CHOSEN = chosen["id"]
    return chosen


def ab_variant_id() -> str | None:
    """Return the variant ID chosen for the current request."""
    return _AB_CHOSEN


def ab_variant_stats() -> dict:
    """Return A/B test distribution stats (for monitoring)."""
    return {
        "total_requests": _AB_COUNTER,
        "current_variant": _AB_CHOSEN,
        "variants": [{"id": v["id"], "weight": v["weight"], "description": v["description"]} for v in VARIANTS],
    }
