# conftest.py
import os
os.environ["TESTING"] = "true"

import pytest


@pytest.fixture(scope="session", autouse=True)
def set_test_env():
    """Ensures model loading errors don't crash rule-engine-only tests."""
    import main
    # Disable rate limiting during tests
    if hasattr(main, 'app') and hasattr(main.app.state, 'limiter'):
        main.app.state.limiter.enabled = False
    yield