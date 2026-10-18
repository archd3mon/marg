"""Contract tests: the exact response shapes the Flutter app (and React app) depend on.

If one of these fails, a client will break, so fix the backend or update
docs/API_CONTRACT.md and the client in the same change.
"""
import math

import pytest

KOTHRUD = {"lat": 18.5074, "lng": 73.8077}
VIMAN_NAGAR = {"lat": 18.5679, "lng": 73.9143}
SWARGATE = {"lat": 18.5018, "lng": 73.8586}
DEPART = "2026-10-19T08:42:00+05:30"
ROUTE_TYPES = {"recommended", "fastest", "least_transfers", "least_walking", "alternative"}
MODES = {"walk", "bus", "metro"}


def _search(client, src=KOTHRUD, dst=VIMAN_NAGAR, prefs=None, depart=DEPART):
    body = {"source": src, "destination": dst}
    if depart:
        body["departure_time"] = depart
    if prefs is not None:
        body["mode_preferences"] = prefs
    return client.post("/api/v1/routes/search", json=body)


def _is_num(x):
    return isinstance(x, (int, float)) and not isinstance(x, bool) and math.isfinite(x)


# ───────────────────────── health ─────────────────────────
def test_health_shape(client):
    r = client.get("/api/v1/health")
    assert r.status_code == 200
    d = r.json()
    assert d["status"] in {"ok", "degraded"}
    assert d["routing_available"] is True
    for comp in ("graph", "kdtree", "ml_model", "search"):
        assert d["components"][comp]["status"] == "ok", comp


# ───────────────────────── stops ─────────────────────────
def test_stops_shape(client):
    stops = client.get("/api/v1/network/stops").json()["stops"]
    assert stops
    types = {s["type"] for s in stops}
    assert "bus_stop" in types, "clients map bus_stop -> bus; if this key changes update TransitStop.fromJson"
    assert types <= {"bus_stop", "metro_station"}
    for s in stops[:50]:
        assert s["id"] and s["name"]
        assert _is_num(s["lat"]) and _is_num(s["lon"])


def test_nearby_stops_sorted_and_bounded(client):
    r = client.get("/api/v1/network/stops/nearby", params={**KOTHRUD, "radius_m": 1500, "limit": 20})
    assert r.status_code == 200
    stops = r.json()["stops"]
    assert 0 < len(stops) <= 20
    d = [s["distance_meters"] for s in stops]
    assert d == sorted(d)
    assert max(d) <= 1500
    assert all(s["type"] == "bus_stop" for s in stops)


def test_nearby_stops_include_metro_flag(client):
    # Civil Court metro station area
    r = client.get("/api/v1/network/stops/nearby", params={"lat": 18.5286, "lng": 73.8467, "radius_m": 1500, "include_metro": True})
    assert any(s["type"] == "metro_station" for s in r.json()["stops"])


def test_nearby_stops_validation(client):
    assert client.get("/api/v1/network/stops/nearby").status_code == 422
    assert client.get("/api/v1/network/stops/nearby", params={"lat": 999, "lng": 0}).status_code == 422


def test_nearby_stops_empty_far_away(client):
    r = client.get("/api/v1/network/stops/nearby", params={"lat": 0, "lng": 0})
    assert r.status_code == 200 and r.json()["stops"] == []


# ───────────────────────── geocode ─────────────────────────
def test_geocode_is_wrapped_in_results(client):
    d = client.get("/api/v1/geocode/search", params={"q": "Kothrud", "limit": 8}).json()
    assert isinstance(d, dict) and isinstance(d["results"], list), "must be {results: [...]}, not a bare list"
    assert d["results"]
    for p in d["results"]:
        assert p["name"] and p["display_name"]
        assert _is_num(float(p["lat"])) and _is_num(float(p["lon"]))


def test_geocode_min_length(client):
    assert client.get("/api/v1/geocode/search", params={"q": "k"}).status_code == 422


# ───────────────────────── routes ─────────────────────────
@pytest.fixture(scope="module")
def routes_payload(client):
    r = _search(client)
    assert r.status_code == 200, r.text
    return r.json()


def test_route_top_level(routes_payload):
    assert set(routes_payload) >= {"routes", "warnings", "departure_time_used"}
    assert routes_payload["routes"]
    assert routes_payload["departure_time_used"].startswith("2026-10-19T08:42")
    assert isinstance(routes_payload["warnings"], list)


def test_every_route_has_required_fields(routes_payload):
    ids = []
    for r in routes_payload["routes"]:
        ids.append(r["route_id"])
        assert r["route_id"]
        assert _is_num(r["score"])
        assert isinstance(r["total_time_mins"], int) and r["total_time_mins"] > 0
        assert isinstance(r["transfers"], int) and r["transfers"] >= 0
        assert _is_num(r["total_walk_m"])
        assert isinstance(r["uses_metro"], bool)
        assert r["route_type"] in ROUTE_TYPES
        assert r["legs"]
    assert len(ids) == len(set(ids)), "route_id must be unique within a response"
    assert routes_payload["routes"][0]["route_type"] == "recommended"


def test_every_leg_has_required_fields(routes_payload):
    for r in routes_payload["routes"]:
        for leg in r["legs"]:
            assert leg["mode"] in MODES
            for end in ("from_node", "to_node"):
                assert _is_num(leg[end]["lat"]) and _is_num(leg[end]["lon"])
            assert _is_num(leg["length_m"]) and leg["length_m"] >= 0
            assert isinstance(leg["duration_mins"], int) and leg["duration_mins"] >= 0
            assert isinstance(leg["line_options"], list)


def test_bus_legs_have_a_line_label(routes_payload):
    bus = [l for r in routes_payload["routes"] for l in r["legs"] if l["mode"] == "bus"]
    assert bus, "fixture trip should include at least one bus leg"
    assert all(l["line"] for l in bus), "bus leg without a line shows an empty chip in the app"


def test_route_geometry_present_for_map(routes_payload):
    for r in routes_payload["routes"]:
        for leg in r["legs"]:
            assert len(leg["path"]) >= 2, "polyline needs >= 2 points"
            assert all(len(pt) == 2 for pt in leg["path"])


def test_exclude_metro_filters_every_metro_route(client):
    d = _search(client, prefs={"prefer_bus": True, "exclude_metro": True}).json()
    for r in d["routes"]:
        assert r["uses_metro"] is False
        assert all(l["mode"] != "metro" for l in r["legs"])
    if d["routes"]:
        assert d["routes"][0]["route_type"] == "recommended"
    else:
        assert d["message"]


@pytest.mark.parametrize("prefs", [None, {}, {"prefer_bus": True}, {"prefer_bus": True, "less_walking": True}, {"prefer_metro": True}])
def test_mode_preferences_accepted(client, prefs):
    assert _search(client, prefs=prefs).status_code == 200


def test_less_walking_changes_ranking_inputs(client):
    base = _search(client, prefs={"prefer_bus": True}).json()["routes"]
    less = _search(client, prefs={"prefer_bus": True, "less_walking": True}).json()["routes"]
    assert min(r["total_walk_m"] for r in less) <= min(r["total_walk_m"] for r in base) + 1


def test_departure_time_optional(client):
    r = _search(client, depart=None)
    assert r.status_code == 200 and r.json()["departure_time_used"]


def test_departure_time_garbage_falls_back(client):
    assert _search(client, depart="not-a-date").status_code == 200


def test_invalid_payload_is_422(client):
    assert client.post("/api/v1/routes/search", json={"source": {"lat": 1}}).status_code == 422
    assert client.post("/api/v1/routes/search", json={}).status_code == 422


def test_same_origin_and_destination_does_not_crash(client):
    assert _search(client, src=SWARGATE, dst=SWARGATE).status_code in (200, 400)


def test_far_outside_pune_is_graceful(client):
    r = _search(client, dst={"lat": 19.5, "lng": 75.5})
    assert r.status_code == 200
    d = r.json()
    assert d["routes"] or d["message"], "client shows an empty state only if one of these is present"


def test_503_when_engine_unavailable(client, monkeypatch):
    from app.network.graph import engine
    monkeypatch.setattr(engine, "routing_available", False)
    assert _search(client).status_code == 503


# ───────────────────────── unit: normaliser ─────────────────────────
def test_normalizer_fills_walk_direct_shape():
    from app.main import _normalize_for_clients

    route = {
        "route_id": "walk_direct",
        "legs": [{"mode": "walk", "from_node": {"lat": 1, "lon": 1}, "to_node": {"lat": 1, "lon": 1},
                  "length_m": 1000.0, "travel_time": 720.0, "path": [[1, 1], [1, 1]]}],
        "total_time_mins": 12, "transfers": 0, "score": 12,
    }
    out = _normalize_for_clients([route])[0]
    assert out["route_id"] == "walk_direct"
    assert out["total_walk_m"] == 1000
    assert out["uses_metro"] is False
    assert out["legs"][0]["duration_mins"] == 12


def test_normalizer_assigns_ids_and_lines():
    from app.main import _normalize_for_clients

    leg = {"mode": "bus", "line": "", "route_names": ["95", "79"], "length_m": 100.0, "travel_time": 60.0}
    out = _normalize_for_clients([{"legs": [leg]}, {"legs": [dict(leg)]}])
    assert [r["route_id"] for r in out] == ["route_1", "route_2"]
    assert out[0]["legs"][0]["line"] == "95"
    assert out[0]["legs"][0]["line_options"] == ["95", "79"]


def test_normalizer_adds_straight_line_path_when_missing():
    from app.main import _normalize_for_clients

    leg = {"mode": "walk", "from_node": {"lat": 1.0, "lon": 2.0}, "to_node": {"lat": 3.0, "lon": 4.0}, "length_m": 10.0, "travel_time": 5.0}
    out = _normalize_for_clients([{"legs": [leg]}])[0]["legs"][0]
    assert out["path"] == [[1.0, 2.0], [3.0, 4.0]]
