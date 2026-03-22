import json
import csv
import sys
import os
import networkx as nx
from pathlib import Path
import math
import pickle
from scipy.spatial import KDTree

# Add backend to path so we can import app modules
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

DATA_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/processed")
GTFS_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/gtfs")
OSM_GRAPH_PATH = DATA_DIR / "osm_pune_roads.gpickle"
GRAPH_OUT = DATA_DIR / "multimodal_graph.gpickle"
KDTREE_OUT = DATA_DIR / "spatial_index.pkl"

# --- Feature Flags ---
ENABLE_TRANSIT = True   # Set to False to build road-only graph

# --- Transport parameters ---
METRO_SPEED_KMH = 35.0
METRO_AVG_WAIT_MIN = 5.0
BUS_AVG_WAIT_MIN = 7.0
WALK_SPEED_MS = 1.4
MAX_WALK_SNAP_M = 500     # Max walk link distance for transit<->road
GTFS_SNAP_WARN_M = 50     # Warn & snap if GTFS stop is >50m from nearest road


def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _add_walk_link(G, node_a, node_b, dist_m):
    """Add bidirectional walk edges between two nodes."""
    walk_time = dist_m / WALK_SPEED_MS
    attrs = {"mode": "walk", "length_m": dist_m, "travel_time": walk_time}
    G.add_edge(node_a, node_b, key=f"walk_{node_a}_{node_b}", **attrs)
    G.add_edge(node_b, node_a, key=f"walk_{node_b}_{node_a}", **attrs)


def _snap_transit_to_road(G, stop_id, stop_lat, stop_lon, road_tree, osm_node_ids, osm_node_coords, k=3):
    """
    Connect a transit stop to the k nearest road nodes.
    If the nearest road node is >50m away, log a warning and use
    the road node's coordinates as the effective stop position.
    Returns the (possibly snapped) lat, lon.
    """
    dists, nearest_idx = road_tree.query([stop_lat, stop_lon], k=k)

    snapped_lat, snapped_lon = stop_lat, stop_lon
    warned = False

    for i in range(len(dists)):
        road_n_id = osm_node_ids[nearest_idx[i]]
        road_data = G.nodes[road_n_id]
        real_dist = haversine(stop_lat, stop_lon, road_data["lat"], road_data["lon"])

        if real_dist > MAX_WALK_SNAP_M:
            continue  # Too far, skip this road node

        if i == 0 and real_dist > GTFS_SNAP_WARN_M and not warned:
            print(f"  [SNAP] Stop {stop_id} is {real_dist:.0f}m from nearest road. "
                  f"Snapping to road node {road_n_id}.")
            snapped_lat = road_data["lat"]
            snapped_lon = road_data["lon"]
            warned = True

        _add_walk_link(G, stop_id, road_n_id, real_dist)

    return snapped_lat, snapped_lon


def build_graph():
    # =========================================================================
    # STEP 1: Load OSM Road Network (base layer)
    # =========================================================================
    print("=" * 60)
    print("STEP 1: Loading OSM Road Network...")
    if not OSM_GRAPH_PATH.exists():
        raise FileNotFoundError(f"{OSM_GRAPH_PATH} not found. Run build_osm_graph.py first.")

    with open(OSM_GRAPH_PATH, "rb") as f:
        multi_G = pickle.load(f)

    print(f"  Loaded {len(multi_G.nodes)} road nodes, {len(multi_G.edges)} road edges (MultiDiGraph).")

    # Convert MultiDiGraph → DiGraph (keep min-weight edge per node pair)
    # Required because nx.astar_path doesn't support MultiDiGraph
    G = nx.DiGraph()
    for n, data in multi_G.nodes(data=True):
        G.add_node(n, **data)
    for u, v, data in multi_G.edges(data=True):
        tt = float(data.get("travel_time", data.get("length", 9999)))
        if G.has_edge(u, v):
            if tt < G[u][v].get("travel_time", 9999):
                G[u][v].update(data)
        else:
            G.add_edge(u, v, **data)
    del multi_G

    print(f"  Converted to DiGraph: {len(G.nodes)} nodes, {len(G.edges)} edges.")

    # Normalize OSM edge attributes
    for u, v, d in G.edges(data=True):
        d['mode'] = 'road'
        if 'length_m' not in d:
            d['length_m'] = float(d.get('length', 0.0))
        if 'travel_time' not in d:
            speed = float(d.get('speed_kph', 20.0)) / 3.6
            d['travel_time'] = d['length_m'] / max(speed, 0.1)

    # Normalize OSM node attributes (y=lat, x=lon)
    osm_node_coords = []
    osm_node_ids = []
    for n_id, data in G.nodes(data=True):
        data['lat'] = data.get('y')
        data['lon'] = data.get('x')
        data['type'] = 'road_node'
        osm_node_coords.append([data['lat'], data['lon']])
        osm_node_ids.append(n_id)

    road_tree = KDTree(osm_node_coords)

    # =========================================================================
    # STEP 2: Load Metro edges (existing functionality)
    # =========================================================================
    print("=" * 60)
    print("STEP 2: Loading Metro stations & edges...")
    with open(DATA_DIR / "metro_stations.json", "r") as f:
        metro_stops = json.load(f)

    metro_node_count = 0
    for stop in metro_stops:
        s_id = stop["id"]
        node_data = dict(stop)
        node_data["type"] = "metro_station"
        G.add_node(s_id, **node_data)
        _snap_transit_to_road(G, s_id, stop["lat"], stop["lon"],
                              road_tree, osm_node_ids, osm_node_coords)
        metro_node_count += 1

    edges_csv = DATA_DIR / "metro_edges.csv"
    metro_edge_count = 0
    if edges_csv.exists():
        with open(edges_csv, "r") as f:
            reader = csv.DictReader(f)
            for row in reader:
                from_id = row["from_station"]
                to_id = row["to_station"]
                line = row["line"]
                if from_id in G.nodes and to_id in G.nodes:
                    n1, n2 = G.nodes[from_id], G.nodes[to_id]
                    dist = haversine(n1["lat"], n1["lon"], n2["lat"], n2["lon"])
                    speed_ms = METRO_SPEED_KMH / 3.6
                    travel_time = dist / speed_ms
                    attrs = {
                        "mode": "metro", "length_m": dist,
                        "travel_time": travel_time, "line": line,
                    }
                    G.add_edge(from_id, to_id, key=f"metro_{from_id}_{to_id}", **attrs)
                    G.add_edge(to_id, from_id, key=f"metro_{to_id}_{from_id}", **attrs)
                    metro_edge_count += 1
    print(f"  Added {metro_node_count} metro nodes, {metro_edge_count} metro edges.")

    # =========================================================================
    # STEP 3: GTFS Bus Integration (NEW — guarded by ENABLE_TRANSIT)
    # =========================================================================
    if ENABLE_TRANSIT and GTFS_DIR.exists() and (GTFS_DIR / "stops.txt").exists():
        print("=" * 60)
        print("STEP 3: Integrating GTFS bus data...")

        from app.transit.gtfs_loader import GTFSData
        gtfs = GTFSData()
        gtfs.load(GTFS_DIR)

        # 3a. Add GTFS bus stop nodes
        gtfs_stop_count = 0
        snap_count = 0
        for stop_id, info in gtfs.stops.items():
            node_id = f"gtfs_{stop_id}"
            lat, lon = info["lat"], info["lon"]

            # Intelligent snap: if >50m from road, snap coords to road
            snapped_lat, snapped_lon = _snap_transit_to_road(
                G, node_id, lat, lon,
                road_tree, osm_node_ids, osm_node_coords
            )

            if snapped_lat != lat or snapped_lon != lon:
                snap_count += 1

            G.add_node(node_id,
                       name=info["name"],
                       lat=snapped_lat,
                       lon=snapped_lon,
                       type="bus_stop",
                       gtfs_stop_id=stop_id)
            gtfs_stop_count += 1

        print(f"  Added {gtfs_stop_count} GTFS bus stops ({snap_count} snapped >50m)")

        # 3b. Add bus edges from deduplicated trip sequences
        #     Each edge represents a direct bus connection between consecutive stops.
        #     Edges are tagged with route_id so the router knows which routes serve
        #     each segment — staying on the same route is NOT a transfer.
        bus_edges = gtfs.get_unique_edges()
        bus_edge_count = 0
        skipped = 0

        for (from_stop, to_stop), edge_info in bus_edges.items():
            from_node = f"gtfs_{from_stop}"
            to_node = f"gtfs_{to_stop}"

            if from_node not in G.nodes or to_node not in G.nodes:
                skipped += 1
                continue

            #  Add average wait time to the first boarding of a bus segment.
            #  But we do NOT add wait time to intermediate stops on the same route,
            #  because a passenger already on the bus just rides through.
            #  The wait penalty is applied once per boarding in the router, not here.
            travel_time = edge_info["min_travel_time"]

            # Convert route sets to lists for serialization
            route_ids = list(edge_info["route_ids"])
            route_names = list(edge_info["route_names"])

            attrs = {
                "mode": "bus",
                "length_m": haversine(
                    G.nodes[from_node]["lat"], G.nodes[from_node]["lon"],
                    G.nodes[to_node]["lat"], G.nodes[to_node]["lon"],
                ),
                "travel_time": travel_time,
                "route_ids": route_ids,
                "route_names": route_names,
                "trip_count": edge_info["trip_count"],
            }

            G.add_edge(from_node, to_node,
                        key=f"bus_{from_stop}_{to_stop}",
                        **attrs)
            bus_edge_count += 1

        print(f"  Added {bus_edge_count} bus edges ({skipped} skipped — missing nodes)")
    else:
        if not ENABLE_TRANSIT:
            print("STEP 3: SKIPPED (ENABLE_TRANSIT = False)")
        else:
            print("STEP 3: SKIPPED (No GTFS data found)")

    # =========================================================================
    # STEP 4: Build Unified Spatial Index
    # =========================================================================
    print("=" * 60)
    print("STEP 4: Building unified spatial index...")

    all_node_coords = []
    all_node_ids = []
    for n_id, data in G.nodes(data=True):
        if 'lat' in data and 'lon' in data:
            all_node_coords.append([data['lat'], data['lon']])
            all_node_ids.append(n_id)

    unified_tree = KDTree(all_node_coords)
    index_data = {
        "tree": unified_tree,
        "node_ids": all_node_ids,
        "coords": all_node_coords,
    }

    # =========================================================================
    # STEP 5: Save
    # =========================================================================
    print("=" * 60)
    print(f"STEP 5: Saving graph ({len(G.nodes)} nodes, {len(G.edges)} edges)...")
    with open(GRAPH_OUT, "wb") as f:
        pickle.dump(G, f)
    with open(KDTREE_OUT, "wb") as f:
        pickle.dump(index_data, f)

    print("✓ Multimodal graph built successfully!")


if __name__ == "__main__":
    build_graph()
