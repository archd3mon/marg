# Marg — Pune Urban Mobility Planner

Marg is a production-grade multimodal route planning application for Pune. It integrates Metro, Bus, and Walking paths to generate efficient, time-aware, ML‑scored routes using real-world geographic data and OpenStreetMap.

---

## Features

- **Location Search** — Type place names (e.g. "FC Road", "Pune Airport") with autocomplete powered by OSM Nominatim
- **Multimodal Routing** — Combines walking, bus, and metro segments via k-shortest-paths with diversity filtering
- **True Alternate Routes** — Structurally different route options (not just edge variants)
- **Mode Preferences** — Toggle "Prefer Metro", "Prefer Bus", or "Less Walking" to influence route scoring
- **ML Route Scoring** — Random Forest model predicts leg travel times; final score combines time, transfers, mode penalties, and walking distance
- **Step-by-Step Directions** — Timeline UI with bus route numbers, metro line names, boarding/alighting instructions
- **Transfer Detection** — Accurate counting of mode changes (bus→metro, etc.) ignoring walk segments
- **Mobile-First UI** — Bottom sheet on mobile, sidebar on desktop, responsive layout with smooth animations

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
│  main.py → graph.py (RouteEngine) → ranker.py        │
│          → inference.py (RF Model)                    │
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

1. **Nearest Node Lookup** — KDTree finds closest graph node to source/destination (max 1.5 km)
2. **Time-Bucketed Graph** — Simplified DiGraph with dynamic edge weights based on rush/off-peak × weekday/weekend
3. **K-Shortest Paths** — `nx.shortest_simple_paths` generates candidates weighted by `dynamic_time`
4. **Diversity Filter** — Candidates filtered by transit node overlap (<80%) to ensure structurally different routes
5. **ML Scoring** — Random Forest predicts per-leg travel time from (mode, distance, hour, day, congestion_zone)
6. **Ranking** — `score = time + (transfers × 8min) + mode_penalties + walk_penalty + comfort_bonus` (lower = better)

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
│   │   ├── network/graph.py # RouteEngine: k-shortest paths, transfer counting
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