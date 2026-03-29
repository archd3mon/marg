"""
RAPTOR (Round-Based Public Transit Routing) Algorithm Implementation.
Provides exact timetable-based routing optimizing for arrival time and transfers.
"""

import math
from collections import defaultdict
from typing import List, Dict, Set, Tuple

from app.transit.gtfs_loader import GTFSData, gtfs_data

class RaptorEngine:
    def __init__(self, gtfs: GTFSData):
        self.gtfs = gtfs
        self.patterns = {}               # pattern_id -> tuple of stop_ids
        self.pattern_trips = defaultdict(list) # pattern_id -> list of trip_ids
        self.stop_to_patterns = defaultdict(set) # stop_id -> set of pattern_ids
        self.trip_stop_times = {}        # trip_id -> list of (arrival_sec, depart_sec)
        
        self.footpaths = defaultdict(list) # stop_id -> list of (target_stop_id, walk_time_sec)
        self._is_built = False
        
    def build(self):
        """Prepare RAPTOR optimized data structures from raw GTFS."""
        if self._is_built:
            return
            
        if not self.gtfs.stops:
            print("[RAPTOR] GTFS data not in memory, loading now...")
            self.gtfs.load()
            
        print("[RAPTOR] Building routing structures...")
        pattern_to_id = {}
        pid_counter = 0
        
        for tid, seq in self.gtfs.stop_sequences.items():
            stop_ids = tuple(s[0] for s in seq)
            if stop_ids not in pattern_to_id:
                pattern_to_id[stop_ids] = pid_counter
                self.patterns[pid_counter] = stop_ids
                
                for sid in stop_ids:
                    self.stop_to_patterns[sid].add(pid_counter)
                    
                pid_counter += 1
                
            pid = pattern_to_id[stop_ids]
            self.pattern_trips[pid].append(tid)
            self.trip_stop_times[tid] = [(s[1], s[2]) for s in seq]
            
        # Sort trips in each pattern by departure time at the first stop
        for pid, trips in self.pattern_trips.items():
            trips.sort(key=lambda tid: self.trip_stop_times[tid][0][1])

        # Pre-compute walk footpaths between close stations (e.g. < 200m)
        self._build_footpaths()
        
        self._is_built = True
        print(f"[RAPTOR] Built {len(self.patterns)} unique route patterns.")
        
    def _build_footpaths(self):
        """Build a simple footpath network between nearby stops using haversine."""
        def get_dist(lat1, lon1, lat2, lon2):
            import math
            R = 6371000
            phi1, phi2 = math.radians(lat1), math.radians(lat2)
            dphi = math.radians(lat2 - lat1)
            dlambda = math.radians(lon2 - lon1)
            a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
            return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))
            
        stops = list(self.gtfs.stops.items())
        count = 0
        for i in range(len(stops)):
            s1_id, s1_data = stops[i]
            for j in range(i + 1, len(stops)):
                s2_id, s2_data = stops[j]
                
                # Fast bounding box check to avoid expensive haversine
                if abs(s1_data["lat"] - s2_data["lat"]) > 0.005 or \
                   abs(s1_data["lon"] - s2_data["lon"]) > 0.005:
                    continue
                    
                dist_m = get_dist(s1_data["lat"], s1_data["lon"], s2_data["lat"], s2_data["lon"])
                
                if dist_m < 300: # 300m max transfer walk
                    walk_sec = dist_m / 1.38 # 5 km/h
                    self.footpaths[s1_id].append((s2_id, walk_sec))
                    self.footpaths[s2_id].append((s1_id, walk_sec))
                    count += 1
        print(f"[RAPTOR] Precomputed {count} interior footpaths between stops.")

    def find_earliest_trip(self, pid: int, stop_idx: int, min_depart_time: float) -> str:
        """Find the earliest trip on a pattern that departs after min_depart_time."""
        # Because pattern_trips are sorted by start time, we can binary search (or linear scan for small N)
        for tid in self.pattern_trips[pid]:
            # departure time is index 1 of the tuple
            if self.trip_stop_times[tid][stop_idx][1] >= min_depart_time:
                return tid
        return None

    def route(self, source_stops: Dict[str, float], dest_stops: Dict[str, float], 
              departure_time: float, max_transfers: int = 4, mode_preferences=None, banned_modes=None):
        """
        Run the RAPTOR algorithm.
        source_stops: dict of stop_id -> walk_time_from_origin
        dest_stops: dict of stop_id -> walk_time_to_destination
        """
        if not self._is_built:
            self.build()

        TRANSFER_PENALTY = 300 # 5 minutes
            
        # earliest_arrival[k][stop_id] = earliest arrival time
        earliest_arrival = [{} for _ in range(max_transfers + 2)]
        marked_stops = set()
        
        # journey pointers for traceback
        # pointers[k][stop_id] = (prev_stop, trip_id, board_stop, alight_time)
        pointers = [{} for _ in range(max_transfers + 2)]
        
        # Initialize round 0
        for stop_id, walk_time in source_stops.items():
            arr_time = departure_time + walk_time
            earliest_arrival[0][stop_id] = arr_time
            marked_stops.add(stop_id)
            pointers[0][stop_id] = ("ORIGIN", None, None, arr_time)
            
        best_overall_arrival = float('inf')
        
        for k in range(1, max_transfers + 2):
            # Copy previous round
            earliest_arrival[k] = earliest_arrival[k - 1].copy()
            pointers[k] = pointers[k - 1].copy()
            
            # Step 1: Accumulate routes serving marked stops
            Q = {} # pattern_id -> earliest marked stop index
            for p in marked_stops:
                for pid in self.stop_to_patterns.get(p, []):
                    stop_idx = self.patterns[pid].index(p)
                    if pid not in Q or stop_idx < Q[pid]:
                        Q[pid] = stop_idx
                        
            marked_stops.clear()
            
            # Step 2: Traverse each route
            for pid, start_idx in Q.items():
                if banned_modes:
                    sample_trip = self.pattern_trips[pid][0]
                    route_id = self.gtfs.trips[sample_trip]["route_id"]
                    route_type = self.gtfs.routes.get(route_id, {}).get("route_type", "3")
                    mode = "metro" if route_type in ("1", "2") else "bus"
                    if mode in banned_modes:
                        continue
                        
                pattern_stops = self.patterns[pid]
                current_trip = None
                board_stop = None
                
                for i in range(start_idx, len(pattern_stops)):
                    p = pattern_stops[i]
                    
                    # 2a: Update earliest arrival at p if we are on a trip
                    if current_trip is not None:
                        arr_time = self.trip_stop_times[current_trip][i][0]
                        # Apply transfer penalty dynamically? RAPTOR inherently favors fewer rounds.
                        # But to strictly penalize, we add a flat wait buffer before boarding.
                        if arr_time < earliest_arrival[k].get(p, float('inf')) and arr_time < best_overall_arrival:
                            earliest_arrival[k][p] = arr_time
                            pointers[k][p] = (board_stop, current_trip, board_stop, arr_time)
                            marked_stops.add(p)
                            
                    # 2b: See if we can catch an EARLIER trip from p
                    earliest_start_possible = earliest_arrival[k-1].get(p, float('inf'))
                    # Enforce transfer penalty: you need TRANSFER_PENALTY seconds to switch buses 
                    # (Unless k=1, where you just walked from origin, so no penalty to board the first bus)
                    wait_buffer = TRANSFER_PENALTY if k > 1 else 0
                    
                    if earliest_start_possible + wait_buffer < float('inf'):
                        if current_trip is None or earliest_start_possible + wait_buffer <= self.trip_stop_times[current_trip][i][1]:
                            catchable_trip = self.find_earliest_trip(pid, i, earliest_start_possible + wait_buffer)
                            if catchable_trip:
                                current_trip = catchable_trip
                                board_stop = p
                                
            # Step 3: Footpaths (transfers)
            for p in list(marked_stops):
                for p_target, walk_time in self.footpaths.get(p, []):
                    new_time = earliest_arrival[k][p] + walk_time
                    if new_time < earliest_arrival[k].get(p_target, float('inf')) and new_time < best_overall_arrival:
                        earliest_arrival[k][p_target] = new_time
                        pointers[k][p_target] = (p, "WALK", p, new_time)
                        marked_stops.add(p_target)
                        
            # Check if destination is reached
            for dest_stop, dest_walk in dest_stops.items():
                if dest_stop in earliest_arrival[k]:
                    final_arrive = earliest_arrival[k][dest_stop] + dest_walk
                    if final_arrive < best_overall_arrival:
                        best_overall_arrival = final_arrive
                        
            if not marked_stops:
                break
                
        # Reconstruct exactly matching Phase 9 format
        return self._reconstruct_journey(pointers, dest_stops, earliest_arrival, departure_time)
        
    def _reconstruct_journey(self, pointers, dest_stops, earliest_arrival, departure_time):
        """Build the structured output segment list."""
        # Find best destination stop
        best_dest = None
        best_time = float('inf')
        best_k = 0
        
        for k, arrivals in enumerate(earliest_arrival):
            for dest_stop, dest_walk in dest_stops.items():
                if dest_stop in arrivals:
                    total_time = arrivals[dest_stop] + dest_walk
                    if total_time < best_time:
                        best_time = total_time
                        best_dest = dest_stop
                        best_k = k
                        
        if not best_dest:
            return None
            
        # Traceback
        curr_stop = best_dest
        curr_k = best_k
        events = []
        
        # Add final walk to destination
        walk_to_dest_time = dest_stops[best_dest]
        if walk_to_dest_time > 0:
            events.append({
                "mode": "walk",
                "route_id": None,
                "from": self.gtfs.stops[best_dest]["name"],
                "from_lat": self.gtfs.stops[best_dest]["lat"],
                "from_lon": self.gtfs.stops[best_dest]["lon"],
                "to": "Destination",
                "to_lat": self.gtfs.stops[best_dest]["lat"],
                "to_lon": self.gtfs.stops[best_dest]["lon"],
                "duration": walk_to_dest_time
            })
        
        while True:
            pointer = pointers[curr_k].get(curr_stop)
            if not pointer:
                break
                
            prev_stop, trip_id, board_stop, arr_time = pointer
            
            if prev_stop == "ORIGIN":
                walk_from_origin = arr_time - departure_time
                if walk_from_origin > 0:
                    events.append({
                        "mode": "walk",
                        "route_id": None,
                        "from": "Origin",
                        "from_lat": self.gtfs.stops[curr_stop]["lat"],
                        "from_lon": self.gtfs.stops[curr_stop]["lon"],
                        "to": self.gtfs.stops[curr_stop]["name"],
                        "to_lat": self.gtfs.stops[curr_stop]["lat"],
                        "to_lon": self.gtfs.stops[curr_stop]["lon"],
                        "duration": walk_from_origin
                    })
                break
                
            if trip_id == "WALK":
                walk_dur = earliest_arrival[curr_k][curr_stop] - earliest_arrival[curr_k][prev_stop]
                events.append({
                    "mode": "walk",
                    "route_id": None,
                    "from": self.gtfs.stops[prev_stop]["name"],
                    "from_lat": self.gtfs.stops[prev_stop]["lat"],
                    "from_lon": self.gtfs.stops[prev_stop]["lon"],
                    "to": self.gtfs.stops[curr_stop]["name"],
                    "to_lat": self.gtfs.stops[curr_stop]["lat"],
                    "to_lon": self.gtfs.stops[curr_stop]["lon"],
                    "duration": walk_dur
                })
                curr_stop = prev_stop
            else:
                route_id = self.gtfs.trips[trip_id]["route_id"]
                # Time spent on bus
                # Departure time at board_stop
                pid = next(k for k, v in self.patterns.items() if trip_id in self.pattern_trips[k])
                b_idx = self.patterns[pid].index(board_stop)
                a_idx = self.patterns[pid].index(curr_stop)
                
                depart_time = self.trip_stop_times[trip_id][b_idx][1]
                arrive_time = self.trip_stop_times[trip_id][a_idx][0]
                
                route_info = self.gtfs.routes.get(route_id, {})
                route_type = route_info.get("route_type", "3")
                mode = "metro" if route_type in ("1", "2") else "bus"
                
                events.append({
                    "mode": mode,
                    "route_id": route_id,
                    "trip_id": trip_id,
                    "from": self.gtfs.stops[board_stop]["name"],
                    "from_lat": self.gtfs.stops[board_stop]["lat"],
                    "from_lon": self.gtfs.stops[board_stop]["lon"],
                    "to": self.gtfs.stops[curr_stop]["name"],
                    "to_lat": self.gtfs.stops[curr_stop]["lat"],
                    "to_lon": self.gtfs.stops[curr_stop]["lon"],
                    "duration": arrive_time - depart_time
                })
                curr_stop = board_stop
                curr_k -= 1 # Using a trip consumes a transfer round!
                
        events.reverse()
        
        # Count transfers properly: only distinct vehicle boardings minus 1.
        # Consecutive bus/metro events with the same route_id are one boarding.
        # Walk legs break the transit chain and force a new boarding.
        boardings = 0
        last_route_id = None
        for e in events:
            if e["mode"] in ("bus", "metro"):
                curr_route = e.get("route_id")
                if last_route_id is None or curr_route != last_route_id:
                    boardings += 1
                last_route_id = curr_route
            else:
                # Walk breaks the chain
                last_route_id = None
        transfers = max(0, boardings - 1)
        
        # Backward compatibility for legacy UI and test_route.py
        legs = []
        for e in events:
            legs.append({
                "mode": e["mode"],
                "from_node": {"name": e["from"], "lat": e.get("from_lat", 0.0), "lon": e.get("from_lon", 0.0)},
                "to_node": {"name": e["to"], "lat": e.get("to_lat", 0.0), "lon": e.get("to_lon", 0.0)},
                "travel_time": e["duration"],
                "length_m": e["duration"] * 1.38 if e["mode"] == "walk" else e["duration"] * 5.0, # Dummy dist
                "route_names": [e.get("route_id")] if e.get("route_id") else []
            })
            
        return {
            "total_time": best_time - departure_time,
            "total_time_s": best_time - departure_time,
            "total_distance_m": sum(l["length_m"] for l in legs),
            "transfers": transfers,
            "legs": legs,
            "segments": events
        }

# Global singleton
raptor_engine = RaptorEngine(gtfs_data)
