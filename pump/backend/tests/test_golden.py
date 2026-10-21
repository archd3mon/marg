"""test_golden.py — Regression baseline test for Marg routing engine.

Re-runs fixed origin/destination queries in-process and compares to backend/tests/golden/baseline.json.
Tolerances:
- route ids equal
- arrival time +- 0 min (duration minutes match exactly)
- transfers equal
- walk distance +- 1 m

Run with:
    pytest -m golden
"""
import json
from pathlib import Path
import pytest

# Load baseline JSON once at import time
BASELINE_PATH = Path(__file__).resolve().parent / "golden" / "baseline.json"

if BASELINE_PATH.exists():
    with open(BASELINE_PATH, "r", encoding="utf-8") as f:
        _BASELINE_DATA = json.load(f)
    GOLDEN_CASES = _BASELINE_DATA.get("cases", [])
else:
    GOLDEN_CASES = []


@pytest.fixture(scope="session")
def in_process_engine():
    """Ensure the routing engine, ML predictor, and search engine are booted in-process."""
    from app.network.graph import engine
    from app.ml.inference import predictor
    from app.search.search import search_engine
    import app.main as app_main

    # Disable external HTTP OSRM enhancement so comparison is 100% deterministic and offline
    app_main._enhance_walk_paths = lambda routes: None

    engine.load()
    predictor.load()
    search_engine.load()

    return engine


@pytest.mark.golden
@pytest.mark.parametrize("case", GOLDEN_CASES, ids=[c["case_id"] for c in GOLDEN_CASES])
def test_golden_route_regression(in_process_engine, case):
    """Verify in-process route query matches baseline within strict tolerances."""
    from app.main import search_routes, RouteRequest, Point

    req = RouteRequest(
        source=Point(lat=case["source"]["lat"], lng=case["source"]["lng"]),
        destination=Point(lat=case["destination"]["lat"], lng=case["destination"]["lng"]),
        departure_time=case["departure_time"],
        mode_preferences=case.get("mode_preferences"),
    )

    actual_res = search_routes(req)
    actual_routes = actual_res.get("routes", [])
    expected_routes = case["response"].get("routes", [])

    assert len(actual_routes) == len(expected_routes), (
        f"Route count mismatch for {case['case_id']}: "
        f"got {len(actual_routes)}, expected {len(expected_routes)}"
    )

    for i, (act, exp) in enumerate(zip(actual_routes, expected_routes)):
        # 1. Route IDs equal
        assert act.get("route_id") == exp.get("route_id"), (
            f"[{case['case_id']} - Route {i}] route_id mismatch: "
            f"got {act.get('route_id')}, expected {exp.get('route_id')}"
        )

        # 2. Arrival time +-0 min (exact match on total_time_mins given identical departure)
        assert act.get("total_time_mins") == exp.get("total_time_mins"), (
            f"[{case['case_id']} - Route {i}] arrival duration mismatch: "
            f"got {act.get('total_time_mins')} min, expected {exp.get('total_time_mins')} min"
        )

        # 3. Transfers equal
        assert act.get("transfers") == exp.get("transfers"), (
            f"[{case['case_id']} - Route {i}] transfers mismatch: "
            f"got {act.get('transfers')}, expected {exp.get('transfers')}"
        )

        # 4. Walk distance +-1 m
        act_walk = act.get("total_walk_m", 0)
        exp_walk = exp.get("total_walk_m", 0)
        assert abs(act_walk - exp_walk) <= 1, (
            f"[{case['case_id']} - Route {i}] walk distance mismatch: "
            f"got {act_walk}m, expected {exp_walk}m (tolerance +-1m)"
        )
