import pickle
from pathlib import Path
import networkx as nx
from itertools import islice

DATA_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/processed")
GRAPH_PATH = DATA_DIR / "multimodal_graph.gpickle"
KDTREE_PATH = DATA_DIR / "spatial_index.pkl"

class RouteEngine:
    def __init__(self):
        self.G = None
        self.tree = None
        self.node_ids = None
        self.coords = None
        
    def load(self):
        print("Loading Route Engine Graph and KD-Tree...")
        with open(GRAPH_PATH, 'rb') as f:
            self.G = pickle.load(f)
            
        with open(KDTREE_PATH, 'rb') as f:
            index_data = pickle.load(f)
            self.tree = index_data['tree']
            self.node_ids = index_data['node_ids']
            self.coords = index_data['coords']
        print(f"Loaded {len(self.G.nodes)} nodes into engine.")
        
    def get_nearest_node(self, lat, lon):
        dist, idx = self.tree.query([lat, lon])
        return self.node_ids[idx], dist

    def k_shortest_paths(self, source_lat, source_lon, dest_lat, dest_lon, k=5, departure_hour=10, departure_day=0):
        """
        Uses NetworkX's built-in `shortest_simple_paths` (Yen's algorithm implementation)
        to find top k routes minimizing dynamic time-based weights instead of mere distance.
        """
        if self.G is None:
            raise ValueError("Engine not loaded")
            
        source_id, s_dist = self.get_nearest_node(source_lat, source_lon)
        dest_id, d_dist = self.get_nearest_node(dest_lat, dest_lon)
        
        # Max reasonable walk to a node (approx 1.5km)
        if s_dist > 0.015 or d_dist > 0.015:
            return []
            
        # Update graph edge weights dynamically *before* route calculation
        # and project the MultiDiGraph to a DiGraph since shortest_simple_paths
        # does not support MultiGraphs natively.
        G_simple = nx.DiGraph()
        
        for u, v, key, d in self.G.edges(keys=True, data=True):
            mode = d.get('mode', 'walk')
            length = d.get('length_m', 0.0)
            
            # Approximate the ML models rules for rapid graph traversal
            speed_m_s = 1.4 # walk
            if mode == 'metro':
                speed_m_s = 10.0
            elif mode == 'bus':
                base_speed = 5.0
                # Rush hour penalty
                if (8 <= departure_hour <= 11) or (17 <= departure_hour <= 20):
                    base_speed *= 0.5
                speed_m_s = base_speed
                
            dynamic_time = length / max(speed_m_s, 1.0)
            
            if G_simple.has_edge(u, v):
                if dynamic_time < G_simple[u][v]['dynamic_time']:
                    # Overwrite with faster edge
                    G_simple.add_edge(u, v, **d)
                    G_simple[u][v]['dynamic_time'] = dynamic_time
            else:
                G_simple.add_edge(u, v, **d)
                G_simple[u][v]['dynamic_time'] = dynamic_time

        try:
            # We use the dynamically calculated attribute as the weight on the Simple DiGraph
            paths_gen = nx.shortest_simple_paths(G_simple, source=source_id, target=dest_id, weight='dynamic_time')
            
            top_k_paths = []
            for path in islice(paths_gen, k):
                top_k_paths.append(self._format_path(path, G_simple))
            return top_k_paths
            
        except nx.NetworkXNoPath:
            return []
            
    def _format_path(self, node_list, G_simple):
        """Converts raw node list into a structure suitable for the ML layer."""
        legs = []
        path_distance = 0.0
        
        for i in range(len(node_list)-1):
            n1 = node_list[i]
            n2 = node_list[i+1]
            
            best_edge = G_simple.get_edge_data(n1, n2)
            
            leg = {
                "from_node": self.G.nodes[n1],
                "to_node": self.G.nodes[n2],
                "mode": best_edge.get("mode", "walk"),
                "length_m": best_edge.get("length_m", 0.0)
            }
            path_distance += leg['length_m']
            legs.append(leg)
            
        return {
            "legs": legs,
            "total_distance_m": path_distance,
            "transfers": self._count_transfers(legs)
        }
        
    def _count_transfers(self, legs):
        transfers = 0
        if not legs: return 0
        
        current_mode = legs[0]['mode']
        for leg in legs[1:]:
            # We only count structural transit changes as transfers
            # Moving from Bus to Bus without a walk might not happen cleanly in our heuristic graph
            # so we define transfer as a mode switch.
            if leg['mode'] != current_mode and current_mode != 'walk':
                if leg['mode'] in ['bus', 'metro']:
                    transfers += 1
            current_mode = leg['mode']
        return transfers

# Singleton instances
engine = RouteEngine()
