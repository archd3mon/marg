# Marg — Pune Urban Mobility Planner

Marg is a production-grade multimodal route planning application for Pune. It integrates Metro, Bus, and Walking paths to generate efficient, time-aware, ML‑scored routes using real-world geographic data and OpenStreetMap.

---

## Features

- **Location Search** — Type place names (e.g. "FC Road", "Pune Airport") with autocomplete powered by OSM Nominatim
- **Multimodal Routing** — Seamlessly combines walking, bus, and metro segments powered by the time-aware RAPTOR algorithm utilizing real-world GTFS timetables
- **Time-Aware GTFS Scheduling** — Real transit timetables calculate exact arrival times, wait times, and optimal transfer points
- **True Alternate Routes** — Structurally different route options (not just edge variants)
- **Mode Preferences** — Toggle "Prefer Metro", "Prefer Bus", or "Less Walking" to influence route scoring
- **ML Route Scoring** — Random Forest model predicts leg travel times; final score combines time, transfers, mode penalties, and walking distance
- **Step-by-Step Directions** — Timeline UI with bus route numbers, metro line names, boarding/alighting instructions
- **Transfer Detection** — Accurate counting of mode changes (bus→metro, etc.) ignoring walk segments
- **Recent Locations** — Quick access to last 5 searched origins/destinations via `localStorage`
- **Interactive Map Feedback** — Real-time highlights when hovering itinerary legs; toast notifications for map pin drops
- **Mobile-First UI** — Bottom sheet on mobile, sidebar on desktop, responsive layout with glassmorphism and Framer Motion animations

---

## Recent Upgrades & Changelog

### [Upgrade 1] — Safe Initialization
**Date:** 2026-03-22
- **Backend:** Added `routing_available` flag and `load_status` diagnostics. Structured try/except blocks prevent server crashes if data files are missing or corrupt.
- **Verification:** Health endpoint now provides granular status for Graph, ML, and Search engines.

### [Upgrade 3] — Eager Loading on Startup
**Date:** 2026-03-22
- **Performance:** RAPTOR GTFS structures are now pre-built during server startup. First-request latency dropped from 100s to <1s.

### [Upgrade 4] — KD-Tree Fallback
**Date:** 2026-03-22
- **UX:** Improved handling for points far from transit. Now returns descriptive warnings instead of empty results for locations within a 2.5km–5km radius of Pune.

### [Upgrade 5] & [Upgrade 6] — Yen's Algorithm & Diversity Filter
**Date:** 2026-03-22
- **Algorithms:** Implementation of Yen's K-Shortest Paths for robust alternatives. A diversity filter ensures paths are structurally distinct (<80% overlap).

### [Upgrade 7] — Multi-Objective Routing
**Date:** 2026-03-22
- **UI:** Added route-type badges (⚡ Fastest, 🔁 Fewer Transfers, 🚶 Less Walking) to help users choose based on their current priority.

### [Upgrade 8] — Advanced Transfer Logic
**Date:** 2026-03-22
- **Accuracy:** Replaced generic transfer penalties with a hub-aware lookup table (e.g., Civil Court metro transfers are faster than street-level bus swaps).

### [Upgrade 9] — Spatial-Aware Geocoding
**Date:** 2026-03-22
- **Search:** Results are now re-ranked using a haversine proximity penalty to Pune city center, ensuring "local" results always appear first.

### [Upgrade 10] — Recent Locations
**Date:** 2026-03-22
- **UX:** Added a persistent `localStorage` hook to suggest previous search points when the search input is focused and empty.

### [Upgrade 11] — [Upgrade 13] — Visual & Interactive Overhaul
**Date:** 2026-03-22
- **Aesthetics:** Switched to **Outfit** typography and implemented **Glassmorphism** depth.
- **Interactivity:** Added **Framer Motion** transitions and synchronized sidebar-to-map leg highlighting.
- **Feedback:** Integrated **react-toastify** for responsive map-state notifications.

---

## System Architecture

```
┌──────────────────────────────────────────────────────┐
│                    Frontend (React + Vite)            │
│  SearchPanel → RouteList → ItineraryPanel → MapView  │
│  Autocomplete ↔ /api/v1/geocode/search               │
│  Route Search ↔ /api/v1/routes/search                │
└──────────────────┬───────────────────────────────────┘
                   │ HTTP (via Vite proxy)
┌──────────────────▼───────────────────────────────────┐
│                 Backend (FastAPI)                     │
│  main.py → graph.py (RouteEngine)                     │
│          → RAPTOR (gtfs_loader.py + raptor.py)        │
│          → ranker.py & inference.py (RF Model)        │
│  Nominatim geocoding (httpx → OSM API)                │
└──────────────────┬───────────────────────────────────┘
                   │ Pickle / JSON
┌──────────────────▼───────────────────────────────────┐
│              Data Layer                               │
│  multimodal_graph.gpickle  (NetworkX MultiDiGraph)    │
│  spatial_index.pkl         (KDTree for nearest-node)  │
│  bus_stops.json, metro_stations.json, metro_edges.csv │
│  travel_time_rf.pkl        (sklearn Random Forest)    │
└──────────────────────────────────────────────────────┘
```

---

## Routing Algorithm

1. **First/Last Mile Walk Lookup** — KDTree maps the origin and destination to all transit stops within a 1.5km walking radius.
2. **RAPTOR Timetable Engine** — The core GTFS sequence engine "rides" the active timetables to compute the absolute earliest arrival and fastest multi-modal transfers.
3. **Graph A* Fallback** — If GTFS scheduling is unviable, the router seamlessly falls back to a time-bucketed NetworkX DiGraph traversing physical roads.
4. **Diversity Filter** — Transit node paths are compared (<80% overlap) to yield structurally distinct route choices.
5. **ML Scoring & Ranking** — A Random Forest model weighs (mode, distance, congestion). The final itinerary is ranked via `score = time + (transfers × 8min) + walk_penalty`.

---

## Dataset Structure

```
pump/data/processed/
├── bus_stops.json            # [{id, name, lat, lon, type: "bus_stop"}, ...]
├── bus_routes.json           # [{route_id, stops: [...], ...}, ...]
├── metro_stations.json       # [{id, name, lat, lon, line, order, type: "metro"}, ...]
├── metro_edges.csv           # from_station, to_station, line
├── multimodal_graph.gpickle  # NetworkX MultiDiGraph (bus + metro + walk edges)
├── spatial_index.pkl         # KDTree + node_ids + coords
└── mapped_transit_stops.json # Combined transit stop mapping

pump/data/models/
└── travel_time_rf.pkl        # Trained Random Forest model
```

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/health` | System health: graph nodes/edges, ML model status |
| `GET` | `/api/v1/network/stops` | All metro + first 500 bus stops |
| `GET` | `/api/v1/geocode/search?q=<query>` | Nominatim geocoding scoped to Pune |
| `POST` | `/api/v1/routes/search` | Multimodal route search with ML scoring |

**Route search payload:**
```json
{
  "source": {"lat": 18.52, "lng": 73.85},
  "destination": {"lat": 18.56, "lng": 73.84},
  "departure_time": "2026-03-16T10:00:00",
  "mode_preferences": {"prefer_metro": true}
}
```

---

## How to Run Locally

### 1. Backend

```bash
cd pump/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### 2. Frontend

```bash
cd pump/frontend
npm install
npm run dev
```

### 3. Run Tests

```bash
cd pump/backend
source venv/bin/activate
python -m pytest tests/test_routes.py -v
```

### 4. Validate Datasets

```bash
cd pump/backend
source venv/bin/activate
python scripts/validate_datasets.py
```

---

## Project Structure

```
pump/
├── backend/
│   ├── app/
│   │   ├── main.py          # FastAPI app, endpoints, geocoding
│   │   ├── network/graph.py # RouteEngine: First-mile KDTree, Graph Fallback A*
│   │   ├── transit/         # High-speed timetable parsing
│   │   │   ├── gtfs_loader.py # Highly-optimized GTFS memory pipeline
│   │   │   └── raptor.py    # RAPTOR Time-Aware Algorithm
│   │   ├── ml/inference.py  # TravelTimePredictor (Random Forest)
│   │   └── scoring/ranker.py # Score & rank with mode preferences
│   ├── scripts/
│   │   ├── build_graph.py    # Build multimodal graph from data
│   │   ├── validate_datasets.py # Pre-flight dataset checks
│   │   ├── parse_datasets.py    # Parse raw KML/CSV to JSON
│   │   ├── train_model.py       # Train travel time RF model
│   │   └── generate_synthetic_data.py # Generate training data
│   ├── tests/test_routes.py  # Pytest suite (health, routes, geocode)
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── App.jsx           # Layout orchestrator (mobile/desktop)
│   │   ├── api.js            # API client (routes, geocode, stops)
│   │   ├── index.css         # Full design system
│   │   ├── components/
│   │   │   ├── SearchPanel.jsx    # Autocomplete + mode toggles
│   │   │   ├── RouteCard.jsx      # Route summary card
│   │   │   ├── RouteList.jsx      # Route card container
│   │   │   ├── ItineraryPanel.jsx # Step-by-step timeline
│   │   │   ├── BottomSheet.jsx    # Mobile bottom sheet
│   │   │   └── ModeIcon.jsx       # SVG transport icons
│   │   └── map/
│   │       ├── MapView.jsx        # Leaflet map container
│   │       ├── RoutePolylines.jsx # Color-coded route lines
│   │       └── CustomMarkers.jsx  # Start/end/transfer markers
│   └── package.json
└── data/
    ├── processed/  # JSON/CSV/pickle data files
    ├── models/     # Trained ML model
    └── raw/        # Source data
```