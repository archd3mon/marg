import pickle
from pathlib import Path
import networkx as nx
from itertools import islice
import os

DATA_DIR = Path(os.getenv("PUMP_DATA_DIR", "/home/jayant/gitgud/marg/marg/pump/data/processed"))
GRAPH_PATH = DATA_DIR / "multimodal_graph.gpickle"
KDTREE_PATH = DATA_DIR / "spatial_index.pkl"


class RouteEngine:
    def __init__(self):
        self.G = None
        self.tree = None
        self.node_ids = None
        self.coords = None
        self._simple_cache = {}  # Cache simplified DiGraphs per time-bucket

    def load(self):
        print("Loading Route Engine Graph and KD-Tree...")
        with open(GRAPH_PATH, "rb") as f:
            self.G = pickle.load(f)
        with open(KDTREE_PATH, "rb") as f:
            index_data = pickle.load(f)
            self.tree = index_data["tree"]
            self.node_ids = index_data["node_ids"]
            self.coords = index_data["coords"]
        print(f"Loaded {len(self.G.nodes)} nodes, {len(self.G.edges)} edges into engine.")

    def get_nearest_node(self, lat, lon):
        dist, idx = self.tree.query([lat, lon])
        return self.node_ids[idx], dist

    def _get_time_bucket(self, hour, day):
        """Bucket by peak/off-peak and weekday/weekend for caching."""
        is_rush = (8 <= hour <= 11) or (17 <= hour <= 20)
        is_weekend = day >= 5
        return f"{'rush' if is_rush else 'off'}_{('we' if is_weekend else 'wd')}"

    def _build_simple_graph(self, departure_hour, departure_day):
        """Build a simplified DiGraph with dynamic time-based weights."""
        bucket = self._get_time_bucket(departure_hour, departure_day)

        if bucket in self._simple_cache:
            return self._simple_cache[bucket]

        G_simple = nx.DiGraph()

        for u, v, key, d in self.G.edges(keys=True, data=True):
            mode = d.get("mode", "walk")
            length = d.get("length_m", 0.0)

            # Speed calculation
            if mode == "metro":
                speed_kmh = d.get("speed_kmh", 35.0)
                speed_m_s = speed_kmh / 3.6
                # Add wait time penalty (converted to equivalent distance)
                wait_penalty = d.get("avg_wait_min", 5.0) * 60.0 * 0.1  # small fraction
            elif mode == "bus":
                base_speed = 5.0  # m/s (~18 km/h)
                if (8 <= departure_hour <= 11) or (17 <= departure_hour <= 20):
                    base_speed *= 0.5
                speed_m_s = base_speed
                wait_penalty = 0
            else:  # walk
                speed_m_s = 1.4  # ~5 km/h
                wait_penalty = 0

            dynamic_time = (length / max(speed_m_s, 0.5)) + wait_penalty

            if G_simple.has_edge(u, v):
                if dynamic_time < G_simple[u][v]["dynamic_time"]:
                    G_simple.add_edge(u, v, **d)
                    G_simple[u][v]["dynamic_time"] = dynamic_time
            else:
                G_simple.add_edge(u, v, **d)
                G_simple[u][v]["dynamic_time"] = dynamic_time

        # Cache up to 4 buckets
        if len(self._simple_cache) >= 4:
            self._simple_cache.clear()
        self._simple_cache[bucket] = G_simple

        return G_simple

    def _get_transit_nodes(self, node_list, G_simple):
        """Extract the set of transit (bus/metro) node IDs from a path."""
        transit_nodes = set()
        for i in range(len(node_list) - 1):
            edge_data = G_simple.get_edge_data(node_list[i], node_list[i + 1])
            mode = edge_data.get("mode", "walk") if edge_data else "walk"
            if mode in ("bus", "metro"):
                transit_nodes.add(node_list[i])
                transit_nodes.add(node_list[i + 1])
        return transit_nodes

    def _get_mode_sequence(self, node_list, G_simple):
        """Get the simplified mode sequence (consecutive duplicates collapsed)."""
        seq = []
        for i in range(len(node_list) - 1):
            edge_data = G_simple.get_edge_data(node_list[i], node_list[i + 1])
            mode = edge_data.get("mode", "walk") if edge_data else "walk"
            if not seq or seq[-1] != mode:
                seq.append(mode)
        return tuple(seq)

    def k_shortest_paths(self, source_lat, source_lon, dest_lat, dest_lon,
                          k=5, departure_hour=10, departure_day=0):
        """Find top k structurally diverse shortest multimodal paths."""
        if self.G is None:
            raise ValueError("Engine not loaded")

        source_id, s_dist = self.get_nearest_node(source_lat, source_lon)
        dest_id, d_dist = self.get_nearest_node(dest_lat, dest_lon)

        # Max ~1.5km walk to nearest node
        if s_dist > 0.015 or d_dist > 0.015:
            return []

        G_simple = self._build_simple_graph(departure_hour, departure_day)

        try:
            diverse_paths = []
            accepted_transit_sets = []
            
            # Penalized graph copy for diverse routing
            G_penalized = G_simple.copy()

            # We will try up to k*4 times to find diverse paths
            for attempt in range(k * 4):
                try:
                    path = nx.shortest_path(G_penalized, source=source_id, target=dest_id, weight="dynamic_time")
                except nx.NetworkXNoPath:
                    break

                # Check diversity
                path_set = set(path)
                is_diverse = True
                
                for existing_path in accepted_transit_sets:
                    overlap = len(path_set & existing_path) / max(len(path_set | existing_path), 1)
                    if overlap > 0.80:
                        is_diverse = False
                        break

                if is_diverse:
                    diverse_paths.append(path)
                    accepted_transit_sets.append(path_set)

                if len(diverse_paths) >= k:
                    break
                    
                # Penalize edges of this path globally to push the next search to alternate routes
                for u, v in zip(path[:-1], path[1:]):
                    if G_penalized.has_edge(u, v):
                        # Penalize time by 50% to encourage different path next iteration
                        G_penalized[u][v]["dynamic_time"] = G_penalized[u][v].get("dynamic_time", 1.0) * 1.5

            return [self._format_path(p, G_simple) for p in diverse_paths]
        except Exception:
            return []

    def _format_path(self, node_list, G_simple):
        """Convert raw node list into structured route data."""
        legs = []
        path_distance = 0.0

        for i in range(len(node_list) - 1):
            n1, n2 = node_list[i], node_list[i + 1]
            edge_data = G_simple.get_edge_data(n1, n2)

            leg = {
                "from_node": dict(self.G.nodes[n1]),
                "to_node": dict(self.G.nodes[n2]),
                "mode": edge_data.get("mode", "walk"),
                "length_m": edge_data.get("length_m", 0.0),
                "line": edge_data.get("line", ""),
            }
            path_distance += leg["length_m"]
            legs.append(leg)

        return {
            "legs": legs,
            "total_distance_m": path_distance,
            "transfers": self._count_transfers(legs),
        }

    def _count_transfers(self, legs):
        """Count transfers between distinct transit lines or modes."""
        transfers = 0
        last_transit_leg = None
        for leg in legs:
            mode = leg["mode"]
            if mode in ("bus", "metro"):
                if last_transit_leg is not None:
                    # Transfer if modes differ, or if same mode but different/empty lines
                    same_line = False
                    if last_transit_leg.get("line") and leg.get("line"):
                        same_line = (last_transit_leg["line"] == leg["line"])
                    
                    if mode != last_transit_leg["mode"] or not same_line:
                        transfers += 1
                last_transit_leg = leg
        return transfers


# Singleton
engine = RouteEngine()
