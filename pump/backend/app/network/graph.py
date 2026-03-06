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

    def k_shortest_paths(self, source_lat, source_lon, dest_lat, dest_lon,
                          k=5, departure_hour=10, departure_day=0):
        """Find top k shortest multimodal paths using Yen's algorithm."""
        if self.G is None:
            raise ValueError("Engine not loaded")

        source_id, s_dist = self.get_nearest_node(source_lat, source_lon)
        dest_id, d_dist = self.get_nearest_node(dest_lat, dest_lon)

        # Max ~1.5km walk to nearest node
        if s_dist > 0.015 or d_dist > 0.015:
            return []

        G_simple = self._build_simple_graph(departure_hour, departure_day)

        try:
            paths_gen = nx.shortest_simple_paths(
                G_simple, source=source_id, target=dest_id, weight="dynamic_time"
            )
            top_k = []
            for path in islice(paths_gen, k):
                top_k.append(self._format_path(path, G_simple))
            return top_k
        except nx.NetworkXNoPath:
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
        transfers = 0
        if not legs:
            return 0
        current_mode = legs[0]["mode"]
        for leg in legs[1:]:
            if leg["mode"] != current_mode and current_mode != "walk":
                if leg["mode"] in ("bus", "metro"):
                    transfers += 1
            current_mode = leg["mode"]
        return transfers


# Singleton
engine = RouteEngine()
