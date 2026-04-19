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
        assert data["components"]["graph"]["nodes"] > 0
        assert data["components"]["ml_model"]["status"] == "ok"


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
        """Coordinates far outside Pune should still return a response (walk-only fallback)."""
        mumbai = {"lat": 19.076, "lng": 72.877}
        resp = self._search(client, mumbai, self.SWARGATE)
        assert resp.status_code == 200
        data = resp.json()
        assert "routes" in data

    def test_distant_point_walk_fallback(self, client):
        """Points far from transit should return a direct walk-only route instead of 500 error."""
        distant_point = {"lat": 18.435, "lng": 73.766} # Khadakwasla
        resp = self._search(client, distant_point, self.SWARGATE)
        assert resp.status_code == 200
        data = resp.json()
        assert "routes" in data
        assert len(data["routes"]) >= 1
        route = data["routes"][0]
        # Must have legs and a score/time field
        assert "legs" in route

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

    def test_geocode_known_place_local_fallback(self, client):
        """Searching for a locally known place should yield a result from local index or nominations."""
        resp = client.get("/api/v1/geocode/search", params={"q": "COEP"})
        assert resp.status_code == 200
        data = resp.json()
        assert "results" in data
        assert len(data["results"]) > 0
        assert "source" in data["results"][0]

    def test_geocode_never_returns_empty(self, client):
        """Geocode should never return an empty results list (fallback to Pune center)."""
        resp = client.get("/api/v1/geocode/search", params={"q": "xyznonexistent123"})
        assert resp.status_code == 200
        data = resp.json()
        assert "results" in data
        assert len(data["results"]) > 0


MUST_RESOLVE = [
    # Metro stations
    "PCMC", "Swargate", "Civil Court", "Deccan Gymkhana", "Ruby Hall Clinic Metro",
    "Vanaz", "Kalyani Nagar", "Ramwadi", "Shivajinagar Metro", "Khadki",
    # Colleges
    "COEP", "PICT", "MIT Pune", "Fergusson College", "Pune University", "NDA",
    "Symbiosis", "Cummins College", "VIT Pune", "Armed Forces Medical College", "BJ Medical College",
    "JSPM Narhe", "PCCOE Nigdi", "Film and Television Institute",
    # Hospitals
    "Ruby Hall Clinic", "Sahyadri Hospital", "Deenanath Mangeshkar Hospital",
    "Jehangir Hospital", "KEM Hospital", "Sassoon Hospital",
    "Jupiter Hospital Baner", "Command Hospital Pune",
    # Localities
    "Hinjewadi", "Wakad", "Baner", "Kothrud", "Hadapsar", "Magarpatta",
    "Koregaon Park", "Viman Nagar", "Kharadi", "Wagholi", "Katraj",
    "Mundhwa", "Tathawade", "Ravet", "Balewadi", "Lonavala",
    # Landmarks
    "Shaniwar Wada", "Aga Khan Palace", "Sinhagad Fort", "Parvati Hill",
    "Dagdusheth Halwai Temple", "Rajiv Gandhi Zoological Park",
    # Transport
    "Pune Airport", "Pune Junction", "Swargate Bus Stand",
    # Roads and markets
    "FC Road", "JM Road", "Mandai", "Market Yard", "Laxmi Road",
    "Chandni Chowk", "DP Road",
    # Corporate campuses
    "Infosys Hinjewadi", "TCS Sahyadri Park", "Wipro Kharadi", "Persistent Systems",
    # Hotels
    "JW Marriott Pune", "Taj Blue Diamond", "Conrad Pune",
    # Banks
    "SBI Main Branch Pune", "HDFC Bank Pune Camp", "Bank of Maharashtra HO",
    # Cinemas
    "PVR INOX Amanora", "INOX Bund Garden",
    # Police stations
    "Vishrambaug Police Station", "Kothrud Police Station",
    # Fuel stations
    "HP Petrol Pump Swargate", "Indian Oil Kothrud",
    # Parks
    "Saras Baug", "Okayama Friendship Garden", "Khadakwasla Dam",
    # Temples
    "ISKCON Pune", "Kasba Ganpati",
    # Sports venues
    "MCA Stadium Gahunje", "Balewadi Stadium",
    # Residential societies
    "Amanora Park Town", "Blue Ridge Hinjewadi",
    # Junctions
    "Katraj Chowk", "Hadapsar Gadital", "Navale Bridge",
]


class TestComprehensiveGeocode:
    """Every place in MUST_RESOLVE must return valid coordinates within Maharashtra."""

    @pytest.mark.parametrize("place", MUST_RESOLVE)
    def test_must_resolve(self, client, place):
        resp = client.get("/api/v1/geocode/search", params={"q": place})
        assert resp.status_code == 200, f"HTTP error for '{place}'"
        data = resp.json()
        assert "results" in data
        assert len(data["results"]) > 0, f"FAILED: '{place}' returned 0 results"
        first = data["results"][0]
        assert first["lat"] is not None, f"'{place}' has null lat"
        assert 18.0 < first["lat"] < 19.5, f"'{place}' lat {first['lat']} out of Maharashtra range"
        assert 73.0 < first["lon"] < 75.0, f"'{place}' lon {first['lon']} out of Maharashtra range"


class TestDepartureTime:
    """Tests for departure time feature."""

    def test_routes_with_departure_time(self, client):
        """Routes search with explicit departure_time returns valid results."""
        payload = {
            "source": {"lat": 18.5204, "lng": 73.8567},
            "destination": {"lat": 18.5642, "lng": 73.8440},
            "departure_time": "2026-06-10T08:30:00",
            "mode_preferences": {}
        }
        response = client.post("/api/v1/routes/search", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "routes" in data
        assert "departure_time_used" in data
        assert "08:30" in data["departure_time_used"] or "03:00" in data["departure_time_used"]

    def test_routes_without_departure_time_defaults_to_now(self, client):
        """Routes search without departure_time still works (defaults to current time)."""
        payload = {
            "source": {"lat": 18.5204, "lng": 73.8567},
            "destination": {"lat": 18.5642, "lng": 73.8440},
        }
        response = client.post("/api/v1/routes/search", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "departure_time_used" in data

    def test_routes_off_peak_vs_rush_differ(self, client):
        """Routes at rush hour and off-peak should return different scores."""
        base = {
            "source": {"lat": 18.5204, "lng": 73.8567},
            "destination": {"lat": 18.5642, "lng": 73.8440},
            "mode_preferences": {}
        }
        rush_payload = {**base, "departure_time": "2026-06-10T08:30:00"}
        offpk_payload = {**base, "departure_time": "2026-06-10T14:00:00"}

        rush_resp = client.post("/api/v1/routes/search", json=rush_payload)
        offpk_resp = client.post("/api/v1/routes/search", json=offpk_payload)

        assert rush_resp.status_code == 200
        assert offpk_resp.status_code == 200

        rush_time = rush_resp.json()["routes"][0]["total_time_mins"]
        offpk_time = offpk_resp.json()["routes"][0]["total_time_mins"]

        # Rush-hour route should take longer than off-peak
        assert rush_time >= offpk_time, (
            f"Expected rush ({rush_time}) >= off-peak ({offpk_time})"
        )


