#!/usr/bin/env bash
# Boots the real backend and asserts the 4 endpoints the app uses. Run from repo root.
set -euo pipefail
PORT="${PORT:-8000}"; BASE="http://127.0.0.1:$PORT/api/v1"
( cd pump/backend && python -m uvicorn app.main:app --port "$PORT" >/tmp/marg_e2e.log 2>&1 ) &
PID=$!; trap 'kill $PID 2>/dev/null || true' EXIT
for i in $(seq 1 90); do curl -sf "$BASE/health" >/dev/null && break; sleep 2; done
curl -sf "$BASE/health" | python -c "import sys,json;d=json.load(sys.stdin);assert d['routing_available'],d"
curl -sf "$BASE/network/stops/nearby?lat=18.5074&lng=73.8077" | python -c "import sys,json;assert json.load(sys.stdin)['stops']"
curl -sf "$BASE/geocode/search?q=Kothrud" | python -c "import sys,json;assert json.load(sys.stdin)['results']"
curl -sf -X POST "$BASE/routes/search" -H 'content-type: application/json' \
 -d '{"source":{"lat":18.5074,"lng":73.8077},"destination":{"lat":18.5679,"lng":73.9143},"mode_preferences":{"prefer_bus":true,"exclude_metro":true}}' \
 | python -c "import sys,json;r=json.load(sys.stdin)['routes'];assert r and all(not x['uses_metro'] for x in r)"
echo "E2E SMOKE OK"
