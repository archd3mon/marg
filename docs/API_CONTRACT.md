# API Contract — Marg Pune Urban Mobility

> Canonical specification for the Marg HTTP API (`/api/v1`). Verified by `pump/backend/tests/test_api_contract.py` and captured as real Flutter test fixtures in `pump/mobile/test/fixtures/real/`.

---

## 1. Network & Connection Settings

- **Base URL (`API_BASE`):** Configured via `--dart-define=API_BASE=<URL>`
  - **Android Emulator (Local):** `http://10.0.2.2:8000/api/v1` (Debug/Profile only)
  - **Physical Device LAN (Local):** `http://<YOUR_LAN_IP>:8000/api/v1` (Debug/Profile only)
  - **Cloud (Hugging Face Spaces):** `https://<hf-user>-<space-name>.hf.space/api/v1` (Mandatory HTTPS for Release)
  - **Cloud (Render Production):** `https://<service>.onrender.com/api/v1` (Mandatory HTTPS for Release)
- **Timeouts:**
  - Connect: 10 seconds
  - Receive / Read: 45 seconds (allows for Render/HF free-tier spinning up from cold start)
- **Retry Policy:**
  - Retry idempotent `GET` requests twice with exponential backoff (1s, 3s).
- **Health Gate:**
  - App checks `GET /health` on startup. If routing engine is initializing or unavailable, app enters "Waking up Marg…" cold-start gate and polls every 3s.

---

## 2. Backend & Contract Change Workflow

To ensure zero contract drift between backend and clients:
1. **Rule:** Backend edits are allowed only if **ADDITIVE**, covered by `pump/backend/tests/test_api_contract.py`, and mirrored in `docs/API_CONTRACT.md` in the exact same commit.
2. **Workflow:**
   ```bash
   # 1. Edit backend code
   # 2. Run backend contract tests
   pytest pump/backend/tests/test_api_contract.py

   # 3. Re-capture real fixtures for Flutter
   bash scripts/capture_fixtures.sh
   # (or: cd pump/backend && python scripts/capture_fixtures.py ../mobile/test/fixtures/real)

   # 4. Update Flutter models/tests until green
   cd pump/mobile && flutter test
   ```

---

## 3. Endpoints Specification

### 3.0 GET `/`
Root service greeting and status endpoint.

**Response (200 OK):**
```json
{
  "name": "Pune Urban Mobility Planner - Marg",
  "status": "online",
  "docs": "/docs",
  "health": "/api/v1/health"
}
```

### 3.1 GET `/health`
Returns system component status, engine availability, and load metrics.

**Response (200 OK):**
```json
{
  "status": "ok",
  "components": {
    "graph": {
      "status": "ok",
      "nodes": 91714,
      "edges": 239280
    },
    "kdtree": {
      "status": "ok",
      "indexed_nodes": 91714
    },
    "ml_model": {
      "status": "ok"
    },
    "search": {
      "status": "ok",
      "indexed_points": 22896
    }
  },
  "routing_available": true,
  "load_time_s": 4.12
}
```

**Guarantees & Client Behavior:**
- `status`: `"ok"` or `"degraded"`.
- `routing_available` (bool): When `true`, route planning is online.
- When `routing_available` is `false` or server returns `503`, client renders the graceful cold-start "Waking up Marg…" screen.

---

### 3.2 GET `/network/stops`
Returns static transit stops for map initialization and network rendering.

**Response (200 OK):**
```json
{
  "stops": [
    {
      "id": "bus_32769",
      "name": "Forest Office Road",
      "code": "151131",
      "lat": 18.51983,
      "lon": 73.63158,
      "type": "bus_stop"
    },
    {
      "id": "metro_pu_01",
      "name": "PCMC",
      "lat": 18.6281,
      "lon": 73.8053,
      "type": "metro_station",
      "line": "Purple",
      "order": 1
    }
  ]
}
```

**Guarantees & Client Behavior:**
- `stops`: Array of transit stops.
- `type`: Explicitly `"bus_stop"` or `"metro_station"` (never bare `"bus"` or `"metro"`).
- In Marg v1 (bus-only), client filters for `type == "bus_stop"`. Metro stations are preserved for future scope.
- Coordinates: `lat` and `lon` are finite floating-point numbers.
- Backend caps initial bus stops at 500 for lightweight transmission.

---

### 3.3 GET `/network/stops/nearby`
Finds transit stops within walking distance of a geographic point.

**Query Parameters:**
| Parameter | Type | Required | Default | Description |
|---|---|:---:|:---:|---|
| `lat` | float | Yes | — | Latitude (-90 to 90) |
| `lng` | float | Yes | — | Longitude (-180 to 180) |
| `radius_m` | float | No | `1500` | Search radius in meters |
| `limit` | int | No | `20` | Maximum stops returned |
| `include_metro`| bool | No | `false` | Include metro stations in results |

**Response (200 OK):**
```json
{
  "stops": [
    {
      "id": "bus_39507",
      "code": "40691",
      "name": "Vanaz Corner",
      "lat": 18.50737,
      "lon": 73.80757,
      "type": "bus_stop",
      "distance_meters": 14
    },
    {
      "id": "bus_39030",
      "code": "30691",
      "name": "Vanaz Corner",
      "lat": 18.50758,
      "lon": 73.80784,
      "type": "bus_stop",
      "distance_meters": 25
    }
  ]
}
```

**Guarantees & Client Behavior:**
- `stops`: Sorted in strictly ascending order by `distance_meters`.
- Bounded: `distance_meters <= radius_m` and `stops.length <= limit`.
- `type`: Defaults to `"bus_stop"`. Includes `"metro_station"` only if `include_metro=true`.
- Empty state: If no stops within radius, returns 200 OK with `{"stops": []}`.
- Validation: Missing or out-of-range coordinates return `422 Unprocessable Entity`.

---

### 3.4 GET `/geocode/search`
Location and POI search for Pune, re-ranked with local haversine proximity.

**Query Parameters:**
| Parameter | Type | Required | Default | Description |
|---|---|:---:|:---:|---|
| `q` | string | Yes | — | Query text (min 2 characters) |
| `limit` | int | No | `8` | Maximum results returned |

**Response (200 OK) — Always Wrapped in `results`:**
```json
{
  "results": [
    {
      "name": "Kothrud Bus Depot",
      "display_name": "Kothrud Bus Depot (bus_station)",
      "lat": 18.5012,
      "lon": 73.8082,
      "type": "bus_station",
      "source": "local",
      "importance": 1.0
    },
    {
      "name": "Indian Oil Kothrud",
      "display_name": "Indian Oil Kothrud (fuel_station)",
      "lat": 18.5045,
      "lon": 73.8089,
      "type": "fuel_station",
      "source": "local",
      "importance": 1.0
    }
  ]
}
```

**Guarantees & Client Behavior:**
- **Wrapped Shape:** Guaranteed to return an object with a `"results"` array: `{"results": [...]}` (never a bare list).
- Client debounces input by 400ms before sending.
- Query validation: Queries with `< 2` characters return `422 Unprocessable Entity`.

---

### 3.5 POST `/routes/search`
Multimodal and bus-priority route planning with RAPTOR and ML-scoring.

**Request Body:**
```json
{
  "source": {
    "lat": 18.5074,
    "lng": 73.8077
  },
  "destination": {
    "lat": 18.5679,
    "lng": 73.9143
  },
  "departure_time": "2026-10-19T08:42:00+05:30",
  "mode_preferences": {
    "prefer_bus": true,
    "exclude_metro": true,
    "less_walking": false
  }
}
```

**Request Parameters:**
- `source`, `destination`: Objects with `lat` and `lng`.
- `departure_time` (optional): ISO-8601 timestamp with timezone. If omitted or malformed, server falls back to current time.
- `mode_preferences` (optional):
  - `exclude_metro`: When `true`, completely filters out metro legs and routes.
  - `prefer_bus`: Heavily favors bus routes.
  - `less_walking`: Applies a stronger penalty to walking distance during route ranking.

**Response (200 OK):**
```json
{
  "routes": [
    {
      "route_id": "route_1",
      "score": 142.57,
      "total_time_mins": 90,
      "transfers": 1,
      "total_walk_m": 1534,
      "uses_metro": false,
      "route_type": "recommended",
      "legs": [
        {
          "mode": "walk",
          "from_node": {
            "name": "Origin",
            "lat": 18.508284,
            "lon": 73.809349
          },
          "to_node": {
            "name": "Pratik Nagar",
            "lat": 18.508284,
            "lon": 73.809349
          },
          "length_m": 218.7,
          "duration_mins": 3,
          "route_names": [],
          "line_options": [],
          "line": "",
          "path": [
            [18.5073824, 73.8076731],
            [18.5075253, 73.8076289]
          ]
        },
        {
          "mode": "bus",
          "from_node": {
            "name": "Pratik Nagar",
            "lat": 18.508284,
            "lon": 73.809349
          },
          "to_node": {
            "name": "Pune Station Moledina Stand",
            "lat": 18.5271,
            "lon": 73.873001
          },
          "length_m": 9450.0,
          "duration_mins": 36,
          "route_names": ["1030"],
          "line_options": ["1030"],
          "line": "1030",
          "path": [
            [18.508284, 73.809349],
            [18.5083138, 73.8095246]
          ]
        }
      ]
    }
  ],
  "warnings": [],
  "departure_time_used": "2026-10-19T08:42:00+05:30"
}
```

**Guarantees & Normalization (`_normalize_for_clients`):**
1. **`route_id` Guarantee:** Guaranteed unique string for every route (e.g., `"route_1"`, `"route_2"`, or `"walk_direct"`).
2. **`route_type` Classification:** Values are strictly one of: `recommended`, `fastest`, `least_transfers`, `least_walking`, `alternative`. Route index 0 is always marked `recommended`.
3. **`line` and `line_options` Guarantee:**
   - Every bus and metro leg is guaranteed to contain a non-empty `line` string (e.g. `"1030"`), populated from `route_names[0]` if needed. Chip in UI is never blank.
   - `line_options` is guaranteed to be a list of alternative line strings.
4. **`path` Polyline Guarantee:**
   - Every leg includes a `path` coordinate array `[[lat, lon], ...]`.
   - Length of `path` is guaranteed $\ge 2$. If road-following geometry is missing, normalizer injects straight-line coordinates `[[from.lat, from.lon], [to.lat, to.lon]]`.
5. **`exclude_metro` Guarantee:**
   - When `exclude_metro: true` is passed, all returned routes guarantee `uses_metro: false` and every leg has `mode != "metro"`.
6. **`departure_time_used`:** ISO timestamp reflecting the actual time used for GTFS timetable lookups. Arrival time = `departure_time_used + total_time_mins`.
7. **`warnings`:** Array of advisory strings. If present, client renders `warnings[0]` as an inline footnote under the results header.

---

## 4. Failure, Cold-Start & Empty States

| Condition | HTTP Status | Response Payload | Client Handling |
|---|:---:|---|---|
| **Cold Start / Engine Unavailable** | `503` | `{"detail": "Routing engine is not available"}` | Show "Waking up Marg…" cold-start gate and poll `/health` every 3s. |
| **Too Far From Transit** | `200` | `{"routes": [], "message": "Origin or destination is too far from the transit network.", "warnings": []}` | Show friendly empty state explaining origin/destination is beyond network coverage; offer button to re-center pin. |
| **Walk Direct Fallback** | `200` | `{"routes": [{"route_id": "walk_direct", "uses_metro": false, "transfers": 0, "legs": [...]}]}` | Render single walk itinerary without bus transfer chips. |
| **Invalid Payload** | `422` | `{"detail": [...]}` | Show validation error message. |

---

## 5. UI Badges & Chips Mapping

### Route Badges
| `route_type` | Badge Text | Token Color | Icon |
|---|---|---|---|
| `recommended` / `fastest` | Fastest | `MargColors.success` (Green) | Bolt |
| `least_transfers` | Fewer transfers | `MargColors.primary` (Blue) | Merge / Arrow |
| `least_walking` | Less walking | `MargColors.warning` (Orange) | Walk |
| `alternative` | (none) | — | — |

### Leg Chips
- **`walk`:** Grey chip showing walking minutes (e.g. `🚶 5m`).
- **`bus`:** Blue chip showing bus line name (e.g. `🚌 1030`). If `line_options.length > 1`, display `+N` suffix (e.g. `1030 +2`).
- **`metro`:** Purple chip showing line name (hidden in v1 bus-only mode).

---

## 6. Honest Transit Disclosure

Marg uses real GTFS timetables and spatial graph routing. The app never invents live vehicle positions, crowd numbers, or fictitious live arrivals:
- Schedule-based trips are explicitly labeled **SCHEDULED**.
- Disruptions and service notices are user-managed with sample data explicitly tagged **Sample**.
