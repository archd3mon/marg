#!/usr/bin/env bash
# Usage: bash scripts/verify.sh [phase-N]   (run from repo root)
set -uo pipefail
PHASE="${1:-phase-x}"
mkdir -p proof
cd pump/mobile
{
  echo "== $PHASE  $(date -Iseconds) =="
  echo "-- flutter analyze"; flutter analyze 2>&1 | tail -n 15
  echo "-- flutter test";    flutter test 2>&1 | tail -n 15
  echo "-- hardcoded colors in features (must be empty)"
  grep -rn "Color(0x" lib/features 2>/dev/null || echo "none"
} | tee "../../proof/${PHASE}.log"
