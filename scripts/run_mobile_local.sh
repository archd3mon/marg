#!/usr/bin/env bash
# Usage: bash scripts/run_mobile_local.sh [flutter run args...]
# Starts the Marg backend locally on 0.0.0.0:8000, waits for health check,
# then launches the Flutter mobile app pointing to the Android emulator loopback.
set -euo pipefail

PORT="${PORT:-8000}"
HOST="0.0.0.0"
API_BASE="http://10.0.2.2:${PORT}/api/v1"

echo "== Starting Marg backend on ${HOST}:${PORT} =="
( cd pump/backend && python -m uvicorn app.main:app --host "${HOST}" --port "${PORT}" ) &
BACKEND_PID=$!
trap 'echo "Shutting down backend..."; kill $BACKEND_PID 2>/dev/null || true' EXIT INT TERM

echo "Waiting for backend to be ready..."
for i in $(seq 1 45); do
  if curl -sf "http://127.0.0.1:${PORT}/api/v1/health" >/dev/null 2>&1; then
    echo "Backend is ready!"
    break
  fi
  sleep 1
done

echo "== Starting Flutter app with API_BASE=${API_BASE} =="
cd pump/mobile
flutter run --dart-define="API_BASE=${API_BASE}" "$@"
