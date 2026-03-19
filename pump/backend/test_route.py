"""Test script to verify multi-modal routing with GTFS bus integration."""
import sys
sys.path.insert(0, ".")

from app.network.graph import engine

engine.load()

# --- Test 1: Baner to Shivajinagar ---
print("=" * 60)
print("TEST 1: Baner (18.5590, 73.7868) → Shivajinagar (18.5325, 73.8495)")
print("=" * 60)
paths = engine.k_shortest_paths(18.5590, 73.7868, 18.5325, 73.8495, k=3)
print(f"Found {len(paths)} paths.\n")
for i, path in enumerate(paths):
    print(f"  Route {i+1}: {path['total_distance_m']:.0f}m, {path['transfers']} transfers")
    for leg in path["legs"]:
        from_name = leg['from_node'].get('name', 'Road')
        to_name = leg['to_node'].get('name', 'Road')
        mode = leg['mode']
        routes = leg.get('route_names', [])
        route_str = f" [{', '.join(routes)}]" if routes else ""
        print(f"    {mode}{route_str}: {from_name} → {to_name} "
              f"({leg['length_m']:.0f}m, {leg['travel_time']:.0f}s)")
    print()

# --- Test 2: SIT Pune to Dagduseth ---
print("=" * 60)
print("TEST 2: SIT Pune (18.5362, 73.7271) → Dagduseth (18.5171, 73.8553)")
print("=" * 60)
paths2 = engine.k_shortest_paths(18.5362, 73.7271, 18.5171, 73.8553, k=3)
print(f"Found {len(paths2)} paths.\n")
for i, path in enumerate(paths2):
    print(f"  Route {i+1}: {path['total_distance_m']:.0f}m, {path['transfers']} transfers")
    for leg in path["legs"]:
        from_name = leg['from_node'].get('name', 'Road')
        to_name = leg['to_node'].get('name', 'Road')
        mode = leg['mode']
        routes = leg.get('route_names', [])
        route_str = f" [{', '.join(routes)}]" if routes else ""
        print(f"    {mode}{route_str}: {from_name} → {to_name} "
              f"({leg['length_m']:.0f}m, {leg['travel_time']:.0f}s)")
    print()
