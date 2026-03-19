# MARG Routing & Search Upgrade

## What Was Broken & Why
1. **No Real Road Network**: The core issue with the previous routing engine was that it completely ignored the existing OSM road network dataset (`osm_pune_roads.gpickle`). Instead, the graph compiler `build_graph.py` linked bus stops and metro stations directly to their k-nearest neighbors using crow-fly (straight line) geographic distances. This meant routes completely ignored roads, one-way streets, highways, and bodies of water, resulting in invalid straight-line routing across buildings.
2. **Brittle Search API**: The search endpoint depended 100% on the external OpenStreetMap Nominatim API, which aggressively filtered out local aliases (like "SIT", "Dagduseth", "Lal Deval") and failed to match the exact names of the 5,600+ bus/metro stops already in our local dataset.
3. **ML Travel Time Reliance**: Route lengths were measured in meters on fake edges, so the ML Random Forest model was incorrectly guessing travel times without any understanding of road speeds, traffic, or highway access.

## What Was Changed
1. **OSMnx Road Integration**: A new script `build_osm_graph.py` automatically downloads the drivable road network for Pune and converts it into a graph with default speed limits mapped to OSM highway types (e.g. `motorway` at 80 km/h, `residential` at 20 km/h).
2. **Transit-Road Fusion**: The core `build_graph.py` script now merges the 5,600+ bus stops and 49 metro stations into the actual OSM road network by snapping them to the nearest valid roads via pedestrian links. The KD-Tree now indexes *all* 89,000+ nodes, allowing users to start/end routing at any exact geographic point on a street.
3. **A* Pathfinding**: The routing algorithm was upgraded from a greedy distance-based router to a proper A* Search in `graph.py` using the Haversine distance divided by the network's max speed (80 km/h) as an admissible heuristic. 
4. **Local Search Engine**: Added a fast offline fuzzy search index (`search.py`) using `rapidfuzz` that pre-loads all ~5,600 transit stops and local landmarks (e.g. Vetal Tekdi, FC Road) serving as an instant cache before hitting Nominatim.
5. **Deterministic Travel Times**: The ranker now calculates trip duration using real vehicle speeds (`duration = distance / speed_limit`) attached directly from OSM instead of the opaque Random Forest model.

## Datasets Used
- **osm_pune_roads.gpickle** (Generated from osmnx Overpass `drive` area query)
- `bus_stops.json`
- `metro_stations.json`
- `metro_edges.csv`

## Known Limitations
- **Bus Sequence Data**: The `bus_routes.json` file ONLY contains route summaries, not actual stop sequences (e.g., GTFS sequence arrays). Because we don't know the exact sequence of stops for a given bus route, bus trips have been disabled in the graph builder and users are instead routed directly over the road network ("walk"/"drive"). Once GTFS sequences are available, explicit bus edges can be overlaid on the road graph.
