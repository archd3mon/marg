# API Contract (read from `pump/backend/app/main.py` and the React client)

Base: `--dart-define=API_BASE=https://<render-host>/api/v1`. Timeouts: connect 10 s, receive 45 s (cold start). Retry GET twice with 1 s / 3 s backoff.

> Fields below were read from the backend and React components. **First task of Phase 1: hit each endpoint once, save real JSON to `test/fixtures/`, and generate models from those.** Treat anything not in a fixture as optional/nullable.

## GET /health
Granular status for Graph, ML and Search engines. Use on app start; if routing unavailable show the "Waking up Marg…" state and retry.

## GET /network/stops
`{ "stops": [ {id, name, lat, lon/lng, type: "bus"|"metro", ...} ] }` — metro entries are included; **filter `type == "bus"` in v1** (keep the field for future scope). Backend caps bus stops at 500: use for map markers/nearby only.

## GET /geocode/search?q=<≥2 chars>&limit=8
Returns ranked place results (local POI + Nominatim, Pune-proximity re-ranked). Debounce 400 ms; cache per query for the session.

## POST /routes/search
Request:
```json
{ "source": {"lat": 18.50, "lng": 73.81}, "destination": {"lat": 18.56, "lng": 73.91},
  "departure_time": "2026-10-16T08:42:00+05:30",   // optional ISO-8601
  "mode_preferences": {"prefer_bus": true, "less_walking": false} }   // optional
```
Response (200):
```json
{ "routes": [ {
    "route_id": "…", "score": 12.3, "total_time_mins": 55, "transfers": 1, "total_walk_m": 650,
    "uses_metro": false,
    "route_type": "recommended|fastest|least_transfers|least_walking|alternative",
    "legs": [ { "mode": "walk|bus|metro", "line": "17", "from_node": {"name","lat","lon"},
                "to_node": {"name","lat","lon"}, "length_m": 450, "duration_mins": 6 } ]
  } ],
  "warnings": ["…"], "departure_time_used": "ISO" }
```
- 503 → routing unavailable (show cold-start/outage state with retry).
- `routes: []` + `message` → "too far from the transit network" empty state (friendly copy, offer to move pin).
- Walk-only fallback has `route_id: "walk_direct"` and legs of mode `walk`.

## UI mapping
| `route_type` | Badge | Colour | Icon |
|---|---|---|---|
| fastest / recommended | Fastest | green | bolt |
| least_transfers | Fewer transfers | blue | merge |
| least_walking | Less walking | orange | walk |
| alternative | (none) | — | — |

Leg chips: `walk` → grey chip with minutes; `bus` → blue chip with `line`; `metro` → purple chip (hidden in v1 but styled).
Arrival time = `departure_time_used + total_time_mins`. Show `warnings[0]` as an inline footnote under the sheet header, never a modal.

## Not available (don't invent)
Real-time vehicle positions · service alerts · crowd levels. See PLAYBOOK §0 constraints.
