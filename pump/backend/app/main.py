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
PUNE_VIEWBOX = "73.68,18.72,74.10,18.33"  # lon1,lat1,lon2,lat2


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
    Geocode a place name using Local Fuzzy Search + OSM Nominatim fallback.
    """
    try:
        # 1. Try local fast fuzzy search first
        local_results = search_engine.search(q, limit=5, threshold=70)
        
        # Determine if we need to call Nominatim to backfill
        needed = 5 - len(local_results)
        nom_results = []
        
        if needed > 0:
            async with httpx.AsyncClient(timeout=0.5) as client:
                resp = await client.get(
                    NOMINATIM_URL,
                    params={
                        "q": q,
                        "format": "json",
                        "limit": needed,
                        "viewbox": PUNE_VIEWBOX,
                        "bounded": 1,
                        "countrycodes": "in",
                        "addressdetails": 1,
                    },
                    headers={"User-Agent": NOMINATIM_USER_AGENT},
                )
                resp.raise_for_status()
                
                for r in resp.json():
                    nom_results.append({
                        "name": r.get("name", r.get("display_name", "").split(",")[0]),
                        "display_name": r.get("display_name", ""),
                        "lat": float(r["lat"]),
                        "lon": float(r["lon"]),
                        "score": 60 # Arbitrary base score for network results
                    })

        # Combine results
        combined = local_results + nom_results
        
        # Calculate distance to Pune center (18.5204, 73.8567) using simple haversine
        def haversine_km(lat1, lon1, lat2, lon2):
            R = 6371.0
            dlat = math.radians(lat2 - lat1)
            dlon = math.radians(lon2 - lon1)
            a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
            return R * c
            
        for r in combined:
            dist = haversine_km(r["lat"], r["lon"], 18.5204, 73.8567)
            r["distance_from_pune_center_km"] = round(dist, 1)
            
        # Re-rank: prioritize local results slightly, but penalize heavily by distance
        # Score logic: base score (local=70-100, nom=60) - (distance_km * 2)
        combined.sort(key=lambda x: x.get("score", 60) - (x["distance_from_pune_center_km"] * 2), reverse=True)

        # Deduplicate by approximate coordinated
        seen_coords = set()
        final_results = []
        for r in combined:
            coord_key = (round(r["lat"], 3), round(r["lon"], 3))
            if coord_key not in seen_coords:
                seen_coords.add(coord_key)
                final_results.append(r)
                if len(final_results) >= 5:
                    break
                    
        return {"results": final_results}

    except httpx.TimeoutException:
        # If Nominatim times out, return just local results
        return {"results": local_results}
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

        source_id, s_dist = engine.get_nearest_node(request.source.lat, request.source.lng)
        dest_id, d_dist = engine.get_nearest_node(request.destination.lat, request.destination.lng)

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
            err = RouteError.not_found()
            err["warnings"] = warnings
            return err

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
