import osmnx as ox
import networkx as nx
from pathlib import Path
import pickle
import os

DATA_DIR = Path(os.getenv("PUMP_DATA_DIR", "/home/jayant/gitgud/marg/marg/pump/data/processed"))
GRAPH_OUT = DATA_DIR / "osm_pune_roads.gpickle"

def build_osm_graph():
    if GRAPH_OUT.exists():
        print(f"Found existing {GRAPH_OUT}, checking if valid...")
        try:
            with open(GRAPH_OUT, 'rb') as f:
                G = pickle.load(f)
            # Ensure it's a MultiDiGraph
            if not isinstance(G, nx.MultiDiGraph):
                print("Graph is not MultiDiGraph. Rebuilding...")
            else:
                edges = list(G.edges(data=True))
                if len(edges) > 0 and 'travel_time' in edges[0][2]:
                    print("Graph is valid and has travel_time. Skipping download.")
                    return
                else:
                    print("Existing graph lacks travel_time or is invalid. Rebuilding...")
        except Exception as e:
            print(f"Error loading existing graph: {e}. Rebuilding...")

    print("Downloading OSM drive network for Pune...")
    # bbox: west, south, east, north
    bbox = (73.68, 18.33, 74.10, 18.72)
    G = ox.graph_from_bbox(bbox=bbox, network_type='drive')
    
    print(f"Downloaded {len(G.nodes)} nodes and {len(G.edges)} edges.")
    
    print("Adding edge speeds and travel times...")
    hwy_speeds = {
        'motorway': 80,
        'trunk': 80,
        'primary': 50,
        'secondary': 40,
        'tertiary': 30,
        'residential': 20,
        'unclassified': 20
    }
    G = ox.add_edge_speeds(G, hwy_speeds=hwy_speeds, fallback=20)
    G = ox.add_edge_travel_times(G)
    
    print(f"Saving to {GRAPH_OUT}...")
    with open(GRAPH_OUT, "wb") as f:
        pickle.dump(G, f)
    print("Done!")

if __name__ == "__main__":
    build_osm_graph()
