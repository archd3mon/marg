from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import json
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


# --- Schemas ---
class Point(BaseModel):
    lat: float
    lng: float

class RouteRequest(BaseModel):
    source: Point
    destination: Point
    departure_time: str  # "YYYY-MM-DDTHH:MM:SS"


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

        # Score & Rank
        ranked = score_and_rank_routes(k_paths, departure_hour=hour, departure_day=day)

        return {"routes": ranked}

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Routing error: {str(e)}")
