# Phase Prompts — paste ONE per session into your agentic IDE

Prefix for every session (short, saves tokens):
> Read `AGENTS.md`, `PLAYBOOK.md`, `docs/API_CONTRACT.md`, `design/marg_tokens.dart`. Do only the phase below. Match the referenced screenshot in `design-reference/screens/`. Finish with `scripts/verify.sh`, `scripts/shot.sh`, a `proof/PROOF_OF_WORK.md` entry, a commit and tag. Reply in ≤ 8 lines.

---
## PHASE 0 — Recon & scaffold
1. Confirm `flutter doctor` is green for Android; start an emulator (Pixel 8, API 34+).
2. `flutter create --org in.marg --project-name marg_app --platforms android,ios pump/mobile`.
3. Add deps: flutter_riverpod, go_router, dio, flutter_map, latlong2, geolocator, shared_preferences, url_launcher, share_plus, intl. Dev: flutter_test, mocktail.
4. Download Inter (OFL) → `assets/fonts/` (400/500/600/700), register in `pubspec.yaml`.
5. Set Android: minSdk 26, edge-to-edge, `android:enableOnBackInvokedCallback="true"`, app label "Marg", INTERNET + FINE/COARSE_LOCATION.
6. Copy `scripts/*` to repo root `scripts/`, `design/marg_tokens.dart` → `lib/theme/`.
**Done when:** app boots to an empty themed screen, `flutter analyze` clean.

## PHASE 1 — Foundation
1. Hit the 4 endpoints, save JSON fixtures in `test/fixtures/`.
2. Build immutable models (`Route`, `Leg`, `Node`, `Place`, `Stop`) with tolerant `fromJson` (nullable unknowns).
3. `ApiClient` (dio, timeouts, retry, typed errors: `Offline`, `Unavailable503`, `Timeout`).
4. Repositories + Riverpod providers.
5. Shared widgets from tokens: `BusChip`, `WalkChip`, `BadgeLabel`, `GlassSheet`, `PrimaryButton`, `Segmented`, `SettingsRow`, `Skeleton`, `TimelineRail`.
6. Golden tests for each shared widget (light + dark).
**Done when:** goldens pass; fake-repo unit test parses fixtures.

## PHASE 2 — Shell + Explore  (ref: `home.png`, `welcome.png`)
1. Onboarding (3 value props, location rationale, Continue → request permission lazily). Show once (`shared_preferences`).
2. App shell: full-bleed `flutter_map` (CARTO Positron/Dark Matter, keep repo's working tile config), glass tab bar (Explore/Saved/Alerts), 48 dp targets.
3. Explore: `DraggableScrollableSheet` snaps 0.14/0.5/0.92; "Where to?" field; Home/Work/Add shortcuts; "Nearby stops" list (nearest bus stops by haversine from `/network/stops`) with line chips.
4. Locate-me + layers buttons (glass, top-right). User dot with soft halo.
**Done when:** matches `home.png` within spacing/type tolerance; sheet feels native.

## PHASE 3 — Plan + Search  (ref: `plan.png`)
1. Plan screen: From/To card with dotted connector + swap, "Leave" row (now / pick time via bottom sheet), Travel-by segmented (**Bus**, Metro disabled + "Soon"), priority chips mapped to `mode_preferences`.
2. Search: tapping a field opens autocomplete (400 ms debounce, session cache, recents from `shared_preferences`, max 5).
3. "Pick on map" long-press → reverse label "Dropped pin".
4. "Show Routes" disabled until both points set; haptic on tap.
**Done when:** matches `plan.png`; recents persist across restarts.

## PHASE 4 — Results  (ref: `results.png`)
1. Call `/routes/search`; skeleton cards while loading; cold-start and 503 states.
2. Result sheet: header "N routes", leave-time chip, cards per API_CONTRACT UI mapping, selected card gets 2 px blue ring + soft blue shadow.
3. Map: draw selected route (white casing + blue stroke; walk = dotted grey), origin/transfer/destination markers, animated fit-to-bounds (existing zoom-to-fit behaviour from React/Flutter work).
4. Selecting a card updates polyline with a 250 ms cross-fade.
**Done when:** matches `results.png`; changing selection feels instant.

## PHASE 5 — Itinerary  (ref: `itinerary.png`)
1. Timeline (time | rail | body): walk legs dotted grey, bus legs solid blue 5 px rail, nodes white-filled ring, destination red.
2. Each bus leg: line chip, headsign if available, "N stops · M min", expandable intermediate stops (animate height).
3. Share (share_plus: text summary), Save route, Start Trip CTA.
**Done when:** matches `itinerary.png`; expand/collapse smooth.

## PHASE 6 — Trip mode  (ref: `live.png`)
1. Banner (dark glass) with next instruction: "Get off at <stop> · N stops". Status chip says **SCHEDULED** (not LIVE) unless a real feed exists.
2. Progress derived from schedule + device location snap-to-route; stats: remaining, arrival, on-schedule state.
3. Foreground-only (no background service in v1). End Trip confirm.
**Done when:** matches `live.png`; label honest.

## PHASE 7 — Saved + Alerts  (ref: `saved.png`, `alerts.png`)
1. Saved: Home/Work places (editable), saved routes (re-run search on tap), swipe-to-delete.
2. Alerts: segmented My Routes / All Service; v1 content = local reminders + `kDemoAlerts` sample notices (flag default **false**, labelled "Sample" when on). Toggles persist.
**Done when:** persistence verified by restart; flag off in release.

## PHASE 8 — Polish
Work through PLAYBOOK §5 checklist. Add dark-mode screenshots for all screens. Profile on low-end AVD; enable blur fallback. TalkBack pass.

## PHASE 9 — Release
Adaptive icon (blue gradient + route glyph, see `welcome.png`), Android 12 splash, `flutter build appbundle --release`, signing config via `key.properties` (gitignored), test APK on a real device. Write `docs/RELEASE.md` with Play Console steps.

## PHASE 10 — Proof & submission
Fill `proof/PROOF_OF_WORK.md`, export screenshots (light + dark) into `proof/final/`, record a 60-s screen capture (`adb shell screenrecord`), update README with GIF/screens. Tick `SUBMISSION_CHECKLIST.md`.
