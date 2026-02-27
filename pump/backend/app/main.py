from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import json
from pathlib import Path

from app.network.graph import engine
from app.ml.inference import predictor
from app.scoring.ranker import score_and_rank_routes

app = FastAPI(title="Pune Urban Mobility Planner - Marg")

# Enable CORS for React frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

import os
from pathlib import Path

# Get top level dir or use default
DEFAULT_DATA_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/processed")
DATA_DIR_ENV = os.getenv("PUMP_DATA_DIR")
DATA_DIR = Path(DATA_DIR_ENV) if DATA_DIR_ENV else DEFAULT_DATA_DIR

# Schemas
class Point(BaseModel):
    lat: float
    lng: float

class RouteRequest(BaseModel):
    source: Point
    destination: Point
    departure_time: str # "YYYY-MM-DDTHH:MM:SS"

@app.on_event("startup")
def startup_event():
    print("Initializing Core Engines...")
    engine.load()
    predictor.load()

@app.get("/api/v1/health")
def health_check():
    return {
        "status": "ok",
        "graph_nodes": len(engine.G.nodes) if engine.G else 0,
        "ml_loaded": predictor.model is not None
    }

@app.get("/api/v1/network/stops")
def get_stops():
    """Returns a lightweight list of stops for the frontend map."""
    stops = []
    
    # Load raw JSONs directly to avoid large graph serialization
    if (DATA_DIR / "metro_stations.json").exists():
        with open(DATA_DIR / "metro_stations.json") as f:
            stops.extend(json.load(f))
            
    if (DATA_DIR / "bus_stops.json").exists():
        with open(DATA_DIR / "bus_stops.json") as f:
            # We take a sample of bus stops to not crash the UI (there are 5000+)
            all_buses = json.load(f)
            stops.extend(all_buses[:500]) # Take top 500 for visualization 
            
    return {"stops": stops}

@app.post("/api/v1/routes/search")
def search_routes(request: RouteRequest):
    try:
        # Extract hour and day from ISO string (e.g. 2026-02-23T18:30:00)
        # Fallbacks to 10 AM Monday
        try:
            from datetime import datetime
            dt = datetime.fromisoformat(request.departure_time.replace('Z', '+00:00'))
            hour = dt.hour
            day = dt.weekday()
        except:
            hour = 10
            day = 0
            
        # 1. Path Generation (Top 5 dynamically shortest based on time of day)
        k_paths = engine.k_shortest_paths(
            request.source.lat, request.source.lng,
            request.destination.lat, request.destination.lng,
            k=5, departure_hour=hour, departure_day=day
        )
        
        if not k_paths:
            return {"routes": []}
            
        # 2. Score & Rank (ML Travel time + Penalty heuristics)
        ranked = score_and_rank_routes(k_paths, departure_hour=hour, departure_day=day)
        
        return {"routes": ranked}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
