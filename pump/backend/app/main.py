from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import json
import httpx
import math
import time
import logging
import re
import sqlite3
import difflib
from pathlib import Path
import os
import pytz

from app.network.graph import engine
from app.ml.inference import predictor
from app.scoring.ranker import score_and_rank_routes
from app.search.search import search_engine

logger = logging.getLogger(__name__)

# --- Lifespan (replaces deprecated on_event) ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    t0 = time.time()
    print("=" * 50)
    print("Initializing Core Engines...")
    engine.load()
    predictor.load()
    search_engine.load()
    
    # Load POI database (new schema)
    poi_db_path = DATA_DIR / "processed" / "pune_poi.sqlite"
    if poi_db_path.exists():
        conn = sqlite3.connect(str(poi_db_path), check_same_thread=False)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA cache_size=-64000")  # 64MB cache
        app.state.poi_db = conn
        count = conn.execute("SELECT COUNT(*) FROM pois").fetchone()[0]
        logger.info(f"POI index loaded: {count} entries")
        print(f"  POI index loaded: {count} entries")
        
        # Feed POI names into the rapidfuzz search engine for fuzzy matching
        try:
            cur = conn.cursor()
            cur.execute("SELECT name, poi_type, lat, lon FROM pois")
            poi_count: int = 0
            existing_names = set(n.lower() for n in search_engine.names)
            for r in cur.fetchall():
                if r["name"].lower() not in existing_names:
                    search_engine.points.append({
                        "name": r["name"],
                        "display_name": f"{r['name']} ({r['poi_type']})",
                        "lat": float(r["lat"]),
                        "lon": float(r["lon"]),
                        "type": r["poi_type"],
                    })
                    search_engine.names.append(r["name"])
                    existing_names.add(r["name"].lower())
                    poi_count += 1
            print(f"  Injected {poi_count} POIs into local fuzzy search.")
        except Exception as e:
            logger.warning(f"Failed to inject POIs into search engine: {e}")
    else:
        logger.warning("pune_poi.sqlite not found — run scripts/build_poi_index.py")
        app.state.poi_db = None

    elapsed: float = round(float(time.time() - t0), 2)
    print(f"All engines ready in {elapsed}s")
    print("=" * 50)
    yield
    # Shutdown
    if getattr(app.state, 'poi_db', None):
        app.state.poi_db.close()


app = FastAPI(title="Pune Urban Mobility Planner - Marg", lifespan=lifespan)

# CORS — explicit allowlist.
# capacitor://localhost is the WebView origin used by Capacitor on Android/iOS.
# ALLOWED_ORIGINS env var (comma-separated) lets Render / CI override this without
# touching code. Wildcard + credentials is a browser spec violation, so we list
# origins explicitly.
_raw_origins = os.getenv(
    "ALLOWED_ORIGINS",
    # capacitor://localhost — Capacitor default scheme
    # https://localhost — when androidScheme='https' is set in capacitor.config.ts
    # localhost:5173 variants — Vite dev server
    "capacitor://localhost,https://localhost,http://localhost:5173,http://127.0.0.1:5173,http://localhost:3000"
)
ALLOWED_ORIGINS = [o.strip() for o in _raw_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)

# Data directory — resolves relative to this file so it works on any host
# (Render, local dev) without requiring PUMP_DATA_DIR to be set.
# Repo layout: pump/backend/app/main.py
#   .parent       → pump/backend/app/
#   .parent.parent → pump/backend/
#   .parent.parent.parent → pump/
#   / "data"       → pump/data/
_THIS_FILE = Path(__file__).resolve()
_REPO_DATA_DIR = _THIS_FILE.parent.parent.parent / "data"
DATA_DIR_ENV = os.getenv("PUMP_DATA_DIR")
DATA_DIR = Path(DATA_DIR_ENV) if DATA_DIR_ENV else _REPO_DATA_DIR

# Nominatim settings
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
NOMINATIM_USER_AGENT = "Marg-PuneTransitPlanner/1.0"
PUNE_VIEWBOX = "73.6,18.2,74.3,18.8"  # lon1,lat1,lon2,lat2 (wider for PCMC+Hinjewadi)

GEOCODE_CACHE: dict[str, dict] = {}

# Import master places for Tier 0 geocoding
from app.utils import PUNE_MASTER_PLACES


# --- Schemas ---
class Point(BaseModel):
    lat: float
    lng: float

class RouteRequest(BaseModel):
    source: Point
    destination: Point
    departure_time: Optional[str] = None      # ISO-8601 string or None
    mode_preferences: Optional[dict] = None   # {"prefer_metro": True, ...}


def parse_departure_time(raw: Optional[str]) -> datetime:
    """
    Parse ISO-8601 departure_time sent by the client.
    Falls back to current local Pune time if None or unparseable.
    Always returns a timezone-aware datetime in Asia/Kolkata.
    """
    IST = pytz.timezone("Asia/Kolkata")
    if raw:
        try:
            dt = datetime.fromisoformat(raw)
            if dt.tzinfo is None:
                dt = IST.localize(dt)
            else:
                dt = dt.astimezone(IST)
            return dt
        except (ValueError, TypeError):
            pass
    return datetime.now(IST)


# --- Error Responses ---
class RouteError:
    @staticmethod
    def not_found():
        return {"routes": [], "message": "No routes found between these locations."}

    @staticmethod
    def too_far():
        return {"routes": [], "message": "Origin or destination is too far from the transit network.", "warnings": []}

    @staticmethod
    def dataset_missing(detail):
        raise HTTPException(status_code=503, detail=f"Dataset not available: {detail}")


# --- Endpoints ---

@app.get("/api/v1/health")
def health_check():
    """Detailed health check showing per-component status."""
    graph_ok = engine.routing_available
    ml_ok = predictor.model_loaded
    search_ok = len(search_engine.points) > 0 if hasattr(search_engine, 'points') else False

    overall = "ok" if (graph_ok and ml_ok) else "degraded"

    return {
        "status": overall,
        "components": {
            "graph": {
                "status": "ok" if engine.load_status.get("graph") else "error",
                "nodes": len(engine.G.nodes) if engine.G else 0,
                "edges": len(engine.G.edges) if engine.G else 0,
            },
            "kdtree": {
                "status": "ok" if engine.load_status.get("kdtree") else "error",
                "indexed_nodes": len(engine.node_ids) if engine.node_ids else 0,
            },
            "ml_model": {
                "status": "ok" if ml_ok else "error",
            },
            "search": {
                "status": "ok" if search_ok else "error",
                "indexed_points": len(search_engine.points) if hasattr(search_engine, 'points') else 0,
            },
        },
        "routing_available": graph_ok,
        "load_time_s": engine.load_time_s,
    }


@app.get("/api/v1/network/stops")
def get_stops():
    """Returns a lightweight list of stops for the frontend map."""
    stops = []

    metro_file = DATA_DIR / "processed" / "metro_stations.json"
    bus_file = DATA_DIR / "processed" / "bus_stops.json"

    if metro_file.exists():
        with open(metro_file) as f:
            stops.extend(json.load(f))

    if bus_file.exists():
        with open(bus_file) as f:
            all_buses = json.load(f)
            stops.extend(all_buses[:500])

    return {"stops": stops}


@app.get("/api/v1/geocode/search")
async def geocode_search(q: str = Query(..., min_length=2, description="Search query"), limit: int = 8):
    """
    4-tier geocoding system:
      Tier 0: PUNE_MASTER_PLACES dict — instant dict lookup + fuzzy match
      Tier 1: FTS5 full-text search on pune_poi.sqlite
      Tier 2: Nominatim API with Pune bounding box
      Tier 3: Fuzzy fallback using difflib on all known place names

    Always returns at least 1 result. Never returns [].
    Results sorted by importance DESC.
    """
    try:
        q_lower = q.strip().lower()
        now = time.time()

        # Clean expired cache (7 days TTL)
        expired = [k for k, v in GEOCODE_CACHE.items() if now - float(v.get('ts', 0)) > 7 * 86400]
        for k in expired:
            del GEOCODE_CACHE[k]

        # Check cache
        if q_lower in GEOCODE_CACHE:
            return {"results": GEOCODE_CACHE[q_lower]["data"]}

        results = []

        # ── Tier 0: Exact + prefix match on master dict ──────────────────
        for name, data in PUNE_MASTER_PLACES.items():
            if q_lower in name.lower() or name.lower() in q_lower:
                results.append({
                    "name": name,
                    "display_name": f"{name} ({data.get('type', 'place')})",
                    "lat": data["lat"],
                    "lon": data["lon"],
                    "type": data.get("type", "place"),
                    "source": "local",
                    "importance": 1.0,
                })
            # Also check alt names
            elif "alt" in data:
                for alt in data["alt"].split(","):
                    if q_lower in alt.strip().lower() or alt.strip().lower() in q_lower:
                        results.append({
                            "name": name,
                            "display_name": f"{name} ({data.get('type', 'place')})",
                            "lat": data["lat"],
                            "lon": data["lon"],
                            "type": data.get("type", "place"),
                            "source": "local",
                            "importance": 1.0,
                        })
                        break

        # ── Tier 1: FTS5 search (if DB available) ────────────────────────
        if getattr(app.state, "poi_db", None):
            try:
                cur = app.state.poi_db.cursor()
                clean_q = re.sub(r'[^a-zA-Z0-9 ]', '', q_lower)
                if clean_q.strip():
                    fts_sql = """
                        SELECT p.name, p.lat, p.lon, p.poi_type, p.importance
                        FROM pois p
                        JOIN pois_fts ON p.id = pois_fts.rowid
                        WHERE pois_fts MATCH ?
                        ORDER BY p.importance DESC, rank
                        LIMIT 20
                    """
                    # Try AND-prefix match first
                    tokens = [f"{t}*" for t in clean_q.split() if t]
                    if tokens:
                        and_query = " AND ".join(tokens)
                        try:
                            cur.execute(fts_sql, (and_query,))
                            rows = cur.fetchall()
                        except Exception:
                            rows = []

                        if not rows:
                            # Fall back to OR-prefix match
                            tokens = [f"{t}*" for t in clean_q.split() if len(t) > 1]
                            if tokens:
                                or_query = " OR ".join(tokens)
                                try:
                                    cur.execute(fts_sql, (or_query,))
                                    rows = cur.fetchall()
                                except Exception:
                                    rows = []

                        for row in rows:
                            results.append({
                                "name": row[0],
                                "display_name": f"{row[0]} ({row[3]})",
                                "lat": float(row[1]),
                                "lon": float(row[2]),
                                "type": row[3],
                                "source": "local",
                                "importance": float(row[4]) if row[4] else 0.5,
                            })
            except Exception as fts_err:
                logger.warning(f"FTS search failed: {fts_err}")

        # ── Tier 2: Nominatim (only if < 3 local results) ───────────────
        if len(results) < 3:
            try:
                async with httpx.AsyncClient(timeout=5.0) as client:
                    resp = await client.get(
                        NOMINATIM_URL,
                        params={
                            "q": q,
                            "format": "json",
                            "limit": 10,
                            "viewbox": PUNE_VIEWBOX,
                            "bounded": 0,
                            "countrycodes": "in",
                            "addressdetails": 1,
                        },
                        headers={"User-Agent": NOMINATIM_USER_AGENT},
                    )
                    resp.raise_for_status()

                    from app.utils import haversine
                    for r in resp.json():
                        lat = float(r["lat"])
                        lon = float(r["lon"])
                        dist = haversine({'lat': lat, 'lng': lon}, {'lat': 18.5204, 'lng': 73.8567})
                        results.append({
                            "name": r.get("name", r.get("display_name", "").split(",")[0]),
                            "display_name": r.get("display_name", ""),
                            "lat": lat,
                            "lon": lon,
                            "source": "nominatim",
                            "importance": max(0.3, 0.7 - dist / 100),
                            "distance_from_pune_center_km": round(dist, 1),
                        })
            except Exception as e:
                logger.warning(f"Nominatim fetch failed: {e}")

        # ── Tier 3: Fuzzy fallback (only if still empty) ────────────────
        if not results:
            all_names = list(PUNE_MASTER_PLACES.keys())
            matches = difflib.get_close_matches(q, all_names, n=3, cutoff=0.5)
            for m in matches:
                data = PUNE_MASTER_PLACES[m]
                results.append({
                    "name": m,
                    "display_name": f"{m} (did you mean?)",
                    "lat": data["lat"],
                    "lon": data["lon"],
                    "type": data.get("type", "place"),
                    "source": "fuzzy",
                    "importance": 0.6,
                })

        # ── Absolute last resort: Pune city center ──────────────────────
        if not results:
            results = [{
                "name": "Pune City Center",
                "display_name": "Pune City Center",
                "lat": 18.5204,
                "lon": 73.8567,
                "source": "fallback",
                "importance": 0.1,
            }]

        # ── Deduplicate by (round(lat,3), round(lon,3)) ─────────────────
        seen: set[tuple[float, float]] = set()
        unique: list[dict] = []
        for r in sorted(results, key=lambda x: -x.get("importance", 0)):
            key = (round(float(r["lat"]), 3), round(float(r["lon"]), 3))
            if key not in seen:
                seen.add(key)
                unique.append(r)

        final_results = unique[:limit]

        GEOCODE_CACHE[q_lower] = {"ts": now, "data": final_results}
        return {"results": final_results}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Geocoding error: {str(e)}")



# --- OSRM Walk Path Enhancement ---
def _decode_polyline(encoded: str) -> list:
    """Decode Google-style encoded polyline into [[lat, lon], ...]."""
    result = []
    index = 0
    lat = 0
    lng = 0
    while index < len(encoded):
        # Latitude
        shift = 0
        b = 0x20
        val = 0
        while b >= 0x20:
            b = ord(encoded[index]) - 63
            index += 1
            val |= (b & 0x1F) << shift
            shift += 5
        lat += (~(val >> 1) if val & 1 else val >> 1)
        # Longitude
        shift = 0
        b = 0x20
        val = 0
        while b >= 0x20:
            b = ord(encoded[index]) - 63
            index += 1
            val |= (b & 0x1F) << shift
            shift += 5
        lng += (~(val >> 1) if val & 1 else val >> 1)
        result.append([lat / 1e5, lng / 1e5])
    return result


def _enhance_walk_paths(ranked_routes: list):
    """
    Post-process ranked routes: for walk legs that only have a 2-point
    straight-line path, fetch road-following geometry from OSRM foot router.
    Silently skips on any error (timeout, network) — straight line remains.
    """
    import httpx

    # Only enhance the top-ranked route to avoid OSRM public API rate limits / sequential timeouts
    if not ranked_routes:
        return
        
    top_route = ranked_routes[0]
    for leg in top_route.get("legs", []):
        if leg.get("mode") != "walk":
            continue
        path = leg.get("path")
        # Enhance legs with OSRM road-following geometry (use first & last points)
        if path and len(path) >= 2:
            from_pt = path[0]  # [lat, lon]
            to_pt = path[-1]    # [lat, lon]
            try:
                url = (
                    f"https://router.project-osrm.org/route/v1/foot/"
                    f"{from_pt[1]},{from_pt[0]};{to_pt[1]},{to_pt[0]}"
                    f"?overview=full&geometries=polyline"
                )
                resp = httpx.get(url, timeout=0.8) # ultra fast timeout
                if resp.status_code == 200:
                    data = resp.json()
                    routes_data = data.get("routes", [])
                    if routes_data:
                        geom = routes_data[0].get("geometry", "")
                        if geom:
                            decoded = _decode_polyline(geom)
                            if len(decoded) > 2:
                                leg["path"] = decoded
            except Exception:
                pass  # Keep straight-line path on any error


@app.post("/api/v1/routes/search")
def search_routes(request: RouteRequest):
    # Check routing_available first (Upgrade 1)
    if not engine.routing_available:
        raise HTTPException(
            status_code=503,
            detail="Routing engine unavailable — data files missing or corrupt. Check /api/v1/health for details."
        )

    try:
        # Parse departure time
        departure_dt = parse_departure_time(request.departure_time)
        hour = departure_dt.hour
        day = departure_dt.weekday()

        s_nodes, s_warn = engine.find_nearest_nodes(request.source.lat, request.source.lng)
        d_nodes, d_warn = engine.find_nearest_nodes(request.destination.lat, request.destination.lng)
        
        source_id, s_dist = s_nodes[0]
        dest_id, d_dist = d_nodes[0]

        warnings = []
        if s_dist > 0.025 or d_dist > 0.025:
            warnings.append("Origin or destination is far from transit stops. Route may involve a long walk.")
            
        # Warning for data-sparse off-peak regions
        if hour < 6 or hour > 21:
            warnings.append("High-frequency direct connections may have ceased for the night. Slower alternatives shown.")

        # Generate routes
        k_paths = engine.k_shortest_paths(
            request.source.lat, request.source.lng,
            request.destination.lat, request.destination.lng,
            k=5, departure_hour=hour, departure_day=day,
            mode_preferences=request.mode_preferences,
        )

        if not k_paths:
            from app.utils import haversine
            walk_distance_km = haversine(
                {'lat': request.source.lat, 'lng': request.source.lng},
                {'lat': request.destination.lat, 'lng': request.destination.lng}
            )
            walk_time_min = walk_distance_km / 5.0 * 60
            routes = [{
                "route_id": "walk_direct",
                "legs": [{
                    "mode": "walk",
                    "from_node": {"name": "Origin", "lat": request.source.lat, "lon": request.source.lng},
                    "to_node": {"name": "Destination", "lat": request.destination.lat, "lon": request.destination.lng},
                    "length_m": walk_distance_km * 1000,
                    "travel_time": walk_time_min * 60,
                    "path": [[request.source.lat, request.source.lng], [request.destination.lat, request.destination.lng]]
                }],
                "segments": [{
                    "mode": "walk",
                    "route_id": None,
                    "from": "Origin",
                    "to": "Destination",
                    "duration": walk_time_min * 60
                }],
                "total_time_mins": round(walk_time_min),
                "total_time": walk_time_min * 60,
                "total_time_s": walk_time_min * 60,
                "total_distance_km": round(walk_distance_km, 2),
                "total_distance_m": walk_distance_km * 1000,
                "transfers": 0,
                "score": walk_time_min,
                "badges": ["🚶 Walk only"],
                "warning": "No transit route found. Showing direct walking distance only."
            }]
            return {"routes": routes, "warnings": warnings, "departure_time_used": departure_dt.isoformat()}

        # Score & Rank (with mode preferences)
        ranked = score_and_rank_routes(
            k_paths,
            departure_hour=hour,
            departure_day=day,
            mode_preferences=request.mode_preferences,
            predictor=predictor,
        )

        # Enhance walk legs with OSRM road-following paths
        _enhance_walk_paths(ranked)

        return {"routes": ranked, "warnings": warnings, "departure_time_used": departure_dt.isoformat()}

    except ValueError as e:
        if "too far" in str(e).lower():
            return RouteError.too_far()
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Routing error: {str(e)}")
