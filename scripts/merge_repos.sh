#!/usr/bin/env bash
# Merge MARGui (Flutter) into marg (backend + React), keeping both histories.
# Run from the root of a clean clone of marg:   bash scripts/merge_repos.sh [margui-url] [margui-branch]
set -euo pipefail
UI_URL="${1:-https://github.com/archd3mon/MARGui}"
UI_BRANCH="${2:-master}"

[ -z "$(git status --porcelain)" ] || { echo "Working tree not clean"; exit 1; }
git checkout -b integrate/flutter-ui
git remote add margui "$UI_URL" 2>/dev/null || git remote set-url margui "$UI_URL"
git fetch margui

# The only colliding paths are .gitignore and README.md (verified by comparing both trees).
git merge "margui/$UI_BRANCH" --allow-unrelated-histories --no-commit || true

# README: keep marg's as the root README, preserve the UI one as docs/MOBILE_README.md
git show "margui/$UI_BRANCH:README.md" > docs/MOBILE_README.md
git checkout --ours README.md 2>/dev/null || git show HEAD:README.md > README.md
git add README.md docs/MOBILE_README.md

# .gitignore: union of both, de-duplicated, order preserved
{ git show HEAD:.gitignore; echo; git show "margui/$UI_BRANCH:.gitignore"; } | awk 'NF==0 || !seen[$0]++' > .gitignore
git add .gitignore

[ -z "$(git diff --name-only --diff-filter=U)" ] || { echo "Unresolved conflicts:"; git diff --name-only --diff-filter=U; exit 1; }
git commit -m "merge: bring in MARGui Flutter app (pump/mobile) alongside backend and React client"
echo "Merged. Next: PLAYBOOK step M1."
