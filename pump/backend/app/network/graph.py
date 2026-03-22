import pickle
from pathlib import Path
import networkx as nx
import os
import math
import logging
import time
from scipy.spatial import KDTree
from app.transit.raptor import raptor_engine

logger = logging.getLogger(__name__)

ENABLE_RAPTOR = True
DATA_DIR = Path(os.getenv("PUMP_DATA_DIR", "/home/jayant/gitgud/marg/marg/pump/data/processed"))
GRAPH_PATH = DATA_DIR / "multimodal_graph.gpickle"
KDTREE_PATH = DATA_DIR / "spatial_index.pkl"

# Transfer penalty: added once when boarding a new bus (not for continuing same route)
BUS_BOARDING_PENALTY_SEC = 420  # 7 min average wait


def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))


class RouteEngine:
    def __init__(self):
        self.G = None
        self.tree = None
        self.node_ids = None
        self.coords = None
        self.routing_available = False
        self.load_status = {
            "graph": False,
            "kdtree": False,
        }
        self.load_time_s = 0.0

    def load(self):
        t0 = time.time()
        logger.info("Loading Route Engine Graph and KD-Tree...")

        # --- Load multimodal graph ---
        try:
            with open(GRAPH_PATH, "rb") as f:
                multi_G = pickle.load(f)
            logger.info(f"  Raw graph loaded: {len(multi_G.nodes)} nodes, {len(multi_G.edges)} edges")
        except FileNotFoundError:
            logger.error(f"[RouteEngine] Graph file not found: {GRAPH_PATH}")
            self.routing_available = False
            return
        except Exception as e:
            logger.error(f"[RouteEngine] Failed to load graph: {e}")
            self.routing_available = False
            return

        # --- Load spatial index ---
        try:
            with open(KDTREE_PATH, "rb") as f:
                index_data = pickle.load(f)
                self.tree = index_data["tree"]
                self.node_ids = index_data["node_ids"]
                self.coords = index_data["coords"]
            self.load_status["kdtree"] = True
            logger.info(f"  KD-Tree loaded: {len(self.node_ids)} indexed nodes")
        except FileNotFoundError:
            logger.error(f"[RouteEngine] Spatial index not found: {KDTREE_PATH}")
            self.routing_available = False
            return
        except Exception as e:
            logger.error(f"[RouteEngine] Failed to load spatial index: {e}")
            self.routing_available = False
            return

        # Convert MultiDiGraph → simple DiGraph by keeping min-weight edge per pair
        # This is required because nx.astar_path doesn't support MultiDiGraph
        self.G = nx.DiGraph()
        for n, data in multi_G.nodes(data=True):
            self.G.add_node(n, **data)
        for u, v, data in multi_G.edges(data=True):
            tt = float(data.get("travel_time", 9999))
            if self.G.has_edge(u, v):
                if tt < self.G[u][v].get("travel_time", 9999):
                    self.G[u][v].update(data)
                    self.G[u][v]["travel_time"] = tt
            else:
                self.G.add_edge(u, v, **data)
                self.G[u][v]["travel_time"] = tt

        self.load_status["graph"] = True
        del multi_G

        # Count edge types for debug logging
        modes = {}
        for u, v, d in self.G.edges(data=True):
            m = d.get("mode", "unknown")
            modes[m] = modes.get(m, 0) + 1

        self.load_time_s = round(time.time() - t0, 2)
        self.routing_available = True
        logger.info(f"Loaded {len(self.G.nodes)} nodes, {len(self.G.edges)} edges (simplified DiGraph).")
        logger.info(f"  Edge modes: {modes}")
        logger.info(f"  Engine loaded in {self.load_time_s}s")
        # Also print for uvicorn stdout
        print(f"Loaded {len(self.G.nodes)} nodes, {len(self.G.edges)} edges (simplified DiGraph).")
        print(f"  Edge modes: {modes}")
        print(f"  Engine loaded in {self.load_time_s}s")

        # --- Upgrade 3: Eagerly build RAPTOR so first request is fast ---
        if ENABLE_RAPTOR:
            try:
                t_raptor = time.time()
                raptor_engine.build()
                raptor_time = round(time.time() - t_raptor, 2)
                logger.info(f"  RAPTOR built in {raptor_time}s")
                print(f"  RAPTOR built in {raptor_time}s")
            except Exception as e:
                logger.warning(f"[RouteEngine] RAPTOR build failed (non-fatal): {e}")
                print(f"  RAPTOR build failed (non-fatal): {e}")

    def get_nearest_node(self, lat, lon):
        dist, idx = self.tree.query([lat, lon])
        return self.node_ids[idx], dist

    def _heuristic(self, u, v):
        """Admissible heuristic for A* based on max network speed (80 km/h = 22.2 m/s)."""
        node_u = self.G.nodes[u]
        node_v = self.G.nodes[v]
        if 'lat' not in node_u or 'lat' not in node_v:
            return 0
        dist = haversine(node_u['lat'], node_u['lon'], node_v['lat'], node_v['lon'])
        return dist / 22.2

    def k_shortest_paths(self, source_lat, source_lon, dest_lat, dest_lon,
                          k=5, departure_hour=10, departure_day=0,
                          preference="fastest", mode_preferences=None):
        """
        Find k optimal routes using A* search.

        preference: "fastest" (default) or "least_walking"
        """
        if not self.routing_available:
            raise ValueError("Routing engine not available — data files missing or corrupt")

        source_id, s_dist = self.get_nearest_node(source_lat, source_lon)
        dest_id, d_dist = self.get_nearest_node(dest_lat, dest_lon)
        
        # --- PHASE 4 & 7: RAPTOR INTEGRATION WITH A* FALLBACK ---
        if ENABLE_RAPTOR and self.tree is not None:
            try:
                def get_nearby_stops(lat, lon, r_deg=0.015):
                    # 0.015 degrees is roughly 1.5km
                    indices = self.tree.query_ball_point([lat, lon], r=r_deg)
                    stops = {}
                    for idx in indices:
                        n_id = str(self.node_ids[idx])
                        if n_id.startswith("gtfs_"):
                            # Haversine distance for walk time
                            n_lat, n_lon = self.coords[idx]
                            # Fast approximate distance
                            dist_m = haversine(lat, lon, n_lat, n_lon)
                            walk_sec = dist_m / 1.38 # 5 km/h
                            stops[n_id[5:]] = walk_sec
                    return stops
                    
                source_stops = get_nearby_stops(source_lat, source_lon)
                dest_stops = get_nearby_stops(dest_lat, dest_lon)
                
                # Convert departure_hour to seconds since midnight
                departure_sec = departure_hour * 3600
                
                if source_stops and dest_stops:
                    raptor_result = raptor_engine.route(source_stops, dest_stops, departure_sec, mode_preferences=mode_preferences)
                    if raptor_result:
                        print("[ROUTER] Successfully used RAPTOR engine.")
                        routes = [raptor_result]
                        
                        # --- PHASE 3 IMPROVEMENT: Map-Match legs to real street geometries ---
                        try:
                            import networkx as nx
                            for raptor_result in routes:
                                for leg in raptor_result.get("legs", []):
                                    try:
                                        lat1, lon1 = leg["from_node"].get("lat", 0.0), leg["from_node"].get("lon", 0.0)
                                        lat2, lon2 = leg["to_node"].get("lat", 0.0), leg["to_node"].get("lon", 0.0)
                                        
                                        if leg["from_node"]["name"] == "Origin":
                                            n1 = source_id
                                        else:
                                            n1, _ = self.get_nearest_node(lat1, lon1)
                                            
                                        if leg["to_node"]["name"] == "Destination":
                                            n2 = dest_id
                                        else:
                                            n2, _ = self.get_nearest_node(lat2, lon2)
                                            
                                        w = "length_m" if leg["mode"] == "walk" else "travel_time"
                                        path_nodes = nx.shortest_path(self.G, n1, n2, weight=w)
                                        
                                        geom = []
                                        for i in range(len(path_nodes)-1):
                                            u, v = path_nodes[i], path_nodes[i+1]
                                            edge = self.G[u][v]
                                            if "geometry" in edge:
                                                # shapely coords are (lon, lat) -> (lat, lon)
                                                for lon, lat in edge["geometry"].coords:
                                                    geom.append([lat, lon])
                                            else:
                                                n_u, n_v = self.G.nodes[u], self.G.nodes[v]
                                                if 'lat' in n_u and 'lat' in n_v:
                                                    geom.append([n_u['lat'], n_u['lon']])
                                                    geom.append([n_v['lat'], n_v['lon']])
                                                    
                                        if geom:
                                            clean_geom = [geom[0]]
                                            for pt in geom[1:]:
                                                if pt != clean_geom[-1]:
                                                    clean_geom.append(pt)
                                            leg["path"] = clean_geom
                                    except Exception as inner_e:
                                        pass
                        except Exception as e:
                            print(f"[GEOM] Failed to inject map geometries: {e}")
                            
                        # If a specific mode preference is requested, fall through to A* to generate an alternative!
                        if mode_preferences and (mode_preferences.get("prefer_metro") or mode_preferences.get("prefer_bus")):
                            pass # Let A* run to get a second multimodal route
                        else:
                            return routes
                        
            except Exception as e:
                print(f"[ROUTER] RAPTOR failed: {e}")
                
        # Initialize routes array if RAPTOR wasn't enabled or failed
        if 'routes' not in locals():
            routes = []

        if s_dist > 0.045 or d_dist > 0.045:
            raise ValueError("Location too far from transit network.")

        import time
        import networkx as nx
        try:
            edge_penalties = {}
            start_time = time.time()
            
            for _ in range(k):
                if time.time() - start_time > 10.0:
                    print("[ROUTER] A* timeout. Returning current routes.")
                    break
                    
                node_list = self._run_astar(source_id, dest_id, mode_preferences, preference, edge_penalties)
                if not node_list:
                    break
                    
                a_star_route = self._format_path(node_list)
                
                # Extract geometry natively
                for leg in a_star_route.get("legs", []):
                    try:
                        lat1, lon1 = leg["from_node"].get("lat", 0.0), leg["from_node"].get("lon", 0.0)
                        lat2, lon2 = leg["to_node"].get("lat", 0.0), leg["to_node"].get("lon", 0.0)
                        n1, _ = self.get_nearest_node(lat1, lon1)
                        n2, _ = self.get_nearest_node(lat2, lon2)
                        w = "length_m" if leg["mode"] == "walk" else "travel_time"
                        path_nodes = nx.shortest_path(self.G, n1, n2, weight=w)
                        geom = []
                        for i in range(len(path_nodes)-1):
                            u, v = path_nodes[i], path_nodes[i+1]
                            edge = self.G[u][v]
                            if "geometry" in edge:
                                for lon, lat in edge["geometry"].coords:
                                    geom.append([lat, lon])
                            else:
                                n_u, n_v = self.G.nodes[u], self.G.nodes[v]
                                if 'lat' in n_u and 'lat' in n_v:
                                    geom.append([n_u['lat'], n_u['lon']])
                                    geom.append([n_v['lat'], n_v['lon']])
                        if geom:
                            clean_geom = [geom[0]]
                            for pt in geom[1:]:
                                if pt != clean_geom[-1]: clean_geom.append(pt)
                            leg["path"] = clean_geom
                    except Exception:
                        pass
                
                # Check diversity
                if not routes or not self._are_too_similar(routes, a_star_route):
                    routes.append(a_star_route)
                    print(f"[ROUTER] Added A* alternative. Total routes: {len(routes)}")
                    
                # Penalize edges of this path to force Yens algorithm diversity
                for i in range(len(node_list) - 1):
                    u, v = node_list[i], node_list[i+1]
                    edge_penalties[(u, v)] = edge_penalties.get((u, v), 1.0) * 10.0

            return routes
            
        except Exception as e:
            print(f"Routing error: {e}")
            import traceback
            traceback.print_exc()
            return routes if 'routes' in locals() else []

    def _run_astar(self, source_id, dest_id, mode_preferences, preference, edge_penalties):
        import heapq
        import time
        TRANSFER_PENALTY = 300
        queue = [(0, 0, source_id, None)]
        min_g_score = {(source_id, None): 0}
        came_from = {}
        final_state = None
        start_time = time.time()

        while queue:
            if time.time() - start_time > 5.0:
                break
                
            f, g, u, current_route = heapq.heappop(queue)
            
            if u == dest_id:
                final_state = (u, current_route)
                break
                
            if g > min_g_score.get((u, current_route), float('inf')):
                continue
                
            for v, edge_data in self.G[u].items():
                mode = edge_data.get("mode", "walk")
                next_route = None
                
                edge_cost_multiplier = 1.0
                if mode_preferences:
                    if mode == "bus" and mode_preferences.get("prefer_metro"):
                        edge_cost_multiplier *= 1.5
                    elif mode == "metro" and mode_preferences.get("prefer_bus"):
                        edge_cost_multiplier *= 1.5
                    elif mode == "walk" and mode_preferences.get("avoid_walking"):
                        edge_cost_multiplier *= 2.0
                
                if mode in ("road", "walk"):
                    walk_time = float(edge_data.get("length_m", 0.0)) / 1.38
                    edge_cost = walk_time * 3.0 if preference == "least_walking" else walk_time
                else:
                    edge_cost = float(edge_data.get("travel_time", 9999))
                    if mode == "bus":
                        next_route = tuple(sorted(edge_data.get("route_ids", [])))
                    elif mode == "metro":
                        next_route = (edge_data.get("line", ""),)
                        
                edge_cost *= edge_cost_multiplier
                edge_cost *= edge_penalties.get((u, v), 1.0)

                penalty = 0
                if mode in ("bus", "metro"):
                    if current_route is not None:
                        if not set(current_route).intersection(set(next_route)):
                            penalty = TRANSFER_PENALTY
                    else:
                        penalty = TRANSFER_PENALTY / 2
                        
                new_g = g + edge_cost + penalty
                h = self._heuristic(v, dest_id)
                next_state = (v, next_route)
                
                if new_g < min_g_score.get(next_state, float('inf')):
                    min_g_score[next_state] = new_g
                    came_from[next_state] = (u, current_route)
                    heapq.heappush(queue, (new_g + h, new_g, v, next_route))
                    
        if final_state is None:
            return None
            
        node_list = []
        curr_s = final_state
        while curr_s in came_from:
            node_list.append(curr_s[0])
            curr_s = came_from[curr_s]
        node_list.append(curr_s[0])
        node_list.reverse()
        return node_list

    def _are_too_similar(self, existing_routes, new_route, threshold=0.8):
        new_nodes = set()
        for leg in new_route.get("legs", []):
            new_nodes.add(leg.get("from_node", {}).get("name"))
            new_nodes.add(leg.get("to_node", {}).get("name"))
            
        for ext in existing_routes:
            ext_nodes = set()
            for leg in ext.get("legs", []):
                ext_nodes.add(leg.get("from_node", {}).get("name"))
                ext_nodes.add(leg.get("to_node", {}).get("name"))
                
            intersection = new_nodes.intersection(ext_nodes)
            overlap = len(intersection) / max(len(new_nodes), 1)
            
            if overlap > threshold and ext.get("transfers") == new_route.get("transfers"):
                return True
        return False

    def _format_path(self, node_list):
        """Convert raw node list into structured route data with smart leg merging."""
        raw_legs = []
        path_distance = 0.0

        for i in range(len(node_list) - 1):
            n1, n2 = node_list[i], node_list[i + 1]
            edge_data = self.G[n1][n2]

            mode = edge_data.get("mode", "walk")
            display_mode = "walk" if mode == "road" else mode
            
            # Recalculate realistic travel time for display
            length_m = float(edge_data.get("length_m", 0.0))
            if mode in ("road", "walk"):
                leg_travel_time = length_m / 1.38
            else:
                leg_travel_time = float(edge_data.get("travel_time", 0.0))

            leg = {
                "from_node": dict(self.G.nodes[n1]),
                "to_node": dict(self.G.nodes[n2]),
                "mode": display_mode,
                "length_m": length_m,
                "line": edge_data.get("line", ""),
                "travel_time": leg_travel_time,
                # Carry route metadata for bus legs to enable smart merging
                "route_ids": edge_data.get("route_ids", []),
                "route_names": edge_data.get("route_names", []),
            }
            path_distance += leg["length_m"]
            raw_legs.append(leg)

        # Smart merge: collapse consecutive legs of the same mode
        # For bus legs, only merge if they share at least one common route_id
        # (meaning the passenger can stay on the same bus — NOT a transfer)
        merged_legs = []
        for leg in raw_legs:
            if not merged_legs:
                merged_legs.append(leg)
                continue

            prev = merged_legs[-1]

            # Walk/road merging: always merge consecutive walk segments
            if leg["mode"] == "walk" and prev["mode"] == "walk":
                prev["to_node"] = leg["to_node"]
                prev["length_m"] += leg["length_m"]
                prev["travel_time"] += leg["travel_time"]
                continue

            # Bus merging: merge ONLY if they share a common route_id
            # This is the critical logic: riding the same bus through multiple
            # stops is NOT a transfer. The bus just continues.
            if leg["mode"] == "bus" and prev["mode"] == "bus":
                prev_routes = set(prev.get("route_ids", []))
                curr_routes = set(leg.get("route_ids", []))
                shared = prev_routes & curr_routes

                if shared:
                    # Same bus route — merge (passenger stays on the bus)
                    prev["to_node"] = leg["to_node"]
                    prev["length_m"] += leg["length_m"]
                    prev["travel_time"] += leg["travel_time"]
                    # Narrow down to only the shared routes
                    prev["route_ids"] = list(shared)
                    prev["route_names"] = [
                        n for n in prev.get("route_names", [])
                        if any(rid in shared for rid in prev_routes)
                    ] or leg.get("route_names", [])
                    continue

            # Different mode or different bus route — new leg
            merged_legs.append(leg)

        transfers = self._count_transfers(merged_legs)
        # 300 seconds penalty per transfer
        total_time = sum(leg["travel_time"] for leg in merged_legs) + (transfers * 300)

        # Map to phase 9 format
        segments = []
        for leg in merged_legs:
            segments.append({
                "mode": leg["mode"],
                "route_id": leg.get("route_ids", [None])[0] if leg.get("route_ids") else None,
                "from": leg["from_node"].get("name", "Road"),
                "to": leg["to_node"].get("name", "Road"),
                "duration": leg["travel_time"]
            })

        return {
            "legs": merged_legs,                   # Legacy UI API
            "segments": segments,                  # New Phase 9 format
            "total_distance_m": path_distance,     # Legacy UI API
            "total_time_s": total_time,            # Legacy UI API
            "total_time": total_time,              # New Phase 9 format
            "transfers": transfers,                # Shared API
        }

    def _count_transfers(self, legs):
        """
        Count transfers properly: every distinct boarding event counts as 1 transit ride.
        Transfers = (total boardings) - 1. Walking breaks the transit chain.
        """
        boardings = 0
        last_transit_routes = None

        for leg in legs:
            mode = leg["mode"]
            if mode in ("bus", "metro"):
                curr_routes = set(leg.get("route_ids", [])) if mode == "bus" else {leg.get("line", "")}
                
                if last_transit_routes is None:
                    # Fresh boarding (from start or after walking)
                    boardings += 1
                else:
                    # Direct consecutive transfer between transit legs
                    if not (last_transit_routes & curr_routes):
                        boardings += 1
                        
                last_transit_routes = curr_routes
            else:
                # Walk segment breaks the transit chain completely
                last_transit_routes = None
                
        return max(0, boardings - 1)


# Singleton
engine = RouteEngine()
