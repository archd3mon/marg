import json
import networkx as nx
from pathlib import Path
import math
import pickle
from scipy.spatial import KDTree

DATA_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/processed")
GRAPH_OUT = DATA_DIR / "multimodal_graph.gpickle"
KDTREE_OUT = DATA_DIR / "spatial_index.pkl"

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000 # radius of Earth in meters
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))

def build_graph():
    print("Loading nodes...")
    with open(DATA_DIR / "bus_stops.json", 'r') as f:
        bus_stops = json.load(f)
        
    with open(DATA_DIR / "metro_stations.json", 'r') as f:
        metro_stops = json.load(f)
        
    G = nx.MultiDiGraph()
    node_coords = []
    node_ids = []
    
    # 1. Add Bus Nodes
    for stop in bus_stops:
        G.add_node(stop['id'], **stop)
        node_coords.append([stop['lat'], stop['lon']])
        node_ids.append(stop['id'])
        
    # 2. Add Metro Nodes
    for stop in metro_stops:
        G.add_node(stop['id'], **stop)
        node_coords.append([stop['lat'], stop['lon']])
        node_ids.append(stop['id'])
        
    print(f"Added {len(G.nodes)} nodes. Building edges...")
    
    # 3. Build Metro Edges (Sequential along lines)
    aqua = [s for s in metro_stops if "Aqua" in s.get('line', '')]
    purple = [s for s in metro_stops if "Purple" in s.get('line', '')]
    
    for line in (aqua, purple):
        for i in range(len(line)-1):
            n1 = line[i]
            n2 = line[i+1]
            dist = haversine(n1['lat'], n1['lon'], n2['lat'], n2['lon'])
            
            # Bidirectional metro edges
            G.add_edge(n1['id'], n2['id'], mode="metro", length_m=dist, key=f"metro_{n1['id']}_{n2['id']}")
            G.add_edge(n2['id'], n1['id'], mode="metro", length_m=dist, key=f"metro_{n2['id']}_{n1['id']}")

    # 4. Build Bus Edges
    # Since we have isolated stops but lack sequential route geometries directly mapped to stops 
    # in this raw dataset format, we will spatially link nearby bus stops to simulate the network.
    # A real transit router uses GTFS `stop_times.txt`, but we will build a spatial Delaunay-like
    # or proximity graph for bus stops within 500m of each other.
    print("Building spatial index for transfers and bus routing...")
    tree = KDTree(node_coords)
    
    # Connect stops within 400 meters
    for i, (lat, lon) in enumerate(node_coords):
        n1_id = node_ids[i]
        n1_type = G.nodes[n1_id].get('type')
        
        # Find neighbors within ~400 meters (approx 0.004 degrees)
        # Using KDTree in Euclidean space on lat/lon is technically flawed but acceptable for 400m
        # For precision, we query larger and filter by Haversine.
        neighbors = tree.query_ball_point([lat, lon], r=0.005) 
        
        for j in neighbors:
            if i != j:
                n2_id = node_ids[j]
                n2_type = G.nodes[n2_id].get('type')
                
                n2_lat, n2_lon = node_coords[j]
                dist = haversine(lat, lon, n2_lat, n2_lon)
                
                if dist <= 400:
                    mode = "walk"
                    if n1_type == 'bus_stop' and n2_type == 'bus_stop':
                        # Allow bus travel between nearby stops to simulate the road network
                        G.add_edge(n1_id, n2_id, mode="bus", length_m=dist, key=f"bus_{n1_id}_{n2_id}")
                    
                    # Also add a walk edge for transfers
                    G.add_edge(n1_id, n2_id, mode="walk", length_m=dist, key=f"walk_{n1_id}_{n2_id}")

    print(f"Graph built with {len(G.nodes)} nodes and {len(G.edges)} edges.")
    
    # Save Graph
    with open(GRAPH_OUT, 'wb') as f:
        pickle.dump(G, f)
        
    # Save Spatial Index for API
    index_data = {
        'tree': tree,
        'node_ids': node_ids,
        'coords': node_coords
    }
    with open(KDTREE_OUT, 'wb') as f:
        pickle.dump(index_data, f)
        
    print("Saved Graph and KD-Tree successfully.")

if __name__ == "__main__":
    build_graph()
