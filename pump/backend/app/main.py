from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import json
import httpx
from pathlib import Path
import os

from app.network.graph import engine
from app.ml.inference import predictor
from app.scoring.ranker import score_and_rank_routes


# --- Lifespan (replaces deprecated on_event) ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("Initializing Core Engines...")
    engine.load()
    predictor.load()
    print("Engines ready.")
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
        return {"routes": [], "message": "Origin or destination is too far from the transit network (>1.5 km)."}

    @staticmethod
    def dataset_missing(detail):
        raise HTTPException(status_code=503, detail=f"Dataset not available: {detail}")


# --- Endpoints ---

@app.get("/api/v1/health")
def health_check():
    return {
        "status": "ok",
        "graph_nodes": len(engine.G.nodes) if engine.G else 0,
        "graph_edges": len(engine.G.edges) if engine.G else 0,
        "ml_loaded": predictor.model is not None,
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
    Geocode a place name using OSM Nominatim, scoped to Pune.
    Returns up to 5 results with name, display_name, lat, lon.
    """
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(
                NOMINATIM_URL,
                params={
                    "q": q,
                    "format": "json",
                    "limit": 5,
                    "viewbox": PUNE_VIEWBOX,
                    "bounded": 1,
                    "addressdetails": 1,
                },
                headers={"User-Agent": NOMINATIM_USER_AGENT},
            )
            resp.raise_for_status()
            results = resp.json()

        return {
            "results": [
                {
                    "name": r.get("name", r.get("display_name", "").split(",")[0]),
                    "display_name": r.get("display_name", ""),
                    "lat": float(r["lat"]),
                    "lon": float(r["lon"]),
                }
                for r in results
            ]
        }
    except httpx.TimeoutException:
        return {"results": [], "error": "Geocoding service timed out"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Geocoding error: {str(e)}")


@app.post("/api/v1/routes/search")
def search_routes(request: RouteRequest):
    # Validate engine is loaded
    if engine.G is None:
        raise HTTPException(status_code=503, detail="Routing engine not initialized. Please wait for startup.")
    if predictor.model is None:
        raise HTTPException(status_code=503, detail="ML model not loaded.")

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

        # Generate routes
        k_paths = engine.k_shortest_paths(
            request.source.lat, request.source.lng,
            request.destination.lat, request.destination.lng,
            k=5, departure_hour=hour, departure_day=day,
        )

        if not k_paths:
            return RouteError.not_found()

        # Score & Rank (with mode preferences)
        ranked = score_and_rank_routes(
            k_paths,
            departure_hour=hour,
            departure_day=day,
            mode_preferences=request.mode_preferences,
        )

        return {"routes": ranked}

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Routing error: {str(e)}")
