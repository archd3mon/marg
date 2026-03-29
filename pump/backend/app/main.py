from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import json
import httpx
import math
import time
import logging
from pathlib import Path
import os

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
    
    # Load POI database
    import sqlite3
    poi_db_path = DATA_DIR / "pune_poi.sqlite"
    if poi_db_path.exists():
        app.state.poi_db = sqlite3.connect(str(poi_db_path), check_same_thread=False)
        app.state.poi_db.row_factory = sqlite3.Row
        logger.info("POI index loaded")
        
        # Feed POI names into the rapidfuzz search engine for fuzzy matching
        try:
            cur = app.state.poi_db.cursor()
            cur.execute("SELECT name, type, lat, lon FROM pois")
            poi_count = 0
            existing_names = set(n.lower() for n in search_engine.names)
            for r in cur.fetchall():
                if r["name"].lower() not in existing_names:
                    search_engine.points.append({
                        "name": r["name"],
                        "display_name": f"{r['name']} ({r['type']})",
                        "lat": float(r["lat"]),
                        "lon": float(r["lon"]),
                        "type": r["type"],
                    })
                    search_engine.names.append(r["name"])
                    existing_names.add(r["name"].lower())
                    poi_count += 1
            print(f"  Injected {poi_count} POIs into local fuzzy search.")
        except Exception as e:
            logger.warning(f"Failed to inject POIs into search engine: {e}")
    else:
        logger.warning("pune_poi.sqlite not found — geocoding will rely on Nominatim only")
        app.state.poi_db = None

    # Pre-warm geocode cache with PUNE_KNOWN_PLACES
    try:
        from app.utils import PUNE_KNOWN_PLACES
        for name, data in PUNE_KNOWN_PLACES.items():
            GEOCODE_CACHE[name.lower()] = {
                "ts": time.time(),
                "data": [{"display_name": name, "name": name, "lat": data["lat"], "lon": data["lng"], "source": "local", "distance_from_pune_center_km": 0}]
            }
    except Exception as e:
        logger.warning(f"Could not prewarm geocode cache: {e}")

    elapsed = round(time.time() - t0, 2)
    print(f"All engines ready in {elapsed}s")
    print("=" * 50)
    yield
    # Shutdown (nothing to clean up)


app = FastAPI(title="Pune Urban Mobility Planner - Marg", lifespan=lifespan)

# Enable CORS for React frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Data directory
DEFAULT_DATA_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/processed")
DATA_DIR_ENV = os.getenv("PUMP_DATA_DIR")
DATA_DIR = Path(DATA_DIR_ENV) if DATA_DIR_ENV else DEFAULT_DATA_DIR

# Nominatim settings
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
NOMINATIM_USER_AGENT = "Marg-PuneTransitPlanner/1.0"
PUNE_VIEWBOX = "73.7,18.3,74.2,18.7"  # lon1,lat1,lon2,lat2

GEOCODE_CACHE = {}


# --- Schemas ---
class Point(BaseModel):
    lat: float
    lng: float

class RouteRequest(BaseModel):
    source: Point
    destination: Point
    departure_time: str  # "YYYY-MM-DDTHH:MM:SS"
    mode_preferences: Optional[dict] = None  # {"prefer_metro": True, ...}


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

    metro_file = DATA_DIR / "metro_stations.json"
    bus_file = DATA_DIR / "bus_stops.json"

    if metro_file.exists():
        with open(metro_file) as f:
            stops.extend(json.load(f))

    if bus_file.exists():
        with open(bus_file) as f:
            all_buses = json.load(f)
            stops.extend(all_buses[:500])

    return {"stops": stops}


@app.get("/api/v1/geocode/search")
async def geocode_search(q: str = Query(..., min_length=2, description="Search query")):
    """
    Tier 1: Check PUNE_KNOWN_PLACES dict (in cache)
    Tier 2: FTS5 search in pune_poi.sqlite
    Tier 3: Nominatim API with haversine re-rank
    """
    try:
        q_lower = q.lower().strip()
        now = time.time()
        
        # Clean expired cache (7 days TTL)
        expired = [k for k, v in GEOCODE_CACHE.items() if now - float(v.get('ts', 0)) > 7*86400]
        for k in expired:
            del GEOCODE_CACHE[k]
            
        # Tier 1: Cache (Pre-warmed with known places)
        if q_lower in GEOCODE_CACHE:
            return {"results": GEOCODE_CACHE[q_lower]["data"]}

        results = []
        
        # Tier 2: FTS search in SQLite
        if getattr(app.state, "poi_db", None):
            try:
                cur = app.state.poi_db.cursor()
                import re
                clean_q = re.sub(r'[^a-zA-Z0-9 ]', '', q_lower)
                if clean_q:
                    fts_sql = """
                        SELECT p.name, p.type, p.lat, p.lon 
                        FROM pois_fts f 
                        JOIN pois p ON p.id = f.rowid 
                        WHERE pois_fts MATCH ? 
                        ORDER BY f.rank LIMIT 5
                    """
                    # 1. Prefix match on all terms
                    tokens = [f"{t}*" for t in clean_q.split()]
                    and_query = " AND ".join(tokens)
                    cur.execute(fts_sql, (and_query, ))
                    rows = cur.fetchall()
                    if not rows:
                        # 2. Token overlap (any token matches)
                        tokens = [f"{t}*" for t in clean_q.split() if len(t)>2]
                        if tokens:
                            or_query = " OR ".join(tokens)
                            cur.execute(fts_sql, (or_query, ))
                            rows = cur.fetchall()

                    for r in rows:
                        results.append({
                            "name": r["name"],
                            "display_name": r["name"] + f" ({r['type']})",
                            "lat": float(r["lat"]),
                            "lon": float(r["lon"]),
                            "source": "local",
                        })
            except Exception as fts_err:
                logger.warning(f"FTS search failed: {fts_err}")

        # Tier 2.5: Existing rapidfuzz local search (bus stops, metro, landmarks)
        if not results:
            try:
                local_matches = search_engine.search(q, limit=5, threshold=55)
                for m in local_matches:
                    results.append({
                        "name": m["name"],
                        "display_name": m["display_name"],
                        "lat": m["lat"],
                        "lon": m["lon"],
                        "source": "local",
                    })
            except Exception as local_err:
                logger.warning(f"Local search failed: {local_err}")

        # Tier 3: Nominatim fallback
        if not results:
            try:
                async with httpx.AsyncClient(timeout=3.0) as client:
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
                    
                    nom_results = []
                    for r in resp.json():
                        nom_results.append({
                            "name": r.get("name", r.get("display_name", "").split(",")[0]),
                            "display_name": r.get("display_name", ""),
                            "lat": float(r["lat"]),
                            "lon": float(r["lon"]),
                            "source": "nominatim",
                        })
                        
                    from app.utils import haversine
                    for r in nom_results:
                        dist = haversine({'lat': r["lat"], 'lng': r["lon"]}, {'lat': 18.5204, 'lng': 73.8567})
                        r["distance_from_pune_center_km"] = round(dist, 1)
                        
                    # Prioritize within 30km
                    nom_results.sort(key=lambda x: (x["distance_from_pune_center_km"] > 30, x["distance_from_pune_center_km"]))
                    results.extend(nom_results)
            except Exception as e:
                logger.warning(f"Nominatim fetch failed: {e}")

        # Fuzzy match fallback if still nothing
        if not results and getattr(app.state, "poi_db", None):
            import difflib
            cur = app.state.poi_db.cursor()
            cur.execute("SELECT name, type, lat, lon FROM pois")
            all_pois = cur.fetchall()
            names = [r["name"] for r in all_pois]
            matches = difflib.get_close_matches(q, names, n=1, cutoff=0.4)
            if matches:
                best_match = matches[0]
                cur.execute("SELECT name, type, lat, lon FROM pois WHERE name=? LIMIT 1", (best_match,))
                r = cur.fetchone()
                if r:
                    results.append({
                        "name": r["name"],
                        "display_name": f"Nearest match: {r['name']} ({r['type']})",
                        "lat": float(r["lat"]),
                        "lon": float(r["lon"]),
                        "source": "local",
                    })

        if not results:
            # Absolute worst-case fallback, should rarely happen
            return {"results": []}

        # Deduplicate
        seen_coords = set()
        final_results = []
        for r in results:
            coord_key = (round(float(r["lat"]), 3), round(float(r["lon"]), 3))
            if coord_key not in seen_coords:
                seen_coords.add(coord_key)
                final_results.append(r)
                if len(final_results) >= 5:
                    break
                    
        GEOCODE_CACHE[q_lower] = {"ts": now, "data": final_results}
        return {"results": final_results}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Geocoding error: {str(e)}")


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
        try:
            from datetime import datetime
            dt = datetime.fromisoformat(request.departure_time.replace("Z", "+00:00"))
            hour = dt.hour
            day = dt.weekday()
        except Exception:
            hour = 10
            day = 0

        s_nodes, s_warn = engine.find_nearest_nodes(request.source.lat, request.source.lng)
        d_nodes, d_warn = engine.find_nearest_nodes(request.destination.lat, request.destination.lng)
        
        source_id, s_dist = s_nodes[0]
        dest_id, d_dist = d_nodes[0]

        warnings = []
        if s_dist > 0.025 or d_dist > 0.025:
            warnings.append("Origin or destination is far from transit stops. Route may involve a long walk.")

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
                "total_time_min": round(walk_time_min),
                "total_time": walk_time_min * 60,
                "total_time_s": walk_time_min * 60,
                "total_distance_km": round(walk_distance_km, 2),
                "total_distance_m": walk_distance_km * 1000,
                "transfers": 0,
                "score": walk_time_min,
                "badges": ["🚶 Walk only"],
                "warning": "No transit route found. Showing direct walking distance only."
            }]
            return {"routes": routes, "warnings": warnings}

        # Score & Rank (with mode preferences)
        ranked = score_and_rank_routes(
            k_paths,
            departure_hour=hour,
            departure_day=day,
            mode_preferences=request.mode_preferences,
            predictor=predictor,
        )

        return {"routes": ranked, "warnings": warnings}

    except ValueError as e:
        if "too far" in str(e).lower():
            return RouteError.too_far()
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Routing error: {str(e)}")
