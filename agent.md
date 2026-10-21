# Agent Instructions — Marg Backend & System Guidelines

You are working on Marg, a multimodal (walk/bus/metro) journey planner for Pune.
Backend: FastAPI, RAPTOR over GTFS, KD-tree snapping, NetworkX graph + A*, geocoding, RF travel-time model, ranker.
Clients (React web, Flutter app) consume `/api/v1/routes/search` and `/api/v1/geocode/search`.

## HARD RULES
1. **Never break the public API contract.** Response changes must be additive (new optional fields only). Never rename or remove existing fields.
2. **Every behaviour change goes behind an env flag in `app/config.py`** (e.g. `MARG_RAPTOR_MULTICRITERIA=1`) with the OLD behaviour as the fallback. Flags default to OFF until I say to flip them.
3. **Memory budget:** the server must stay under 450 MB RSS after startup (Render free tier is 512 MB). Do not load new big structures eagerly without measuring.
4. **Run tests before and after each task:** `python -m pytest backend/tests -q` (or `pytest pump/backend/tests -q`). If a previously passing test fails, fix or revert; do not edit tests to make them pass unless the test was wrong, and explain why.
5. **One logical change per commit with a clear message.** Do not bundle unrelated edits.
6. **No new heavy dependencies without asking.** Prefer stdlib/numpy/scipy/networkx already in `requirements.txt`. Small pure-Python libs (e.g. `rapidfuzz`) are acceptable if you tell me.
7. **Do not fabricate numbers.** Any metric in docs must come from a script in the repo that I can rerun.
8. **Do not touch frontend code unless the prompt says so.**
9. **At the end of each task, print:**
   - Files changed
   - Flags added
   - Tests run
   - Anything uncertain
