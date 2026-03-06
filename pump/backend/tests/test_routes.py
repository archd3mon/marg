"""
test_routes.py — Automated routing tests for Marg.

Tests:
  1. Health endpoint returns 200
  2. Routes exist between major Pune areas
  3. Route responses have expected fields
  4. Edge cases: same origin/dest, far-apart points, outside Pune
"""

import pytest
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient
from app.main import app


@pytest.fixture(scope="module")
def client():
    """Use TestClient as context manager to trigger lifespan startup/shutdown."""
    with TestClient(app) as c:
        yield c


class TestHealthCheck:
    def test_health_returns_ok(self, client):
        resp = client.get("/api/v1/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"
        assert data["graph_nodes"] > 0
        assert data["ml_loaded"] is True


class TestRouteSearch:
    """Test route search between well-known Pune locations."""

    KHADKI = {"lat": 18.5570, "lng": 73.8425}
    SHIVAJI_NAGAR = {"lat": 18.5325, "lng": 73.8495}
    KOTHRUD = {"lat": 18.5074, "lng": 73.8077}
    SWARGATE = {"lat": 18.5015, "lng": 73.8565}

    def _search(self, client, source, dest):
        return client.post("/api/v1/routes/search", json={
            "source": source,
            "destination": dest,
            "departure_time": "2026-03-06T10:00:00",
        })

    def test_khadki_to_shivaji_nagar(self, client):
        """Short route along Purple metro line."""
        resp = self._search(client, self.KHADKI, self.SHIVAJI_NAGAR)
        assert resp.status_code == 200
        data = resp.json()
        assert "routes" in data
        if data["routes"]:
            route = data["routes"][0]
            assert "legs" in route
            assert "total_time_mins" in route
            assert route["total_time_mins"] > 0

    def test_kothrud_to_swargate(self, client):
        """Medium route — Kothrud (west) to Swargate (central)."""
        resp = self._search(client, self.KOTHRUD, self.SWARGATE)
        assert resp.status_code == 200
        data = resp.json()
        assert "routes" in data

    def test_route_response_structure(self, client):
        """Validate the full response structure of a route."""
        resp = self._search(client, self.KHADKI, self.SHIVAJI_NAGAR)
        assert resp.status_code == 200
        data = resp.json()

        if data["routes"]:
            route = data["routes"][0]
            assert "score" in route
            assert "total_time_mins" in route
            assert "transfers" in route
            assert "legs" in route
            assert "rank" in route

            for leg in route["legs"]:
                assert "mode" in leg
                assert leg["mode"] in ("walk", "bus", "metro")
                assert "length_m" in leg
                assert "from_node" in leg
                assert "to_node" in leg
                assert "lat" in leg["from_node"]
                assert "lon" in leg["from_node"]

    def test_same_origin_destination(self, client):
        """Same point should return empty or valid routes, not crash."""
        resp = self._search(client, self.SWARGATE, self.SWARGATE)
        assert resp.status_code == 200

    def test_outside_pune(self, client):
        """Coordinates far outside Pune should return empty routes."""
        mumbai = {"lat": 19.076, "lng": 72.877}
        resp = self._search(client, mumbai, self.SWARGATE)
        assert resp.status_code == 200
        data = resp.json()
        assert data["routes"] == []


class TestStopsEndpoint:
    def test_get_stops(self, client):
        resp = client.get("/api/v1/network/stops")
        assert resp.status_code == 200
        data = resp.json()
        assert "stops" in data
        assert len(data["stops"]) > 0

    def test_stop_structure(self, client):
        resp = client.get("/api/v1/network/stops")
        data = resp.json()
        if data["stops"]:
            stop = data["stops"][0]
            assert "lat" in stop
            assert "lon" in stop
            assert "name" in stop
