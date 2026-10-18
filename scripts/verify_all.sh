#!/usr/bin/env bash
# One command for "is the merged repo healthy?"  bash scripts/verify_all.sh [--no-flutter]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; FAIL=0
step() { echo; echo "== $1"; }
step "backend: pytest (unit + contract + routing)"
( cd "$ROOT/pump/backend" && python -m pytest tests -q -p no:cacheprovider ) || FAIL=1
if [ "${1:-}" != "--no-flutter" ]; then
  step "flutter: analyze"; ( cd "$ROOT/pump/mobile" && flutter analyze ) || FAIL=1
  step "flutter: test";    ( cd "$ROOT/pump/mobile" && flutter test ) || FAIL=1
  step "no hardcoded colours in features"
  if grep -rn "Color(0x" "$ROOT/pump/mobile/lib/features" 2>/dev/null; then FAIL=1; else echo none; fi
fi
step "no machine-specific paths"
if grep -rIn --exclude-dir=.git --exclude-dir=venv --exclude-dir=node_modules "/home/jayant" "$ROOT/pump" "$ROOT/scripts" 2>/dev/null | grep -v -e "\.md:" -e take_screenshots.js ; then FAIL=1; else echo none; fi
echo; [ $FAIL -eq 0 ] && echo "ALL GREEN" || { echo "FAILED"; exit 1; }
