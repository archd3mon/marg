# Marg — Merge Playbook (marg backend + MARGui Flutter)

Goal: one repo where `pump/backend` (FastAPI) and `pump/mobile` (Flutter) run together, proven by tests.
Both repos already use the same `pump/` layout. The only colliding files are `README.md` and `.gitignore`.

## What was verified before writing this (real findings)
| # | Finding | Where | Fix step |
|---|---|---|---|
| 1 | Backend hardcodes `/home/jayant/...` in 6 files; won't boot on any other machine. `.env.example` also sets `PUMP_DATA_DIR` to a different level than `main.py` expects, so `/network/stops` silently returns nothing | backend | **kit** (done, tested) |
| 2 | `rapidfuzz` missing from `requirements.txt` → import crash on fresh install | backend | **kit** |
| 3 | `/geocode/search` returns `{results:[…]}`; Flutter expects a bare list → always falls back to mock places | mobile | M2 |
| 4 | Stop types are `bus_stop`/`metro_station`; Flutter filters `== 'bus'` → real stops all dropped | mobile | M2 |
| 5 | `/network/stops` = first 500 of 5,624 bus stops, not nearby ones | backend | **kit**: `/network/stops/nearby` |
| 6 | Bus legs have `line: ""` (names in `route_names`, up to 19 candidates); non-walk routes had no `route_id`; walk legs sometimes had no `path` | backend | **kit** (additive normaliser) |
| 7 | Backend returns metro routes (even as "recommended"); app is bus-only v1 | both | **kit**: `exclude_metro` pref; M3 sends it |
| 8 | Flutter sends `less_walking`, backend reads `avoid_walking` | backend | **kit** (alias) |
| 9 | Every repository method swallows errors (`catch (_) {}`) and shows hardcoded mock data. Existing Flutter tests use hand-written fixtures, so they can never catch 3–8 | mobile | M2–M3 |
| 10 | `warnings` / `departure_time_used` are top-level in the API but read per-route in the model | mobile | M3 |
| 11 | Android blocks cleartext HTTP, so `http://10.0.2.2:8000` fails | mobile | M5 |
| 12 | Itineraries contain many tiny consecutive legs (e.g. 9 metro hops, 8 bus hops); map draws straight lines between nodes though the API returns road `path` | both | M6 |
| 13 | A destination far outside Pune returns 200 with 5 routes, not the "too far" empty state | backend | M6 (decision) |

Not verifiable here (no Flutter SDK in my sandbox): the Dart tests in the kit were written but **not run**. M2 is where they first run for you.

---
## Step M0 — Merge the repos (you, 5 min)
```bash
git clone https://github.com/archd3mon/marg marg-merged && cd marg-merged
bash /path/to/kit/scripts/merge_repos.sh https://github.com/archd3mon/MARGui master
cp -r /path/to/kit/. .            # overlays backend fixes, tests, scripts, CI, fixtures
git add -A && git commit -m "chore: merge kit (portable paths, contract tests, CI, fixtures)"
```
(If your MARGui default branch is `main`, pass it as the 2nd arg.)

## Step M1 — Prove the backend (you, 3 min)
```bash
cd pump/backend && python -m venv venv && source venv/bin/activate
pip install -r requirements-dev.txt
python -m pytest tests -q          # expect: 140 passed
cd ../.. && bash scripts/e2e_smoke.sh   # expect: E2E SMOKE OK
```
Done when both pass on a machine that is not Jayant's laptop.

---
## IDE prompts (Claude Code / Cursor). Run one per session, in order. Commit after each.

### Prompt M2 — Make the contract tests runnable, fix parsing
```
Read AGENTS.md, docs/MERGE_PLAYBOOK.md (findings table) and docs/API_CONTRACT.md.
Work only in pump/mobile. Do not touch pump/backend.

Goal: make pump/mobile/test/contract/*.dart pass. They parse REAL backend payloads
from test/fixtures/real/. Do not edit those fixtures or weaken the tests.

1. ApiClient: add an optional `Dio? dio` constructor param (use it instead of building a
   new Dio when given; keep current defaults and timeouts otherwise).
2. models:
   - TransitStop.fromJson: map type 'bus_stop' -> 'bus', 'metro_station' -> 'metro'.
   - Place.fromJson: backend sends no id; derive a stable one from name+lat+lon when absent.
3. Run `cd pump/mobile && flutter pub get && flutter test test/contract/models_contract_test.dart`
   and iterate until green. Then run the whole `flutter test` and `flutter analyze`.
   Existing tests must still pass; update them only if they encoded the wrong contract.
Report: tests passing count, and any contract test you believe is wrong (with evidence from the fixture).
```
Done when: `models_contract_test.dart` green, analyze clean.

### Prompt M3 — Repository: real data, no silent mock fallback
```
Work in pump/mobile/lib/data/repositories/transit_repository.dart and api_client.dart.
Goal: make test/contract/repository_contract_test.dart pass.

Rules:
- The hardcoded mock stops/places/routes are DEMO MODE ONLY: used when
  `!apiClient.hasBaseUrl`. When a base URL is set, never catch-and-substitute mock data;
  let ApiOfflineException / ApiTimeoutException / ApiUnavailableException propagate
  (wrap other DioExceptions in a new ApiException), so the screens' existing
  loading/error/offline states actually trigger.
- searchGeocode: response is {results:[...]}; skip the call for queries < 2 chars.
- getNearbyStops: call GET /network/stops/nearby?lat&lng&radius_m=1500&limit=30,
  keep only type 'bus'. Keep sorting by distance.
- searchRoutes: mode_preferences = {prefer_bus:true, exclude_metro:true,
  less_walking: priority=='least_walking'}. After parsing, copy top-level `warnings`
  and `departure_time_used` onto every TransitRoute. If `routes` is empty return [].
- checkHealth: true only if status=='ok' && routing_available==true (nested payload:
  components.graph/ml_model/search). Update getHealth consumers accordingly.
- Check every screen that calls these methods handles the thrown errors (results_error_view,
  place_search_sheet, explore). Add try/catch -> error state where missing.
Finish with `flutter analyze && flutter test`. Summarise changed files in <=8 lines.
```
Done when: all contract tests + existing tests green.

### Prompt M4 — Cold start gate
```
Render free tier cold-starts (30-60s). In pump/mobile add an app-start health gate:
poll /health (checkHealth) with 1s,3s,5s,5s backoff up to ~60s, show the existing
"Waking up Marg…" state meanwhile, then proceed. Route search must also auto-retry once on
503. Add widget tests with a fake repository: (a) unhealthy then healthy -> proceeds,
(b) never healthy -> error view with Retry. No new packages.
```

### Prompt M5 — Android networking + environments
```
In pump/mobile/android: allow cleartext HTTP ONLY in debug/profile builds so the emulator
can reach `http://10.0.2.2:8000/api/v1`:
- add src/debug/res/xml/network_security_config.xml permitting cleartext to 10.0.2.2 and localhost
- reference it from src/debug/AndroidManifest.xml (android:networkSecurityConfig).
Release must stay HTTPS-only (verify src/main manifest has no usesCleartextTraffic).
Add scripts/run_mobile_local.sh (starts backend on 0.0.0.0:8000, then `flutter run
--dart-define=API_BASE=http://10.0.2.2:8000/api/v1`) and document the three API_BASE values
(emulator, physical device on LAN IP, Render HTTPS URL) in docs/MOBILE_README.md.
Also add a startup check: in release builds, if API_BASE is empty or not https, show a clear
config error instead of demo mode.
```

### Prompt M6 — Itinerary quality (do after M5; product decisions flagged)
```
Context: the real API returns noisy itineraries (many tiny consecutive legs; see
test/fixtures/real/routes_search_*.json) and per-leg road geometry in `path`.
In pump/mobile:
1. RouteLeg: parse `path` ([[lat,lon],...]) and `line_options`. Draw polylines from `path`
   (fallback: from/to node) in ResultsMapData.buildPolylines and the itinerary/live maps.
2. Add a pure function collapseLegs(List<RouteLeg>) used by UI only: merge consecutive legs
   with the same mode AND same `line` (metro) into one leg (sum length/duration, concat path,
   first fromNode, last toNode). Do NOT merge different bus lines. TDD: write unit tests first
   using the real fixtures.
3. Bus chip shows `line`; if line_options.length>1 show "+N" in the itinerary detail only.
4. Do not invent headsign, stop counts or frequency: hide those rows when null.
Then run flutter analyze && flutter test.
```
Decision for you: whether routes with >8 legs should be hidden. (Default: keep, collapse only.)
Open backend item (optional): destination far outside Pune returns routes instead of the empty "too far" state (`test_far_outside_pune_is_graceful` allows both). Tighten later.

### Prompt M7 — Update the agent rules and docs
```
Update AGENTS.md / CLAUDE.md and docs/API_CONTRACT.md:
- Replace "Never edit pump/backend/**" with: backend changes allowed only if ADDITIVE, covered by
  pump/backend/tests/test_api_contract.py, and mirrored in docs/API_CONTRACT.md in the same commit.
- Contract change workflow: edit backend -> run scripts/capture_fixtures (pump/backend/scripts/
  capture_fixtures.py ../mobile/test/fixtures/real) -> fix Flutter until `flutter test` is green.
- Rewrite API_CONTRACT.md from the real fixtures: wrapped geocode, bus_stop/metro_station,
  /network/stops/nearby, exclude_metro, route_id/line/line_options/path guarantees, 503/empty states.
- Root README: add a "Run everything" section (backend, React, Flutter) and link
  docs/MOBILE_README.md. Remove stale claims (e.g. Capacitor) that no longer apply.
```

### Prompt M8 — Deploy + device test
```
Help me deploy pump/backend to Render (free): write render.yaml (python 3.12, build:
pip install -r pump/backend/requirements.txt, start: cd pump/backend && uvicorn app.main:app
--host 0.0.0.0 --port $PORT, health check /api/v1/health). Data files are committed, so no
disk needed. Then give me the exact commands to build a release APK pointing at the Render URL
and the manual device checklist below.
```
Manual device checklist: cold start state → search "Kothrud" returns real places → nearby stops list shows real stops near you → Kothrud→Viman Nagar returns ≥1 bus-only route with line chips → tap route, map shows road-following lines → airplane mode shows offline state, not mock data → dark mode.

### Prompt M9 — Final gate
```
Run `bash scripts/verify_all.sh` and `bash scripts/e2e_smoke.sh`. Fix anything red. Then grep the
repo for: "/home/jayant", "catch (_) {}" in pump/mobile/lib/data, "print(" in lib, hardcoded
Color(0x in lib/features. Report each as clean or list offenders. Do not mark done until
GitHub Actions (.github/workflows/ci.yml) is green on the branch.
```

## Definition of "merged and working"
- `verify_all.sh` green locally and CI green on GitHub
- `e2e_smoke.sh` green
- Device checklist passes against the Render URL
- No mock data reachable when API_BASE is set (M3 test proves it)

## Rollback
Everything happens on branch `integrate/flutter-ui`. `main` is untouched until you merge the PR.
