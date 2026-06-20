#!/usr/bin/env bash
#
# BloodConnect Performance Test Suite — Single-Command Runner
# ===============================================================
#
# Usage: ./run_all.sh [api|notification|db|ai|stress|all]
#   (default: all)
#
# This script does NOT start the BloodConnect services for you — they must
# already be running (locally via docker compose, or pointed at a remote
# environment via PERF_API_BASE_URL etc. in .env). See README.md
# "Step 2 — Start the real BloodConnect services" before running this.

set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-all}"
mkdir -p reports

echo "═══════════════════════════════════════════════════════════"
echo " BloodConnect Performance Test Suite"
echo " Mode: $MODE"
echo "═══════════════════════════════════════════════════════════"

if [ ! -f .env ]; then
  echo ""
  echo "⚠  No .env file found. Copying .env.example → .env."
  echo "   Edit .env with real values before this will produce meaningful results."
  cp -n .env.example .env || true
fi

check_reachable() {
  local url="$1"
  local label="$2"
  if curl -fsS --max-time 5 "$url" > /dev/null 2>&1; then
    echo "  ✓ $label reachable at $url"
    return 0
  else
    echo "  ✗ $label NOT reachable at $url — skipping its tests."
    return 1
  fi
}

echo ""
echo "Checking service reachability..."
source <(grep -v '^#' .env | grep -v '^$' | sed 's/^/export /') 2>/dev/null || true
API_URL="${PERF_API_BASE_URL:-http://localhost:8090}"
NOTIF_URL="${PERF_NOTIFICATION_BASE_URL:-http://localhost:8080}"
AI_URL="${PERF_AI_BASE_URL:-http://localhost:8000}"

API_UP=0; NOTIF_UP=0; AI_UP=0
check_reachable "$API_URL/" "API backend" && API_UP=1 || true
check_reachable "$NOTIF_URL/" "Notification backend" && NOTIF_UP=1 || true
check_reachable "$AI_URL/health" "AI service" && AI_UP=1 || true

if [ ! -d node_modules ]; then
  echo ""
  echo "Installing Node.js dependencies (npm install)..."
  npm install
fi

# Start resource monitor in the background for the duration of this run,
# if Docker or PID env vars are available. Failure here is non-fatal.
MONITOR_PID=""
if command -v docker > /dev/null 2>&1 || [ -n "${PERF_API_PID:-}" ]; then
  echo ""
  echo "Starting background resource monitor (reports/resource_usage.json)..."
  PERF_MONITOR_DURATION_SEC="${PERF_MONITOR_DURATION_SEC:-180}" node scripts/resource_monitor.js &
  MONITOR_PID=$!
fi

run_step() {
  local name="$1"; shift
  echo ""
  echo "───────────────────────────────────────────────────────────"
  echo " $name"
  echo "───────────────────────────────────────────────────────────"
  if ! "$@"; then
    echo "✗ $name FAILED — continuing with remaining steps."
  fi
}

if [ "$MODE" = "all" ] || [ "$MODE" = "api" ]; then
  if [ "$API_UP" = "1" ]; then
    run_step "API Backend Load Test" node scripts/load_api_backend.js
  else
    echo "⏭  Skipping API backend tests (service not reachable)."
  fi
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "stress" ]; then
  if [ "$API_UP" = "1" ]; then
    run_step "API Backend Stress Test" node scripts/stress_test_api_backend.js
  else
    echo "⏭  Skipping stress test (API backend not reachable)."
  fi
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "notification" ]; then
  if [ "$NOTIF_UP" = "1" ]; then
    run_step "Notification Backend Load Test" node scripts/load_notification_backend.js
  else
    echo "⏭  Skipping notification backend tests (service not reachable)."
  fi
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "ai" ]; then
  if [ "$AI_UP" = "1" ]; then
    run_step "AI Service Performance Test" python3 scripts/load_ai_service.py
  else
    echo "⏭  Skipping AI service tests (service not reachable)."
  fi
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "db" ]; then
  if [ -n "${PERF_DATABASE_URL:-}" ]; then
    run_step "Database Performance Test" node scripts/db_performance.js
  else
    echo "⏭  Skipping database tests (PERF_DATABASE_URL not set)."
  fi
fi

if [ -n "$MONITOR_PID" ]; then
  echo ""
  echo "Waiting for background resource monitor to finish..."
  wait "$MONITOR_PID" 2>/dev/null || true
fi

echo ""
echo "───────────────────────────────────────────────────────────"
echo " Building consolidated report"
echo "───────────────────────────────────────────────────────────"
node scripts/build_report.js

echo ""
echo "✓ Done. See ./reports/ for summary.json, summary.csv, and per-component raw results."
