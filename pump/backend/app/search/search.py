import json
import os
from pathlib import Path
from rapidfuzz import process, fuzz

DATA_DIR = Path(os.getenv("PUMP_DATA_DIR", "/home/jayant/gitgud/marg/marg/pump/data/processed"))

# Hardcoded popular Pune aliases / landmarks that Nominatim struggles with
LOCAL_LANDMARKS = [
    {
        "name": "SIT Pune",
        "display_name": "Symbiosis Institute of Technology, Lavale",
        "lat": 18.5362,
        "lon": 73.7271,
        "type": "landmark"
    },
    {
        "name": "Dagduseth",
        "display_name": "Shreemant Dagdusheth Halwai Ganpati Mandir",
        "lat": 18.5171,
        "lon": 73.8553,
        "type": "landmark"
    },
    {
        "name": "FC Road",
        "display_name": "Fergusson College Road",
        "lat": 18.5226,
        "lon": 73.8427,
        "type": "landmark"
    },
    {
        "name": "Vetal Tekdi",
        "display_name": "Vetal Tekdi (MIT / Hanuman / Pashan Tekdi)",
        "lat": 18.5268,
        "lon": 73.8222,
        "type": "landmark"
    },
    {
        "name": "Lal Deval",
        "display_name": "David Synagogue (Lal Deval)",
        "lat": 18.5147,
        "lon": 73.8766,
        "type": "landmark"
    },
    {
        "name": "Nava Pul",
        "display_name": "Shivaji Bridge (Nava Pul)",
        "lat": 18.5250,
        "lon": 73.8540,
        "type": "landmark"
    },
    {
        "name": "Sinhagad Fort",
        "display_name": "Sinhagad Fort (Lion's Fort)",
        "lat": 18.3663,
        "lon": 73.7559,
        "type": "landmark"
    },
    {
        "name": "Pune Station",
        "display_name": "Pune Railway Station",
        "lat": 18.5290,
        "lon": 73.8755,
        "type": "landmark"
    }
]

class LocalSearchEngine:
    def __init__(self):
        self.points = []
        self.names = []

    def load(self):
        print("Loading Local Search Engine...")
        self.points = list(LOCAL_LANDMARKS)
        
        bus_file = DATA_DIR / "bus_stops.json"
        metro_file = DATA_DIR / "metro_stations.json"

        if bus_file.exists():
            with open(bus_file, "r") as f:
                bus_stops = json.load(f)
                for s in bus_stops:
                    self.points.append({
                        "name": s["name"],
                        "display_name": f"{s['name']} (Bus Stop)",
                        "lat": s["lat"],
                        "lon": s["lon"],
                        "type": "bus_stop"
                    })
                    
        if metro_file.exists():
            with open(metro_file, "r") as f:
                metro_stops = json.load(f)
                for s in metro_stops:
                    self.points.append({
                        "name": s["name"],
                        "display_name": f"{s['name']} Metro Station",
                        "lat": s["lat"],
                        "lon": s["lon"],
                        "type": "metro_station"
                    })

        self.names = [p["name"] for p in self.points]
        print(f"Loaded {len(self.points)} searchable points.")

    def search(self, query, limit=5, threshold=65):
        if not self.points:
            return []
            
        # Use WRatio which handles partial matches and different orderings well
        results = process.extract(
            query,
            self.names,
            scorer=fuzz.WRatio,
            limit=limit
        )

        matches = []
        # rapidfuzz extract returns tuples of (match, score, index)
        for name, score, idx in results:
            if score >= threshold:
                point = self.points[idx]
                matches.append({
                    "name": point["name"],
                    "display_name": point["display_name"],
                    "lat": point["lat"],
                    "lon": point["lon"],
                    "score": score
                })
                
        return matches

# Singleton
search_engine = LocalSearchEngine()
