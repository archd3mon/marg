#!/usr/bin/env bash
# Usage: bash scripts/shot.sh phase-2-home   -> proof/phase-2-home.png (needs a running emulator/device)
set -euo pipefail
NAME="${1:?name required}"
mkdir -p proof
adb exec-out screencap -p > "proof/${NAME}.png"
echo "saved proof/${NAME}.png ($(stat -c%s "proof/${NAME}.png" 2>/dev/null || wc -c < "proof/${NAME}.png") bytes)"
