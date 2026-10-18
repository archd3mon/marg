# MARG — Build Playbook (Android-first, Flutter)

Pune PMPML bus planner. v1 = **bus only**. Metro = future scope (UI slot reserved, data already in repo).
Look & feel: Apple-grade — clarity, deference, depth. Liquid-glass sheets over a calm map.

**Read order for the agent:** `AGENTS.md` → this file → `design/` → `docs/API_CONTRACT.md` → `prompts/PROMPTS.md` (one phase at a time).

---

## 0. Ground truth (verified in the repo)

| Layer | State |
|---|---|
| Backend `pump/backend` | FastAPI + RAPTOR + NetworkX + RF scorer. **Stable. Do not modify.** |
| Endpoints | `GET /api/v1/health`, `GET /api/v1/network/stops`, `GET /api/v1/geocode/search?q=&limit=`, `POST /api/v1/routes/search` |
| Old client `pump/frontend` | React + Leaflet. **Reference only** for behaviour (recents, hover-highlight, toasts). |
| New client | **Create `pump/mobile/` (Flutter).** Android first; iOS must not be broken but is not tested in v1. |
| Data | PMPML GTFS + stops/routes/depots; metro stations/edges already processed (use later). |

### Honest constraints (do not paper over these)
1. **No real-time bus feed exists.** Backend is schedule-based (GTFS). The "Live trip" screen must show **scheduled progress** and say "Scheduled", never fake "LIVE GPS". Use a pulsing dot only for *your own* location.
2. **No alerts endpoint.** Alerts screen v1 = local, user-generated (saved-route reminders) + clearly marked sample service notices behind a `kDemoAlerts` flag. Never present invented delays as real.
3. **SF Pro cannot be used on Android.** Ship **Inter** (OFL) bundled in assets. Do not reference `-apple-system` in Flutter.
4. Render free-tier backend cold-starts. Show a calm "Waking up Marg…" state, retry with backoff.

---

## 1. Target architecture

```
pump/mobile/
  lib/
    main.dart
    app/            router (go_router), app shell, tab bar
    theme/          marg_tokens.dart, marg_theme.dart, glass.dart
    data/           api_client.dart (dio), models/, repositories/
    features/
      onboarding/ explore/ plan/ results/ itinerary/ trip/ saved/ alerts/
    shared/         widgets (BusChip, WalkChip, Badge, GlassSheet, TimelineRail…)
  assets/fonts/Inter-*.ttf
  test/             widget + golden tests
```
Stack: Flutter 3.x stable · Riverpod · go_router · dio · flutter_map (+ latlong2) · geolocator · shared_preferences · cached_network_image not needed.
Map tiles: CARTO Positron (light) / Dark Matter (dark) — keep existing working config from the repo.
Min SDK 26, target latest. Edge-to-edge, predictive back enabled.

## 2. Design rules (non-negotiable)

- Tokens come only from `design/marg_tokens.dart`. **No raw hex or magic numbers in widgets.**
- 8-pt grid (4 allowed for tight icon gaps). Radii: 10/14/20/28.
- Type: Inter, sizes 34/28/20/17/15/13/12, tight tracking (-0.01 to -0.03em), tabular numbers for times.
- Android adaptation of Apple look: touch targets **≥ 48dp** (mock uses 44pt — grow hit area, not visuals), system-gesture inset respected, no fake iOS status bar/home indicator, haptics `selectionClick` on chip/tab, `lightImpact` on primary CTA.
- Glass = `BackdropFilter(blur 28–32) + white@78% + 0.5px hairline`. Max 2 glass layers on screen; disable blur on low-end (`MediaQuery.disableAnimations`/perf flag) and fall back to solid 94% white.
- Motion: 250–350 ms, `Curves.easeOutCubic` / spring for sheets. Camera fit-to-route animated. Respect reduce-motion.
- Dark mode from day one (tokens have both).
- Every screen has: loading (skeleton, not spinner), empty, error+retry, offline states.
- Accessibility: contrast ≥ 4.5:1, `Semantics` on chips/cards, text scales to 1.3× without clipping.

## 3. Phases (each ends with proof)

| # | Phase | Output | Done when |
|---|---|---|---|
| 0 | Recon & scaffold | `pump/mobile` runs on emulator, Inter loaded | `flutter analyze` clean, blank themed app boots |
| 1 | Foundation | tokens, theme, glass, shared widgets, API client + models | golden tests for BusChip/Badge/Card pass |
| 2 | Shell + Explore | map, draggable glass sheet, tab bar, nearby stops | matches `design-reference/screens/home.png` |
| 3 | Plan + Search | O/D fields, debounced geocode, recents, time, priority chips | matches `plan.png`; recents persist |
| 4 | Results | 3–5 ranked cards, badges, polylines, fit-camera | matches `results.png`; selection syncs map |
| 5 | Itinerary | timeline rail, expandable stops, share | matches `itinerary.png` |
| 6 | Trip mode | schedule-based progress banner + sheet | matches `live.png`, honest "Scheduled" label |
| 7 | Saved + Alerts | places, routes, toggles (local) | matches `saved.png`, `alerts.png` |
| 8 | Polish | motion, haptics, dark mode, states, a11y, perf | checklist §5 all green |
| 9 | Release | icon, splash, signing, AAB, install on a real device | `flutter build appbundle` OK |
| 10 | Proof & submit | `proof/` complete, deck, Figma | `SUBMISSION_CHECKLIST.md` all ticked |

Rule: **one phase per agent session.** Commit at the end of each phase: `phase-N: <summary>`.

## 4. Proof of work (do this as you go)

After every phase the agent must:
1. `bash scripts/verify.sh` → analyze + tests, output saved to `proof/phase-N.log`.
2. `bash scripts/shot.sh phase-N-<screen>` → emulator screenshot into `proof/` (uses `adb exec-out screencap`).
3. Append a block to `proof/PROOF_OF_WORK.md` (template inside): what changed, commit hash, screenshot link, any deviation from design.
4. Tag `git tag phase-N`.

Graders and your viva both reward visible progress: the git log + `proof/` folder is the evidence trail.

## 5. Polish checklist (phase 8)
- [ ] Sheet snaps at 0.14 / 0.5 / 0.92, velocity-aware, no jank at 60 fps (profile mode)
- [ ] Route polyline draws in (trim-path animation) once per search
- [ ] Walk legs dotted, bus legs solid blue, metro legs reserved purple (unused in v1)
- [ ] Skeletons on every async list; cold-start state for backend
- [ ] Dark mode screenshots for all 8 screens
- [ ] TalkBack pass on Home→Plan→Results→Itinerary
- [ ] Font scale 1.3 and 0.85 do not break layouts
- [ ] No hardcoded colors/sizes (`grep -rn "Color(0x" lib/features` returns nothing)

## 6. Metro (future scope) — do now, cheaply
- `TransitMode` enum `{bus, metro}`; v1 UI shows Metro in the segmented control disabled with "Soon" badge.
- `mode_preferences` already supports `prefer_metro`; leave wired but hidden.
- Purple `#AF52DE` and `metro` leg styling exist in tokens so enabling later is a flag flip, not a redesign.

## 7. Risks
| Risk | Mitigation |
|---|---|
| Blur perf on budget Androids | solid fallback, test on a low-end AVD |
| Backend cold start (Render) | splash state + retry; cache last results |
| Nominatim rate limits | 400 ms debounce, 1 req/s cap, cache by query |
| Scope creep | v1 = phases 0–10 exactly; ideas go to `docs/BACKLOG.md` |
