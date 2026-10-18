#!/usr/bin/env python3
"""Boot the real backend in-process and save trimmed REAL responses as Flutter test fixtures.

    cd pump/backend && python scripts/capture_fixtures.py ../mobile/test/fixtures/real

Re-run whenever the API changes; commit the diff so contract drift is visible in review.
"""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from fastapi.testclient import TestClient  # noqa: E402
from app.main import app  # noqa: E402

out = sys.argv[1] if len(sys.argv) > 1 else "fixtures_out"
os.makedirs(out, exist_ok=True)


def write(name, data):
    with open(os.path.join(out, name), "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("wrote", name)


def trim_route(r):
    r = json.loads(json.dumps(r))
    r.pop("segments", None)
    for leg in r["legs"]:
        leg["path"] = leg["path"][:3]
        for k in ("route_ids", "travel_time", "duration_sec"):
            leg.pop(k, None)
    return r


with TestClient(app) as c:
    write("health.json", c.get("/api/v1/health").json())
    stops = c.get("/api/v1/network/stops/nearby", params={"lat": 18.5074, "lng": 73.8077, "radius_m": 1200, "limit": 5, "include_metro": True}).json()
    write("stops_nearby.json", stops)
    allstops = c.get("/api/v1/network/stops").json()["stops"]
    bus = [s for s in allstops if s["type"] == "bus_stop"][:3]
    metro = [s for s in allstops if s["type"] == "metro_station"][:2]
    write("stops.json", {"stops": bus + metro})
    write("geocode_search.json", {"results": c.get("/api/v1/geocode/search", params={"q": "Kothrud", "limit": 3}).json()["results"]})
    body = {"source": {"lat": 18.5074, "lng": 73.8077}, "destination": {"lat": 18.5679, "lng": 73.9143},
            "departure_time": "2026-10-19T08:42:00+05:30", "mode_preferences": {"prefer_bus": True, "exclude_metro": True}}
    d = c.post("/api/v1/routes/search", json=body).json()
    d["routes"] = [trim_route(r) for r in d["routes"][:3]]
    write("routes_search_bus_only.json", d)
    body["mode_preferences"] = {"prefer_bus": True}
    d = c.post("/api/v1/routes/search", json=body).json()
    d["routes"] = [trim_route(r) for r in d["routes"][:2]]
    write("routes_search_with_metro.json", d)
    write("routes_empty.json", {"routes": [], "message": "Origin or destination is too far from the transit network.", "warnings": []})
