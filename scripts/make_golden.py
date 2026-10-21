#!/usr/bin/env python3
"""scripts/make_golden.py — Generate in-process golden baseline routes for Marg.

Runs the current routing engine in-process (no HTTP, no external network)
on 26 fixed origin/destination pairs across 3 departure times on a weekday (08:30, 13:00, 18:30).
Saves complete responses to backend/tests/golden/baseline.json with the engine git SHA.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

# Setup paths
REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = REPO_ROOT / "pump" / "backend"
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# Fixed OD Pairs covering all requested test scenarios
PAIRS = [
    # 1. Short walk-only (~400m)
    {
        "id": "short_walk_deccan_fc_road",
        "category": "short walk-only",
        "name": "Deccan Gymkhana to FC Road",
        "source": {"lat": 18.5173, "lng": 73.8415},
        "destination": {"lat": 18.5204, "lng": 73.8436},
        "mode_preferences": None,
    },
    # 2. Bus-only
    {
        "id": "bus_only_katraj_swargate",
        "category": "bus-only",
        "name": "Katraj Bus Stand to Swargate",
        "source": {"lat": 18.4575, "lng": 73.8677},
        "destination": {"lat": 18.5015, "lng": 73.8565},
        "mode_preferences": {"prefer_bus": True, "exclude_metro": True},
    },
    {
        "id": "bus_only_swargate_hadapsar",
        "category": "bus-only",
        "name": "Swargate to Hadapsar Gadital",
        "source": {"lat": 18.5015, "lng": 73.8565},
        "destination": {"lat": 18.5018, "lng": 73.9268},
        "mode_preferences": {"prefer_bus": True, "exclude_metro": True},
    },
    # 3. Metro-only
    {
        "id": "metro_only_pcmc_civil_court",
        "category": "metro-only",
        "name": "PCMC to Civil Court (Purple Line)",
        "source": {"lat": 18.6298, "lng": 73.8131},
        "destination": {"lat": 18.5286, "lng": 73.8467},
        "mode_preferences": {"prefer_metro": True},
    },
    {
        "id": "metro_only_vanaz_garware",
        "category": "metro-only",
        "name": "Vanaz to Garware College (Aqua Line)",
        "source": {"lat": 18.5074, "lng": 73.8077},
        "destination": {"lat": 18.5146, "lng": 73.8344},
        "mode_preferences": {"prefer_metro": True},
    },
    # 4. Metro + Bus
    {
        "id": "metro_bus_vanaz_pune_station",
        "category": "metro+bus",
        "name": "Vanaz (Kothrud) to Pune Railway Station",
        "source": {"lat": 18.5074, "lng": 73.8077},
        "destination": {"lat": 18.5289, "lng": 73.8744},
        "mode_preferences": None,
    },
    {
        "id": "metro_bus_pcmc_swargate",
        "category": "metro+bus",
        "name": "PCMC to Swargate",
        "source": {"lat": 18.6298, "lng": 73.8131},
        "destination": {"lat": 18.5015, "lng": 73.8565},
        "mode_preferences": None,
    },
    # 5. Far from transit
    {
        "id": "far_from_transit_mulshi_fringe",
        "category": "far-from-transit",
        "name": "Remote West Mulshi Fringe",
        "source": {"lat": 18.4100, "lng": 73.6500},
        "destination": {"lat": 18.4300, "lng": 73.6800},
        "mode_preferences": None,
    },
    {
        "id": "far_from_transit_east_fringe",
        "category": "far-from-transit",
        "name": "Remote East Wagholi Fringe",
        "source": {"lat": 18.6500, "lng": 74.0500},
        "destination": {"lat": 18.6700, "lng": 74.0800},
        "mode_preferences": None,
    },
    # 6. Same point
    {
        "id": "same_point_swargate",
        "category": "same-point",
        "name": "Swargate to Swargate",
        "source": {"lat": 18.5015, "lng": 73.8565},
        "destination": {"lat": 18.5015, "lng": 73.8565},
        "mode_preferences": None,
    },
    {
        "id": "same_point_shivajinagar",
        "category": "same-point",
        "name": "Shivajinagar to Shivajinagar",
        "source": {"lat": 18.5325, "lng": 73.8495},
        "destination": {"lat": 18.5325, "lng": 73.8495},
        "mode_preferences": None,
    },
    # 7. Cross-city
    {
        "id": "cross_city_nigdi_hadapsar",
        "category": "cross-city",
        "name": "Nigdi to Hadapsar",
        "source": {"lat": 18.6515, "lng": 73.7708},
        "destination": {"lat": 18.5018, "lng": 73.9268},
        "mode_preferences": None,
    },
    {
        "id": "cross_city_katraj_hinjewadi_ph3",
        "category": "cross-city",
        "name": "Katraj to Hinjewadi Phase 3",
        "source": {"lat": 18.4575, "lng": 73.8677},
        "destination": {"lat": 18.5802, "lng": 73.6872},
        "mode_preferences": None,
    },
    # 8. Airport
    {
        "id": "airport_pune_station",
        "category": "airport",
        "name": "Pune Airport to Pune Railway Station",
        "source": {"lat": 18.5822, "lng": 73.9197},
        "destination": {"lat": 18.5289, "lng": 73.8744},
        "mode_preferences": None,
    },
    {
        "id": "airport_kothrud",
        "category": "airport",
        "name": "Pune Airport to Kothrud Stand",
        "source": {"lat": 18.5822, "lng": 73.9197},
        "destination": {"lat": 18.5074, "lng": 73.8077},
        "mode_preferences": None,
    },
    {
        "id": "airport_hinjewadi_ph1",
        "category": "airport",
        "name": "Pune Airport to Hinjewadi Phase 1",
        "source": {"lat": 18.5822, "lng": 73.9197},
        "destination": {"lat": 18.5913, "lng": 73.7389},
        "mode_preferences": None,
    },
    # 9. Railway station
    {
        "id": "railway_station_shivajinagar",
        "category": "railway station",
        "name": "Pune Railway Station to Shivajinagar",
        "source": {"lat": 18.5289, "lng": 73.8744},
        "destination": {"lat": 18.5325, "lng": 73.8495},
        "mode_preferences": None,
    },
    {
        "id": "railway_station_hadapsar",
        "category": "railway station",
        "name": "Pune Railway Station to Hadapsar",
        "source": {"lat": 18.5289, "lng": 73.8744},
        "destination": {"lat": 18.5018, "lng": 73.9268},
        "mode_preferences": None,
    },
    # 10. Hinjewadi
    {
        "id": "hinjewadi_shivajinagar",
        "category": "Hinjewadi",
        "name": "Hinjewadi Phase 1 to Shivajinagar",
        "source": {"lat": 18.5913, "lng": 73.7389},
        "destination": {"lat": 18.5325, "lng": 73.8495},
        "mode_preferences": None,
    },
    {
        "id": "hinjewadi_deccan",
        "category": "Hinjewadi",
        "name": "Hinjewadi Phase 2 to Deccan Gymkhana",
        "source": {"lat": 18.5947, "lng": 73.7198},
        "destination": {"lat": 18.5173, "lng": 73.8415},
        "mode_preferences": None,
    },
    # 11. Katraj
    {
        "id": "katraj_shivajinagar",
        "category": "Katraj",
        "name": "Katraj Snake Park to Shivajinagar",
        "source": {"lat": 18.4575, "lng": 73.8677},
        "destination": {"lat": 18.5325, "lng": 73.8495},
        "mode_preferences": None,
    },
    {
        "id": "katraj_kothrud",
        "category": "Katraj",
        "name": "Katraj to Kothrud Stand",
        "source": {"lat": 18.4575, "lng": 73.8677},
        "destination": {"lat": 18.5074, "lng": 73.8077},
        "mode_preferences": None,
    },
    # 12. Kothrud
    {
        "id": "kothrud_shivajinagar",
        "category": "Kothrud",
        "name": "Kothrud Stand to Shivajinagar",
        "source": {"lat": 18.5074, "lng": 73.8077},
        "destination": {"lat": 18.5325, "lng": 73.8495},
        "mode_preferences": None,
    },
    {
        "id": "kothrud_swargate",
        "category": "Kothrud",
        "name": "Kothrud to Swargate",
        "source": {"lat": 18.5074, "lng": 73.8077},
        "destination": {"lat": 18.5015, "lng": 73.8565},
        "mode_preferences": None,
    },
    # 13. Shivajinagar
    {
        "id": "shivajinagar_swargate",
        "category": "Shivajinagar",
        "name": "Shivajinagar to Swargate",
        "source": {"lat": 18.5325, "lng": 73.8495},
        "destination": {"lat": 18.5015, "lng": 73.8565},
        "mode_preferences": None,
    },
    {
        "id": "shivajinagar_aundh",
        "category": "Shivajinagar",
        "name": "Shivajinagar to Aundh Parihar Chowk",
        "source": {"lat": 18.5325, "lng": 73.8495},
        "destination": {"lat": 18.5606, "lng": 73.8074},
        "mode_preferences": None,
    },
]

DEPARTURE_TIMES = [
    "2026-10-21T08:30:00",  # Weekday Morning Peak
    "2026-10-21T13:00:00",  # Weekday Afternoon Off-Peak
    "2026-10-21T18:30:00",  # Weekday Evening Peak
]


def get_git_sha():
    try:
        out = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO_ROOT).decode().strip()
        return out
    except Exception:
        return "unknown"


def generate_golden(output_path: Path):
    print(f"Booting Marg routing engine in-process (no HTTP)...")
    from app.network.graph import engine
    from app.ml.inference import predictor
    from app.search.search import search_engine
    import app.main as app_main
    from app.main import search_routes, RouteRequest, Point

    # Ensure no external HTTP requests by disabling public OSRM walker
    app_main._enhance_walk_paths = lambda routes: None

    engine.load()
    predictor.load()
    search_engine.load()

    git_sha = get_git_sha()
    print(f"Engine loaded. Git SHA: {git_sha}")

    golden_cases = []
    total = len(PAIRS) * len(DEPARTURE_TIMES)
    idx = 0

    t_start = time.time()
    for pair in PAIRS:
        for dep_time in DEPARTURE_TIMES:
            idx += 1
            time_label = dep_time.split("T")[1][:5].replace(":", "")
            case_id = f"{pair['id']}_{time_label}"

            req = RouteRequest(
                source=Point(lat=pair["source"]["lat"], lng=pair["source"]["lng"]),
                destination=Point(lat=pair["destination"]["lat"], lng=pair["destination"]["lng"]),
                departure_time=dep_time,
                mode_preferences=pair.get("mode_preferences"),
            )

            res = search_routes(req)

            # Extract compact metric summary for fast inspection
            summary = []
            for r in res.get("routes", []):
                summary.append({
                    "route_id": r.get("route_id"),
                    "total_time_mins": r.get("total_time_mins"),
                    "transfers": r.get("transfers"),
                    "total_walk_m": r.get("total_walk_m"),
                    "uses_metro": r.get("uses_metro"),
                    "route_type": r.get("route_type"),
                })

            golden_cases.append({
                "case_id": case_id,
                "category": pair["category"],
                "name": pair["name"],
                "source": pair["source"],
                "destination": pair["destination"],
                "departure_time": dep_time,
                "mode_preferences": pair.get("mode_preferences"),
                "summary": summary,
                "response": res,
            })

            if idx % 10 == 0 or idx == total:
                print(f"[{idx}/{total}] Processed {case_id} ({len(res.get('routes', []))} routes found)")

    elapsed = round(time.time() - t_start, 2)
    print(f"Computed {total} cases in {elapsed}s.")

    output_payload = {
        "engine_git_sha": git_sha,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "departure_times": DEPARTURE_TIMES,
        "total_pairs": len(PAIRS),
        "total_cases": len(golden_cases),
        "cases": golden_cases,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output_payload, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Saved full JSON baseline to: {output_path}")


if __name__ == "__main__":
    out_file = BACKEND_DIR / "tests" / "golden" / "baseline.json"
    generate_golden(out_file)
