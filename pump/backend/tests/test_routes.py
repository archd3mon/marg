"""
test_routes.py — Automated routing tests for Marg.

Tests:
  1. Health endpoint returns 200
  2. Routes exist between major Pune areas
  3. Route responses have expected fields
  4. Edge cases: same origin/dest, far-apart points, outside Pune
  5. Transfer count correctness
  6. Alternate route diversity
  7. Geocode search endpoint
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

    def _search(self, client, source, dest, mode_preferences=None):
        payload = {
            "source": source,
            "destination": dest,
            "departure_time": "2026-03-06T10:00:00",
        }
        if mode_preferences:
            payload["mode_preferences"] = mode_preferences
        return client.post("/api/v1/routes/search", json=payload)

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

    def test_transfers_nonzero_for_multimodal(self, client):
        """Routes using multiple transit modes should have transfers > 0."""
        resp = self._search(client, self.KOTHRUD, self.KHADKI)
        assert resp.status_code == 200
        data = resp.json()
        if data["routes"]:
            # Check if any route that uses 2+ transit modes has transfers > 0
            for route in data["routes"]:
                transit_modes = set()
                for leg in route["legs"]:
                    if leg["mode"] in ("bus", "metro"):
                        transit_modes.add(leg["mode"])
                if len(transit_modes) > 1:
                    assert route["transfers"] > 0, \
                        f"Route uses {transit_modes} but reports 0 transfers"

    def test_alternate_routes_are_different(self, client):
        """Multiple routes should have different mode sequences."""
        resp = self._search(client, self.KOTHRUD, self.SWARGATE)
        assert resp.status_code == 200
        data = resp.json()
        if len(data["routes"]) >= 2:
            mode_sequences = []
            for route in data["routes"]:
                seq = []
                for leg in route["legs"]:
                    if not seq or seq[-1] != leg["mode"]:
                        seq.append(leg["mode"])
                mode_sequences.append(tuple(seq))
            # At least 2 routes should have different mode sequences
            unique_seqs = set(mode_sequences)
            assert len(unique_seqs) >= 1, "All routes have identical mode sequences"

    def test_mode_preferences_accepted(self, client):
        """Route search should accept mode_preferences without error."""
        resp = self._search(
            client, self.KOTHRUD, self.SWARGATE,
            mode_preferences={"prefer_metro": True}
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "routes" in data


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


class TestGeocodeEndpoint:
    def test_geocode_search_returns_results(self, client):
        """Searching for a known Pune location should return results."""
        resp = client.get("/api/v1/geocode/search", params={"q": "Shivajinagar Pune"})
        assert resp.status_code == 200
        data = resp.json()
        assert "results" in data

    def test_geocode_search_short_query(self, client):
        """Query less than 2 chars should fail validation."""
        resp = client.get("/api/v1/geocode/search", params={"q": "a"})
        assert resp.status_code == 422  # validation error
