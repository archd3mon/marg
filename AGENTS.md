# AGENTS.md — Marg (Flutter, Android-first)

You are building the Marg mobile app inside `pump/mobile/` of this repo. Also save a copy as `CLAUDE.md` / `.cursorrules` / `.windsurfrules` as your IDE expects.

## Mission
Apple-quality UI for a Pune PMPML bus planner. Bus only in v1; metro is future scope.

## Always
- Read `PLAYBOOK.md`, `design/marg_tokens.dart`, `docs/API_CONTRACT.md` before coding.
- Work on **one phase at a time** from `prompts/PROMPTS.md`. Stop at the phase's "Done when".
- Match `design-reference/screens/*.png` (open them). CSS in `design-reference/html/marg.css` has exact spacing, radii, type.
- Use tokens only. No raw colors, font sizes or paddings in feature widgets.
- Keep widgets small (<150 lines), one responsibility, `const` where possible.
- Every async view handles loading / empty / error / offline.
- Run `bash scripts/verify.sh` before saying a phase is done. Paste its tail in your reply.
- Take a screenshot with `bash scripts/shot.sh <name>` and update `proof/PROOF_OF_WORK.md`.
- Commit per phase: `phase-N: summary`.

## Backend & Contract Change Workflow
- Backend changes are allowed only if **ADDITIVE**, covered by `pump/backend/tests/test_api_contract.py`, and mirrored in `docs/API_CONTRACT.md` in the same commit.
- **Contract change workflow:**
  1. Edit backend (`pump/backend/**`).
  2. Verify backend contract tests: `pytest pump/backend/tests/test_api_contract.py`.
  3. Re-capture fixtures: run `scripts/capture_fixtures` (`pump/backend/scripts/capture_fixtures.py ../mobile/test/fixtures/real`).
  4. Fix Flutter models, mocks, and UI until `flutter test` is green.
  5. Commit backend changes, test contract, updated fixtures, and Flutter client adjustments together.

## Never
- Never make breaking backend edits. Backend changes allowed only if ADDITIVE, covered by `pump/backend/tests/test_api_contract.py`, and mirrored in `docs/API_CONTRACT.md` in the same commit.
- Never edit data files or commit `.env`, keystores, or `*.pkl`/gpickle changes.
- Never fake real-time data. Schedule-based = label it "Scheduled".
- Never use SF Pro / Apple assets. Use bundled Inter.
- Never add a package without stating why; prefer what's in the stack list.
- Never leave `print()`, TODO-without-issue, or commented-out code.

## Token efficiency
- Don't re-read files you just wrote. Don't paste whole files back in chat.
- Prefer targeted edits over rewrites. Use `grep`/`rg` before opening files.
- Summaries: ≤ 8 lines per phase (what changed, verify result, screenshot path, deviations).

## Commands
```bash
cd pump/mobile
flutter pub get
flutter analyze
flutter test
flutter run -d emulator-5554 --dart-define=API_BASE=https://<your-render-url>/api/v1
bash ../../scripts/verify.sh        # analyze + tests + log
bash ../../scripts/shot.sh <name>   # adb screenshot -> proof/

# Backend contract & fixture workflow
pytest pump/backend/tests/test_api_contract.py
bash scripts/capture_fixtures.sh    # or cd pump/backend && python scripts/capture_fixtures.py ../mobile/test/fixtures/real
```

## Definition of done (any phase)
analyze clean · tests pass · matches reference screenshot · states covered · tokens only · screenshot + proof entry · committed.
