"""Startup smoke tests for Marg backend."""
import pytest


def test_startup_health_routing_available(client):
    """Verify backend boots and /api/v1/health reports routing_available: True."""
    resp = client.get("/api/v1/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data.get("routing_available") is True, f"Routing unavailable: {data}"
    assert data.get("status") in ("ok", "degraded")
    assert "components" in data
    assert data["components"]["graph"]["status"] == "ok"
    assert data["components"]["graph"]["nodes"] > 0
