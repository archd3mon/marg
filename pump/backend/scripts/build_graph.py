import json
import csv
import networkx as nx
from pathlib import Path
import math
import pickle
from scipy.spatial import KDTree

DATA_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/processed")
GRAPH_OUT = DATA_DIR / "multimodal_graph.gpickle"
KDTREE_OUT = DATA_DIR / "spatial_index.pkl"

# --- Transport parameters ---
METRO_SPEED_KMH = 35.0          # Metro average including stops
METRO_AVG_WAIT_MIN = 5.0        # Average wait between trains
BUS_PROXIMITY_M = 1200          # Max distance for bus-to-bus edges (increased to connect network)
WALK_TRANSFER_M = 1500          # Max distance for walk/transfer edges to metro


def haversine(lat1, lon1, lat2, lon2):
    """Returns distance in meters between two lat/lon points."""
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def build_graph():
    print("Loading nodes...")
    with open(DATA_DIR / "bus_stops.json", "r") as f:
        bus_stops = json.load(f)
    with open(DATA_DIR / "metro_stations.json", "r") as f:
        metro_stops = json.load(f)

    G = nx.MultiDiGraph()
    node_coords = []
    node_ids = []

    # --- 1. Add Bus Nodes ---
    for stop in bus_stops:
        G.add_node(stop["id"], **stop)
        node_coords.append([stop["lat"], stop["lon"]])
        node_ids.append(stop["id"])

    # --- 2. Add Metro Nodes ---
    for stop in metro_stops:
        G.add_node(stop["id"], **stop)
        node_coords.append([stop["lat"], stop["lon"]])
        node_ids.append(stop["id"])

    print(f"Added {len(G.nodes)} nodes. Building edges...")

    # --- 3. Build Metro Edges from metro_edges.csv ---
    edges_csv = DATA_DIR / "metro_edges.csv"
    if edges_csv.exists():
        metro_edge_count = 0
        with open(edges_csv, "r") as f:
            reader = csv.DictReader(f)
            for row in reader:
                from_id = row["from_station"]
                to_id = row["to_station"]
                line = row["line"]

                if from_id in G.nodes and to_id in G.nodes:
                    n1 = G.nodes[from_id]
                    n2 = G.nodes[to_id]
                    dist = haversine(n1["lat"], n1["lon"], n2["lat"], n2["lon"])

                    # Bidirectional metro edges with speed and wait time attributes
                    edge_attrs = {
                        "mode": "metro",
                        "length_m": dist,
                        "speed_kmh": METRO_SPEED_KMH,
                        "avg_wait_min": METRO_AVG_WAIT_MIN,
                        "line": line,
                    }
                    G.add_edge(from_id, to_id, key=f"metro_{from_id}_{to_id}", **edge_attrs)
                    G.add_edge(to_id, from_id, key=f"metro_{to_id}_{from_id}", **edge_attrs)
                    metro_edge_count += 1

        print(f"Added {metro_edge_count} metro edges (bidirectional) from CSV.")
    else:
        # Fallback: build from JSON (backward compatibility)
        print("WARNING: metro_edges.csv not found — building from sequential station order.")
        lines = {}
        for s in metro_stops:
            line = s.get("line", "Unknown")
            # Handle multi-line stations (e.g. Purple/Aqua)
            for l in line.split("/"):
                l = l.strip()
                if l not in lines:
                    lines[l] = []
                lines[l].append(s)

        for line_name, stations in lines.items():
            stations.sort(key=lambda x: x.get("order", 0))
            for i in range(len(stations) - 1):
                n1, n2 = stations[i], stations[i + 1]
                dist = haversine(n1["lat"], n1["lon"], n2["lat"], n2["lon"])
                edge_attrs = {
                    "mode": "metro",
                    "length_m": dist,
                    "speed_kmh": METRO_SPEED_KMH,
                    "avg_wait_min": METRO_AVG_WAIT_MIN,
                    "line": line_name,
                }
                G.add_edge(n1["id"], n2["id"], key=f"metro_{n1['id']}_{n2['id']}", **edge_attrs)
                G.add_edge(n2["id"], n1["id"], key=f"metro_{n2['id']}_{n1['id']}", **edge_attrs)

    # --- 4. Build Spatial Index ---
    print("Building spatial index for transfers and bus routing...")
    tree = KDTree(node_coords)

    # --- 5. Build Bus + Walk Edges ---
    bus_edge_count = 0
    walk_edge_count = 0

    for i, (lat, lon) in enumerate(node_coords):
        n1_id = node_ids[i]
        n1_type = G.nodes[n1_id].get("type")
        
        # Query top 10 nearest neighbors to GUARANTEE network connectivity
        distances, nearest = tree.query([lat, lon], k=10)
        
        for j in nearest:
            if i != j:
                n2_id = node_ids[j]
                n2_type = G.nodes[n2_id].get("type")
                n2_lat, n2_lon = node_coords[j]
                dist = haversine(lat, lon, n2_lat, n2_lon)

                # Bus-to-bus proximity edges
                if n1_type == "bus_stop" and n2_type == "bus_stop" and dist <= BUS_PROXIMITY_M:
                    G.add_edge(n1_id, n2_id, mode="bus", length_m=dist, key=f"bus_{n1_id}_{n2_id}")
                    bus_edge_count += 1

                # Walk edges (always connect k-nearest)
                if dist <= WALK_TRANSFER_M or True: # Add walk edge regardless of distance to connect graph
                    # Cap distance for walking speed so it doesn't skew perfectly but connects components
                    G.add_edge(n1_id, n2_id, mode="walk", length_m=dist, key=f"walk_{n1_id}_{n2_id}")
                    walk_edge_count += 1

    print(f"Added {bus_edge_count} bus edges, {walk_edge_count} walk edges.")
    print(f"Graph built: {len(G.nodes)} nodes, {len(G.edges)} edges.")

    # --- 6. Save ---
    with open(GRAPH_OUT, "wb") as f:
        pickle.dump(G, f)

    index_data = {
        "tree": tree,
        "node_ids": node_ids,
        "coords": node_coords,
    }
    with open(KDTREE_OUT, "wb") as f:
        pickle.dump(index_data, f)

    print(f"✓ Saved graph to {GRAPH_OUT}")
    print(f"✓ Saved spatial index to {KDTREE_OUT}")


if __name__ == "__main__":
    build_graph()
