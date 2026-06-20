#!/usr/bin/env python3
"""
BloodConnect AI Service — Performance Test Suite
===================================================

Targets ai-service/main.py directly. Every scenario below cites the exact
line(s) of main.py it is testing against.

KEY HYPOTHESIS UNDER TEST: the /predict endpoint (main.py line ~791) is
declared `async def`, but the model forward pass itself —

    with torch.no_grad():
        cls_logits, _cbc_values = vit_model(tensor)

— is a synchronous, CPU-bound call with no `await`, no
`asyncio.to_thread()`, and no `run_in_executor()`. Combined with a single
uvicorn worker (no --workers flag in the Dockerfile CMD, confirmed in
ai-service/Dockerfile), this predicts that concurrent requests to /predict
will NOT run in parallel — each request should block the entire event loop,
including the health check, for the full duration of its own inference.

This script does not assume that conclusion — it runs concurrent requests
and a sequential baseline, computes the ratio between them, and reports
that ratio as evidence either way.

No functional assertions are made about prediction accuracy. This is a
performance suite only.
"""
import argparse
import io
import json
import os
import statistics
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

try:
    import requests
except ImportError:
    print("✗ Missing dependency: pip install requests", file=sys.stderr)
    sys.exit(1)

try:
    from PIL import Image
except ImportError:
    print("✗ Missing dependency: pip install pillow", file=sys.stderr)
    sys.exit(1)

AI_BASE_URL = os.environ.get("PERF_AI_BASE_URL", "http://localhost:8000")
REPORT_DIR = Path(__file__).resolve().parent.parent / "reports"
CONCURRENCY_LEVELS = [int(x) for x in os.environ.get("PERF_AI_CONCURRENCY_LEVELS", "1,2,5,10").split(",")]
# AI service's own slowapi rate limiter on /predict is 30/minute per
# source IP (ai-service/main.py line ~793, @limiter.limit("30/minute")).
# Since this script and every concurrent thread share one source IP, this
# limit binds quickly during local testing. SAMPLES_PER_LEVEL is kept low
# by default specifically to stay under that ceiling across all levels
# combined within a rolling minute; raise PERF_AI_RATE_LIMIT_PER_MINUTE in
# the service's own .env for a real-headroom test run.
SAMPLES_PER_LEVEL = int(os.environ.get("PERF_AI_SAMPLES_PER_LEVEL", "3"))


def make_synthetic_cbc_image() -> bytes:
    """
    Generates a synthetic image for upload. This is NOT a real CBC report —
    it exists purely to exercise the /predict endpoint's full code path
    (file validation -> PIL decode -> tensor transform -> ViT forward pass
    -> optional OCR stage). Prediction *correctness* is out of scope for a
    performance suite; only latency and throughput are measured.
    """
    img = Image.new("RGB", (800, 1000), color=(255, 255, 255))
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=85)
    return buf.getvalue()


def call_predict(image_bytes: bytes, gender: str = "male") -> dict:
    start = time.perf_counter()
    try:
        resp = requests.post(
            f"{AI_BASE_URL}/predict",
            files={"file": (f"{uuid.uuid4().hex}.jpg", image_bytes, "image/jpeg")},
            data={"gender": gender},
            timeout=60,
        )
        elapsed_ms = (time.perf_counter() - start) * 1000
        return {
            "elapsedMs": elapsed_ms,
            "statusCode": resp.status_code,
            "ok": resp.status_code == 200,
            "rateLimited": resp.status_code == 429,
        }
    except requests.RequestException as e:
        elapsed_ms = (time.perf_counter() - start) * 1000
        return {"elapsedMs": elapsed_ms, "statusCode": None, "ok": False, "error": str(e)}


def call_health() -> dict:
    start = time.perf_counter()
    try:
        resp = requests.get(f"{AI_BASE_URL}/health", timeout=10)
        return {"elapsedMs": (time.perf_counter() - start) * 1000, "ok": resp.status_code == 200}
    except requests.RequestException as e:
        return {"elapsedMs": (time.perf_counter() - start) * 1000, "ok": False, "error": str(e)}


def percentile(data, p):
    if not data:
        return None
    s = sorted(data)
    idx = min(len(s) - 1, int((p / 100) * len(s)))
    return round(s[idx], 1)


def summarize(name, timings_ms, extra=None):
    summary = {
        "test": name,
        "iterations": len(timings_ms),
        "avgMs": round(statistics.mean(timings_ms), 1) if timings_ms else None,
        "minMs": round(min(timings_ms), 1) if timings_ms else None,
        "maxMs": round(max(timings_ms), 1) if timings_ms else None,
        "p50Ms": percentile(timings_ms, 50),
        "p95Ms": percentile(timings_ms, 95),
        **(extra or {}),
    }
    print(
        f"  {name}: avg={summary['avgMs']}ms p50={summary['p50Ms']}ms "
        f"p95={summary['p95Ms']}ms (n={summary['iterations']})"
    )
    return summary


def main():
    parser = argparse.ArgumentParser(description="BloodConnect AI service performance suite")
    parser.add_argument("--base-url", default=AI_BASE_URL)
    args = parser.parse_args()
    base_url = args.base_url

    print("═══════════════════════════════════════════════════════════")
    print(" BloodConnect AI Service — Performance Test Suite")
    print(f" Target: {base_url}")
    print("═══════════════════════════════════════════════════════════")

    results = {"generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "target": base_url, "tests": []}

    # ── 0. Hard reachability check ────────────────────────────────────────
    # Why: a "connection refused" error returns in 1-2ms, which is FASTER
    # than a real successful health check. Without this guard, a completely
    # unreachable service could otherwise be misread as a fast, healthy one
    # if a later code path ever averaged failed-call timings in with
    # successful ones (see git history of this file for that exact bug).
    initial_check = call_health()
    if not initial_check.get("ok"):
        print(
            f"\n✗ AI service is not reachable at {base_url} "
            f"({initial_check.get('error', 'unknown error')}).\n"
            f"  Refusing to proceed — see README.md \"Prerequisites\" to start the AI service first.\n",
        )
        sys.exit(1)

    # ── 1. Health check baseline (no model involved) ─────────────────────
    print("\n▶ Health check baseline (GET /health, no model inference)")
    health_timings = [call_health()["elapsedMs"] for _ in range(10)]
    results["tests"].append(summarize("Health check (no inference)", health_timings))

    # ── 2. Model loading / readiness check ────────────────────────────────
    # Why: main.py loads the ViT checkpoint at module import time (model.eval()
    # at line ~580), before the server starts accepting connections. This
    # means "model loading time" is a startup-time cost, not a per-request
    # cost — there is no lazy-loading code path to measure separately. This
    # test instead confirms the model is loaded and ready (GET /health
    # reports model status) before timing any inference below, so that a
    # cold-start mistakenly attributed to the first inference call is ruled out.
    print("\n▶ Confirming model is loaded before timing inference (GET /health)")
    try:
        health_resp = requests.get(f"{base_url}/health", timeout=10).json()
        model_loaded = health_resp.get("model_loaded", health_resp.get("vit_loaded", "unknown"))
        print(f"  /health reports: {json.dumps(health_resp)[:200]}")
        results["modelLoadedAtTestStart"] = model_loaded
    except Exception as e:
        print(f"  ⚠ Could not confirm model status: {e}")
        results["modelLoadedAtTestStart"] = "unknown"

    # ── 3. First-inference latency (cold cache, post-startup) ────────────
    print("\n▶ First inference call after suite start (cold-cache latency)")
    synthetic_image = make_synthetic_cbc_image()
    first = call_predict(synthetic_image)
    print(f"  First call: {first['elapsedMs']:.1f}ms, status={first.get('statusCode')}")
    results["tests"].append({"test": "First inference call", **first})

    # ── 4. Average sequential inference latency ───────────────────────────
    # Why: this is the single most directly comparable number to the
    # thesis's stated targets (AI prediction p95 < 30s, §4.2; CPU inference
    # "3-5s average, up to ~8s p95" claimed in an earlier draft and flagged
    # in docs/BENCHMARK.md as an unfilled template). This is, as far as this
    # suite is aware, the first time that number is actually measured rather
    # than estimated.
    print(f"\n▶ Sequential inference latency ({SAMPLES_PER_LEVEL * 2} requests, one at a time)")
    seq_timings = []
    seq_failures = 0
    for _ in range(SAMPLES_PER_LEVEL * 2):
        r = call_predict(synthetic_image)
        if r.get("rateLimited"):
            print("  ⚠ Hit the AI service's own 30/minute rate limit (slowapi) — stopping sequential run early.")
            break
        if r.get("ok"):
            seq_timings.append(r["elapsedMs"])
        else:
            seq_failures += 1
            failure_detail = r.get("error") or f"HTTP {r.get('statusCode')}"
            print(f"    ⚠ Request failed (not counted toward latency average): {failure_detail}")
        time.sleep(0.1)
    if seq_timings:
        results["tests"].append(summarize("Sequential inference (CPU, one at a time)", seq_timings, {"failedRequests": seq_failures}))
    else:
        print(f"  ✗ All {seq_failures} sequential requests failed — no latency average can be computed. Is the AI service actually running and reachable?")
        results["tests"].append({"test": "Sequential inference (CPU, one at a time)", "iterations": 0, "failedRequests": seq_failures, "avgMs": None})

    # ── 5. Concurrent inference at increasing levels ──────────────────────
    # Why: this is the test that directly confirms or refutes the blocking-
    # event-loop hypothesis described in this script's module docstring. If
    # the hypothesis is correct, total wall-clock time for N concurrent
    # requests should scale roughly LINEARLY with N (i.e. ~N times the
    # single-request latency), not stay flat the way it would on a properly
    # async or multi-worker service.
    print("\n▶ Concurrent inference at increasing levels (tests event-loop blocking hypothesis)")
    concurrency_results = []
    for level in CONCURRENCY_LEVELS:
        print(f"\n  -- Concurrency level: {level} --")
        with ThreadPoolExecutor(max_workers=level) as executor:
            wall_start = time.perf_counter()
            futures = [executor.submit(call_predict, synthetic_image) for _ in range(level)]
            call_results = [f.result() for f in futures]
            wall_elapsed_ms = (time.perf_counter() - wall_start) * 1000

        rate_limited_count = sum(1 for r in call_results if r.get("rateLimited"))
        ok_results = [r for r in call_results if r.get("ok")]
        failed_count = len(call_results) - len(ok_results) - rate_limited_count
        entry = {
            "concurrency": level,
            "wallClockMsForAllRequests": round(wall_elapsed_ms, 1),
            "successfulRequests": len(ok_results),
            "failedRequests": failed_count,
            "rateLimitedRequests": rate_limited_count,
            "individualLatenciesMs": [round(r["elapsedMs"], 1) for r in call_results],
            "avgIndividualLatencyMsOfSuccessfulRequests": (
                round(statistics.mean([r["elapsedMs"] for r in ok_results]), 1) if ok_results else None
            ),
        }
        concurrency_results.append(entry)
        print(
            f"    wall-clock for all {level} requests: {entry['wallClockMsForAllRequests']:.0f}ms | "
            f"successful={entry['successfulRequests']} failed={failed_count} rate_limited={rate_limited_count}",
        )
        if failed_count == level:
            print(f"    ✗ All {level} requests failed — is the AI service actually running and reachable at {base_url}?")
        if rate_limited_count > 0:
            print("    ⚠ Some requests hit the 30/minute rate limit — results above this point may undercount true concurrency capacity.")
            break
        time.sleep(2)  # brief pause between levels to avoid compounding rate-limit pressure

    results["concurrencyTest"] = concurrency_results

    # Compute the scaling ratio: wall-clock at the highest clean concurrency
    # level, divided by what it would be if perfectly parallel (= single
    # sequential latency), divided by the concurrency level itself.
    # A ratio near 1.0 means "scales like one request" (good, parallel).
    # A ratio near `level` means "scales like N sequential requests" (the
    # blocking hypothesis confirmed).
    if concurrency_results and seq_timings:
        baseline_single = statistics.mean(seq_timings)
        clean_results = [r for r in concurrency_results if r["rateLimitedRequests"] == 0]
        if clean_results:
            highest = clean_results[-1]
            ideal_parallel_ms = baseline_single
            actual_ms = highest["wallClockMsForAllRequests"]
            scaling_ratio = round(actual_ms / ideal_parallel_ms, 2) if ideal_parallel_ms else None
            results["blockingHypothesisFinding"] = {
                "concurrencyLevelTested": highest["concurrency"],
                "singleRequestBaselineMs": round(baseline_single, 1),
                "actualWallClockMsAtThisConcurrency": actual_ms,
                "scalingRatio": scaling_ratio,
                "interpretation": (
                    f"A ratio near 1.0 indicates requests ran in parallel. A ratio near "
                    f"{highest['concurrency']} indicates requests were fully serialized "
                    f"(consistent with a blocking inference call on a single event loop / "
                    f"single worker). Measured ratio: {scaling_ratio}."
                ),
            }
            print(f"\n  Scaling ratio at concurrency={highest['concurrency']}: {scaling_ratio} "
                  f"(1.0 = perfectly parallel, {highest['concurrency']} = fully serialized)")

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = REPORT_DIR / "ai_service_results.json"
    out_path.write_text(json.dumps(results, indent=2))
    print(f"\n✓ AI service results written to {out_path}")


if __name__ == "__main__":
    main()
