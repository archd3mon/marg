#!/usr/bin/env bash
# Capture real backend responses as test fixtures for Flutter tests
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== Capturing real backend fixtures..."
if [ -f "$ROOT/pump/backend/venv/bin/python" ]; then
  PYTHON="$ROOT/pump/backend/venv/bin/python"
elif [ -f "$ROOT/pump/backend/venv/Scripts/python.exe" ]; then
  PYTHON="$ROOT/pump/backend/venv/Scripts/python.exe"
else
  PYTHON="python3"
fi

( cd "$ROOT/pump/backend" && "$PYTHON" scripts/capture_fixtures.py ../mobile/test/fixtures/real )
echo "== Fixtures captured successfully to pump/mobile/test/fixtures/real"
