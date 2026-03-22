"""
GTFS Loader for MARG Transit Integration.

Parses standard GTFS text files and builds in-memory lookup structures
for graph integration:
  - stops: stop_id -> {name, lat, lon}
  - routes: route_id -> {short_name, long_name}
  - trips: trip_id -> {route_id, direction_id, headsign}
  - stop_sequences: trip_id -> [(stop_id, arrival_sec, departure_sec, seq), ...]
"""

import csv
import os
from pathlib import Path
from collections import defaultdict
from typing import Optional

GTFS_DIR = Path(os.getenv(
    "GTFS_DATA_DIR",
    "/home/jayant/gitgud/marg/marg/pump/data/gtfs"
))


def _time_to_seconds(time_str: str) -> int:
    """Convert HH:MM:SS to seconds since midnight. Handles >24h for overnight trips."""
    parts = time_str.strip().split(":")
    return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])


class GTFSData:
    """Holds parsed GTFS data in memory."""

    def __init__(self):
        self.stops = {}           # stop_id -> {"name", "lat", "lon"}
        self.routes = {}          # route_id -> {"short_name", "long_name"}
        self.trips = {}           # trip_id -> {"route_id", "direction_id", "headsign"}
        self.stop_sequences = {}  # trip_id -> sorted list of (stop_id, arrival_sec, depart_sec, seq)
        self.route_trips = defaultdict(list)  # route_id -> [trip_id, ...]

    def load(self, gtfs_dir: Optional[Path] = None):
        if gtfs_dir is None:
            gtfs_dir = GTFS_DIR

        print(f"[GTFS] Loading from {gtfs_dir}")
        self._load_stops(gtfs_dir / "stops.txt")
        self._load_routes(gtfs_dir / "routes.txt")
        self._load_trips(gtfs_dir / "trips.txt")
        self._load_stop_times(gtfs_dir / "stop_times.txt")
        print(f"[GTFS] Loaded {len(self.stops)} stops, {len(self.routes)} routes, "
              f"{len(self.trips)} trips, {len(self.stop_sequences)} sequences")

    def _load_stops(self, path: Path):
        with open(path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                self.stops[row["stop_id"]] = {
                    "name": row["stop_name"],
                    "lat": float(row["stop_lat"]),
                    "lon": float(row["stop_lon"]),
                }

    def _load_routes(self, path: Path):
        with open(path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                self.routes[row["route_id"]] = {
                    "short_name": row.get("route_short_name", ""),
                    "long_name": row.get("route_long_name", ""),
                    "route_type": str(row.get("route_type", "3")), # 3=bus, 1=metro
                }

    def _load_trips(self, path: Path):
        with open(path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                tid = row["trip_id"]
                rid = row["route_id"]
                self.trips[tid] = {
                    "route_id": rid,
                    "direction_id": row.get("direction_id", "0"),
                    "headsign": row.get("trip_headsign", ""),
                }
                self.route_trips[rid].append(tid)

    def _load_stop_times(self, path: Path):
        # Read all stop_times grouped by trip_id
        raw = defaultdict(list)
        with open(path, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            header = next(reader)
            t_idx = header.index("trip_id")
            s_idx = header.index("stop_id")
            a_idx = header.index("arrival_time")
            d_idx = header.index("departure_time")
            seq_idx = header.index("stop_sequence")
            
            for row in reader:
                tid = row[t_idx]
                arr, dep = row[a_idx].strip(), row[d_idx].strip()
                
                if len(arr) == 8:
                    a_sec = int(arr[0:2]) * 3600 + int(arr[3:5]) * 60 + int(arr[6:8])
                else:
                    ap = arr.split(":")
                    a_sec = int(ap[0]) * 3600 + int(ap[1]) * 60 + int(ap[2])
                    
                if len(dep) == 8:
                    d_sec = int(dep[0:2]) * 3600 + int(dep[3:5]) * 60 + int(dep[6:8])
                else:
                    dp = dep.split(":")
                    d_sec = int(dp[0]) * 3600 + int(dp[1]) * 60 + int(dp[2])
                    
                raw[tid].append((
                    row[s_idx],
                    a_sec,
                    d_sec,
                    int(row[seq_idx]),
                ))

        # Sort each trip's stops by sequence number
        for tid, entries in raw.items():
            self.stop_sequences[tid] = sorted(entries, key=lambda x: x[3])

    def get_unique_edges(self):
        """
        Extract unique directed bus edges across ALL trips.

        Returns a dict keyed by (from_stop_id, to_stop_id) with value:
          {
            "min_travel_time": float (seconds),
            "route_ids": set of route_ids serving this edge,
            "route_names": set of short names,
            "trip_count": int
          }

        This deduplicates across the 55K+ trips so the graph builder
        only adds one edge per unique stop pair, with aggregated metadata.
        """
        edges: dict = {}

        for tid, seq in self.stop_sequences.items():
            route_id = self.trips[tid]["route_id"]
            route_info = self.routes.get(route_id, {})
            route_name = route_info.get("short_name", "")
            route_type = route_info.get("route_type", "3")
            mode = "metro" if route_type in ("1", "2") else "bus"

            for i in range(len(seq) - 1):
                s1_id, _, s1_depart, _ = seq[i]
                s2_id, s2_arrive, _, _ = seq[i + 1]

                travel_time = max(s2_arrive - s1_depart, 10)  # minimum 10s

                key = (s1_id, s2_id)
                if key not in edges:
                    edges[key] = {
                        "min_travel_time": travel_time,
                        "route_ids": set(),
                        "route_names": set(),
                        "trip_count": 0,
                        "mode": mode,
                    }

                edge = edges[key]
                edge["min_travel_time"] = min(edge["min_travel_time"], travel_time)
                edge["route_ids"].add(route_id)
                edge["route_names"].add(route_name)
                edge["trip_count"] += 1

        return edges


# Singleton
gtfs_data = GTFSData()
