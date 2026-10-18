# Marg (मार्ग) — Pune Urban Mobility Planner

Marg is a production-grade multimodal route planning platform for Pune. It integrates Bus (PMPML), Metro, and Walking paths to generate efficient, time-aware, ML‑scored routes using real-world geographic data, GTFS timetables, and OpenStreetMap.

Marg provides two first-class client experiences:
1. **Flutter Mobile App (Android-first)**: Apple-grade design built with Flutter, featuring liquid glass sheets, tokenized design, and offline resilience. Full details, screenshots gallery, and 60s walkthrough video: [**`docs/MOBILE_README.md`**](docs/MOBILE_README.md).
2. **React Web App**: Responsive web dashboard with Leaflet map visualization, Framer Motion transitions, and step-by-step itineraries.

---

## Features

- **Location Search** — Type place names (e.g. "FC Road", "Pune Airport") with autocomplete powered by local POIs and OSM Nominatim, re-ranked with Pune-proximity haversine weighting.
- **Multimodal & Bus-Priority Routing** — Combines walking, bus, and metro segments powered by the time-aware RAPTOR algorithm utilizing real-world GTFS timetables.
- **Time-Aware GTFS Scheduling** — Real transit timetables calculate exact arrival times, wait times, and optimal transfer points (schedule-based, honestly disclosed).
- **True Alternate Routes** — Structurally distinct route options (<80% spatial overlap) with multi-objective trade-offs (Fastest, Fewer Transfers, Less Walking).
- **Mode Preferences** — Toggle "Prefer Bus", "Prefer Metro", "Less Walking", or "Exclude Metro" (bus-only mode) to guide the search.
- **ML Route Scoring** — Random Forest model predicts leg travel times; final score balances transit duration, transfer overheads, and walking distance.
- **Step-by-Step Directions** — Timeline UI with bus route numbers, metro line names, boarding/alighting instructions, and stop expansions.
- **Interactive Map Feedback** — Road-following polylines, marker sync, and hover leg highlighting.
- **Apple-Quality Mobile Experience** — Flutter app engineered to Apple Human Interface Guidelines on Android with 8 curated screens in Light and Dark appearances.

---

## System Architecture

```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│     Mobile App (Flutter)        │       │    Web App (React + Vite)       │
│  Explore · Plan · Results · Trip│       │  SearchPanel · RouteList · Map  │
│  Itinerary · Saved · Alerts     │       │  Framer Motion · Leaflet Map    │
└────────────────┬────────────────┘       └────────────────┬────────────────┘
                 │ HTTP (API_BASE)                         │ HTTP (Vite Proxy)
                 └────────────────┬────────────────────────┘
                                  │
                 ┌────────────────▼────────────────────────┐
                 │          Backend (FastAPI)              │
                 │  app/main.py (Endpoints & Normalizer)   │
                 │  app/transit/ (RAPTOR + GTFS Loader)    │
                 │  app/network/graph.py (A* & KD-Tree)    │
                 │  app/scoring/ranker.py & ml/ (RF Model) │
                 │  Nominatim & Local POI Geocoder         │
                 └────────────────┬────────────────────────┘
                                  │ Pickle / JSON / CSV
                 ┌────────────────▼────────────────────────┐
                 │               Data Layer                │
                 │  multimodal_graph.gpickle (NetworkX)    │
                 │  spatial_index.pkl (KDTree Spatial)     │
                 │  bus_stops.json, bus_routes.json        │
                 │  metro_stations.json, metro_edges.csv   │
                 │  travel_time_rf.pkl (Scikit-Learn RF)   │
                 └─────────────────────────────────────────┘
```

---

## 🚀 Run Everything (Backend, React, Flutter)

You can run each layer independently or use provided scripts.

### 1. Run the Backend (FastAPI)
```bash
cd pump/backend
python -m venv venv
# On Linux/macOS:
source venv/bin/activate
# On Windows (PowerShell):
.\venv\Scripts\Activate.ps1

pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
- Health Check: `http://localhost:8000/api/v1/health`
- Interactive OpenAPI Docs: `http://localhost:8000/docs`

### 2. Run the React Web App
```bash
cd pump/frontend
npm install
npm run dev
```
- Web App UI: `http://localhost:5173` (requests to `/api/v1` automatically proxy to `http://localhost:8000`).

### 3. Run the Flutter Mobile App (Android)
See [**`docs/MOBILE_README.md`**](docs/MOBILE_README.md) for full mobile documentation and screenshots.
```bash
cd pump/mobile
flutter pub get
flutter analyze
flutter test

# Run on Android emulator (uses 10.0.2.2 loopback to host backend):
flutter run -d emulator-5554 --dart-define=API_BASE=http://10.0.2.2:8000/api/v1

# Or run pointing to cloud production (e.g. Render):
flutter run -d emulator-5554 --dart-define=API_BASE=https://<your-service>.onrender.com/api/v1
```

### 4. Single-Command Local Mobile Stack
To automatically launch the Python backend on `0.0.0.0:8000`, wait for health verification, and boot the Flutter app:
```bash
bash scripts/run_mobile_local.sh
```

### 5. Repository Verification
Verify the entire monorepo (backend pytest contract tests, Flutter analyzer, Flutter tests, and design token audit):
```bash
bash scripts/verify_all.sh
```

---

## API Endpoints Summary

See [**`docs/API_CONTRACT.md`**](docs/API_CONTRACT.md) for the complete canonical API contract and fixture guarantees.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/health` | System health, component status (`graph`, `kdtree`, `ml_model`, `search`), and `routing_available` flag |
| `GET` | `/api/v1/network/stops` | All metro stations + first 500 bus stops for map layer (`type: "bus_stop" \| "metro_station"`) |
| `GET` | `/api/v1/network/stops/nearby?lat=..&lng=..&radius_m=..` | Transit stops sorted ascending by distance from location |
| `GET` | `/api/v1/geocode/search?q=<query>&limit=8` | Pune-proximity re-ranked search (always wrapped in `{"results": [...]}`) |
| `POST` | `/api/v1/routes/search` | Multimodal / bus-only route planning with RAPTOR and ML ranking |

**Route search payload example:**
```json
{
  "source": {"lat": 18.5074, "lng": 73.8077},
  "destination": {"lat": 18.5679, "lng": 73.9143},
  "departure_time": "2026-10-19T08:42:00+05:30",
  "mode_preferences": {
    "prefer_bus": true,
    "exclude_metro": true,
    "less_walking": false
  }
}
```

---

## Backend & Contract Change Workflow

To prevent breaking changes across the Flutter and React clients:
1. Backend changes are allowed only if **ADDITIVE**, covered by `pump/backend/tests/test_api_contract.py`, and mirrored in `docs/API_CONTRACT.md` in the exact same commit.
2. After backend edits, capture fresh test fixtures:
   ```bash
   bash scripts/capture_fixtures.sh
   # (or cd pump/backend && python scripts/capture_fixtures.py ../mobile/test/fixtures/real)
   ```
3. Update Flutter models and tests until `cd pump/mobile && flutter test` passes cleanly.

---

## Project Structure

```
marg-merged/
├── docs/
│   ├── API_CONTRACT.md       # Canonical HTTP API contract & fixture guarantees
│   ├── MOBILE_README.md      # Flutter app architecture, 8-screen gallery & video demo
│   └── MERGE_PLAYBOOK.md     # Integration and release playbook
├── proof/
│   ├── final/                # 8 screens light + dark PNGs and demo MP4 video
│   └── PROOF_OF_WORK.md      # Verification and phase logs
├── scripts/
│   ├── capture_fixtures.sh   # Captures real backend responses to mobile test fixtures
│   ├── run_mobile_local.sh   # Boots local FastAPI backend and launches Flutter app
│   ├── verify_all.sh         # End-to-end test and analysis gate across backend and mobile
│   ├── verify.sh             # Mobile-specific analyzer, test suite and token auditor
│   └── shot.sh               # ADB emulator screenshot capture tool
└── pump/
    ├── backend/
    │   ├── app/
    │   │   ├── main.py       # FastAPI application, route endpoints, geocoder
    │   │   ├── network/      # MultiDiGraph engine and KD-Tree spatial index
    │   │   ├── transit/      # High-speed GTFS loader & RAPTOR algorithm
    │   │   ├── ml/           # Travel time prediction Random Forest model
    │   │   └── scoring/      # Multi-objective route ranker
    │   ├── tests/
    │   │   ├── test_api_contract.py # Backend client contract test suite
    │   │   └── test_routes.py       # Algorithmic routing tests
    │   └── scripts/
    │       ├── capture_fixtures.py  # In-process test client fixture capturer
    │       ├── build_graph.py       # Graph builder from raw datasets
    │       └── validate_datasets.py # Dataset integrity checks
    ├── frontend/             # React + Vite web dashboard (Leaflet + Framer Motion)
    │   ├── src/
    │   │   ├── App.jsx
    │   │   ├── components/
    │   │   └── map/
    │   └── package.json
    ├── mobile/               # Flutter Android mobile app (Apple-quality HIG)
    │   ├── lib/
    │   │   ├── main.dart
    │   │   ├── theme/        # MargColors, MargText, liquid-glass tokens
    │   │   ├── data/         # Typed Dio API client, models & repository
    │   │   └── features/     # Onboarding, explore, plan, results, itinerary, trip, saved, alerts
    │   └── test/             # Unit, widget, and fixture tests
    └── data/
        ├── processed/        # JSON, CSV, and gpickle transit network data
        └── models/           # Pre-trained Random Forest model
```

---

## License

This project is licensed under the MIT License.