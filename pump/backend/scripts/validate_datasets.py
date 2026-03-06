"""
validate_datasets.py — Validate all datasets before graph construction.

Checks:
  1. Missing coordinates in bus_stops.json / metro_stations.json
  2. Duplicate station IDs
  3. Missing required fields
  4. Metro edge references to non-existent stations
  5. Basic graph connectivity check
"""

import json
import csv
from pathlib import Path
from collections import Counter

DATA_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/processed")

ERRORS = []
WARNINGS = []


def check_json_dataset(filepath, required_fields, dataset_name):
    """Validate a JSON array dataset for missing fields and duplicates."""
    if not filepath.exists():
        ERRORS.append(f"[{dataset_name}] File not found: {filepath}")
        return []

    with open(filepath, "r") as f:
        data = json.load(f)

    if not isinstance(data, list):
        ERRORS.append(f"[{dataset_name}] Expected a JSON array, got {type(data).__name__}")
        return []

    print(f"\n{'='*50}")
    print(f"Validating {dataset_name}: {len(data)} records")
    print(f"{'='*50}")

    # Check required fields
    missing_count = 0
    for i, item in enumerate(data):
        for field in required_fields:
            if field not in item or item[field] is None:
                missing_count += 1
                if missing_count <= 5:
                    ERRORS.append(f"[{dataset_name}] Record {i}: missing '{field}' — {item.get('id', 'unknown')}")

    if missing_count > 5:
        ERRORS.append(f"[{dataset_name}] ... and {missing_count - 5} more missing field errors")

    # Check coordinates range (Pune bounding box: 18.33–18.72 lat, 73.68–74.10 lon)
    out_of_range = 0
    for item in data:
        lat = item.get("lat")
        lon = item.get("lon")
        if lat is not None and lon is not None:
            if not (18.33 <= lat <= 18.72) or not (73.68 <= lon <= 74.10):
                out_of_range += 1
                if out_of_range <= 3:
                    WARNINGS.append(f"[{dataset_name}] Coordinates outside Pune: {item.get('name', item.get('id'))} ({lat}, {lon})")

    if out_of_range > 3:
        WARNINGS.append(f"[{dataset_name}] ... and {out_of_range - 3} more out-of-range coordinates")

    # Check duplicate IDs
    ids = [item.get("id") for item in data if "id" in item]
    id_counts = Counter(ids)
    duplicates = {k: v for k, v in id_counts.items() if v > 1}
    if duplicates:
        for dup_id, count in duplicates.items():
            WARNINGS.append(f"[{dataset_name}] Duplicate ID: '{dup_id}' appears {count} times")

    valid_count = len(data) - missing_count
    print(f"  ✓ {valid_count}/{len(data)} records valid")
    if missing_count:
        print(f"  ✗ {missing_count} records with missing fields")
    if out_of_range:
        print(f"  ⚠ {out_of_range} records with out-of-range coordinates")
    if duplicates:
        print(f"  ⚠ {len(duplicates)} duplicate IDs")

    return data


def check_metro_edges():
    """Validate metro_edges.csv references valid station IDs."""
    edges_path = DATA_DIR / "metro_edges.csv"
    stations_path = DATA_DIR / "metro_stations.json"

    if not edges_path.exists():
        WARNINGS.append("[metro_edges] metro_edges.csv not found")
        return

    if not stations_path.exists():
        ERRORS.append("[metro_edges] Cannot validate edges — metro_stations.json not found")
        return

    with open(stations_path, "r") as f:
        stations = json.load(f)
    station_ids = {s["id"] for s in stations}

    print(f"\n{'='*50}")
    print("Validating metro_edges.csv")
    print(f"{'='*50}")

    with open(edges_path, "r") as f:
        reader = csv.DictReader(f)
        edge_count = 0
        orphan_count = 0

        for row in reader:
            edge_count += 1
            if row["from_station"] not in station_ids:
                orphan_count += 1
                ERRORS.append(f"[metro_edges] Edge references unknown station: {row['from_station']}")
            if row["to_station"] not in station_ids:
                orphan_count += 1
                ERRORS.append(f"[metro_edges] Edge references unknown station: {row['to_station']}")

    print(f"  ✓ {edge_count} edges checked")
    if orphan_count:
        print(f"  ✗ {orphan_count} orphan references")
    else:
        print(f"  ✓ All edge references valid")


def check_graph_connectivity():
    """Basic check on the pickled graph for disconnected components."""
    import pickle

    graph_path = DATA_DIR / "multimodal_graph.gpickle"
    if not graph_path.exists():
        WARNINGS.append("[graph] multimodal_graph.gpickle not found — run build_graph.py first")
        return

    print(f"\n{'='*50}")
    print("Analysing graph connectivity")
    print(f"{'='*50}")

    with open(graph_path, "rb") as f:
        G = pickle.load(f)

    # Convert to undirected for component analysis
    G_undirected = G.to_undirected()
    import networkx as nx
    components = list(nx.connected_components(G_undirected))

    print(f"  Nodes: {len(G.nodes)}")
    print(f"  Edges: {len(G.edges)}")
    print(f"  Connected components: {len(components)}")

    if len(components) > 1:
        sizes = sorted([len(c) for c in components], reverse=True)
        print(f"  Component sizes (top 5): {sizes[:5]}")
        if sizes[0] / len(G.nodes) < 0.8:
            WARNINGS.append(f"[graph] Largest component has only {sizes[0]}/{len(G.nodes)} nodes ({100*sizes[0]//len(G.nodes)}%)")
        else:
            print(f"  ✓ Largest component covers {100*sizes[0]//len(G.nodes)}% of nodes")
    else:
        print(f"  ✓ Graph is fully connected")


if __name__ == "__main__":
    print("=== Marg Dataset Validation ===\n")

    # 1. Bus Stops
    check_json_dataset(
        DATA_DIR / "bus_stops.json",
        ["id", "lat", "lon", "name"],
        "bus_stops"
    )

    # 2. Metro Stations
    check_json_dataset(
        DATA_DIR / "metro_stations.json",
        ["id", "lat", "lon", "name", "line"],
        "metro_stations"
    )

    # 3. Metro Edges
    check_metro_edges()

    # 4. Graph Connectivity
    check_graph_connectivity()

    # --- Report ---
    print(f"\n{'='*50}")
    print(f"VALIDATION SUMMARY")
    print(f"{'='*50}")

    if ERRORS:
        print(f"\n❌ {len(ERRORS)} ERROR(S):")
        for e in ERRORS:
            print(f"   {e}")
    else:
        print("\n✓ No errors found")

    if WARNINGS:
        print(f"\n⚠ {len(WARNINGS)} WARNING(S):")
        for w in WARNINGS:
            print(f"   {w}")
    else:
        print("✓ No warnings")

    print()
    exit(1 if ERRORS else 0)
