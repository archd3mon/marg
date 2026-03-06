import json
import csv
from pathlib import Path

OUT_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/processed")
OUT_DIR.mkdir(parents=True, exist_ok=True)

# =============================================================================
# Pune Metro Station Data — Based on MAHA-METRO official map
# Phase 1: Purple Line (PCMC ↔ Swargate) — 14 stations, 11.45 km — OPERATIONAL
# Phase 2: Aqua Line (Vanaz ↔ Ramwadi) — 16 stations, 15.75 km — OPERATIONAL
# Phase 1A: Purple Extension (PCMC ↔ Bhakti Shakti) — 4 stations — UNDER CONSTRUCTION
# Phase 1B: Purple Extension (Swargate ↔ Katraj) — 3 stations — UNDER CONSTRUCTION
# Phase 2 Ext West: Aqua Extension (Vanaz ↔ Chandani Chowk) — 2 stations
# Phase 2 Ext East: Aqua Extension (Ramwadi ↔ Vitthalwadi) — 11 stations
# =============================================================================

# Civil Court is the interchange between Purple and Aqua lines.
# Nodes referencing the same station use the same ID so the graph engine connects them.

# --- PURPLE LINE (North-South: PCMC → Swargate) --- Phase 1 Operational
PURPLE_LINE = [
    {"id": "metro_pu_01", "name": "PCMC",                  "lat": 18.6281, "lon": 73.8053, "type": "metro_station", "line": "Purple", "order": 1},
    {"id": "metro_pu_02", "name": "Sant Tukaram Nagar",     "lat": 18.6175, "lon": 73.8098, "type": "metro_station", "line": "Purple", "order": 2},
    {"id": "metro_pu_03", "name": "Nashik Phata",           "lat": 18.6120, "lon": 73.8115, "type": "metro_station", "line": "Purple", "order": 3},
    {"id": "metro_pu_04", "name": "Kasarwadi",              "lat": 18.6025, "lon": 73.8178, "type": "metro_station", "line": "Purple", "order": 4},
    {"id": "metro_pu_05", "name": "Phugewadi",              "lat": 18.5907, "lon": 73.8245, "type": "metro_station", "line": "Purple", "order": 5},
    {"id": "metro_pu_06", "name": "Dapodi",                 "lat": 18.5805, "lon": 73.8315, "type": "metro_station", "line": "Purple", "order": 6},
    {"id": "metro_pu_07", "name": "Bopodi",                 "lat": 18.5695, "lon": 73.8375, "type": "metro_station", "line": "Purple", "order": 7},
    {"id": "metro_pu_08", "name": "Khadki",                 "lat": 18.5570, "lon": 73.8425, "type": "metro_station", "line": "Purple", "order": 8},
    {"id": "metro_pu_09", "name": "Range Hill",             "lat": 18.5465, "lon": 73.8450, "type": "metro_station", "line": "Purple", "order": 9},
    {"id": "metro_pu_10", "name": "Shivaji Nagar",          "lat": 18.5325, "lon": 73.8495, "type": "metro_station", "line": "Purple", "order": 10},
    {"id": "metro_ix_01", "name": "Civil Court",            "lat": 18.5280, "lon": 73.8555, "type": "metro_station", "line": "Purple/Aqua", "order": 11},
    {"id": "metro_pu_12", "name": "Budhwar Peth",           "lat": 18.5190, "lon": 73.8560, "type": "metro_station", "line": "Purple", "order": 12},
    {"id": "metro_pu_13", "name": "Mandai",                 "lat": 18.5120, "lon": 73.8555, "type": "metro_station", "line": "Purple", "order": 13},
    {"id": "metro_pu_14", "name": "Swargate",               "lat": 18.5015, "lon": 73.8565, "type": "metro_station", "line": "Purple", "order": 14},
]

# --- AQUA LINE (East-West: Vanaz → Ramwadi) --- Phase 2 Operational
AQUA_LINE = [
    {"id": "metro_aq_01", "name": "Vanaz",                       "lat": 18.5133, "lon": 73.8050, "type": "metro_station", "line": "Aqua", "order": 1},
    {"id": "metro_aq_02", "name": "Anand Nagar",                 "lat": 18.5138, "lon": 73.8118, "type": "metro_station", "line": "Aqua", "order": 2},
    {"id": "metro_aq_03", "name": "Ideal Colony",                "lat": 18.5148, "lon": 73.8198, "type": "metro_station", "line": "Aqua", "order": 3},
    {"id": "metro_aq_04", "name": "Nal Stop",                    "lat": 18.5155, "lon": 73.8315, "type": "metro_station", "line": "Aqua", "order": 4},
    {"id": "metro_aq_05", "name": "Garware College",             "lat": 18.5163, "lon": 73.8395, "type": "metro_station", "line": "Aqua", "order": 5},
    {"id": "metro_aq_06", "name": "Deccan Gymkhana",             "lat": 18.5168, "lon": 73.8432, "type": "metro_station", "line": "Aqua", "order": 6},
    {"id": "metro_aq_07", "name": "Chhatrapati Sambhaji Udyan",  "lat": 18.5185, "lon": 73.8482, "type": "metro_station", "line": "Aqua", "order": 7},
    {"id": "metro_aq_08", "name": "PMC",                         "lat": 18.5225, "lon": 73.8530, "type": "metro_station", "line": "Aqua", "order": 8},
    {"id": "metro_ix_01", "name": "Civil Court",                 "lat": 18.5280, "lon": 73.8555, "type": "metro_station", "line": "Purple/Aqua", "order": 9},
    {"id": "metro_aq_10", "name": "R.T.O Pune",                  "lat": 18.5265, "lon": 73.8590, "type": "metro_station", "line": "Aqua", "order": 10},
    {"id": "metro_aq_11", "name": "Kasba Peth",                  "lat": 18.5215, "lon": 73.8630, "type": "metro_station", "line": "Aqua", "order": 11},
    {"id": "metro_aq_12", "name": "Mangalwar Peth",              "lat": 18.5245, "lon": 73.8680, "type": "metro_station", "line": "Aqua", "order": 12},
    {"id": "metro_aq_13", "name": "Pune Railway Station",        "lat": 18.5290, "lon": 73.8755, "type": "metro_station", "line": "Aqua", "order": 13},
    {"id": "metro_aq_14", "name": "Ruby Hall Clinic",            "lat": 18.5330, "lon": 73.8830, "type": "metro_station", "line": "Aqua", "order": 14},
    {"id": "metro_aq_15", "name": "Bund Garden",                 "lat": 18.5348, "lon": 73.8898, "type": "metro_station", "line": "Aqua", "order": 15},
    {"id": "metro_aq_16", "name": "Yerawada",                    "lat": 18.5445, "lon": 73.8945, "type": "metro_station", "line": "Aqua", "order": 16},
    {"id": "metro_aq_17", "name": "Kalyani Nagar",               "lat": 18.5495, "lon": 73.9045, "type": "metro_station", "line": "Aqua", "order": 17},
    {"id": "metro_aq_18", "name": "Ramwadi",                     "lat": 18.5548, "lon": 73.9155, "type": "metro_station", "line": "Aqua", "order": 18},
]

# --- PURPLE EXTENSION NORTH (Phase 1A: PCMC → Bhakti Shakti) --- Under Construction
PURPLE_EXT_NORTH = [
    # PCMC is already in PURPLE_LINE so we start from Chinchwad
    {"id": "metro_pu_1a_01", "name": "Chinchwad",     "lat": 18.6350, "lon": 73.7985, "type": "metro_station", "line": "Purple-1A", "order": 1},
    {"id": "metro_pu_1a_02", "name": "Akurdi",        "lat": 18.6465, "lon": 73.7925, "type": "metro_station", "line": "Purple-1A", "order": 2},
    {"id": "metro_pu_1a_03", "name": "Nigdi",         "lat": 18.6555, "lon": 73.7780, "type": "metro_station", "line": "Purple-1A", "order": 3},
    {"id": "metro_pu_1a_04", "name": "Bhakti Shakti", "lat": 18.6665, "lon": 73.7700, "type": "metro_station", "line": "Purple-1A", "order": 4},
]

# --- PURPLE EXTENSION SOUTH (Phase 1B: Swargate → Katraj) --- Under Construction
PURPLE_EXT_SOUTH = [
    # Swargate is already in PURPLE_LINE so we start from Market Yard
    {"id": "metro_pu_1b_01", "name": "Market Yard",  "lat": 18.4945, "lon": 73.8575, "type": "metro_station", "line": "Purple-1B", "order": 1},
    {"id": "metro_pu_1b_02", "name": "Padmavati",    "lat": 18.4838, "lon": 73.8540, "type": "metro_station", "line": "Purple-1B", "order": 2},
    {"id": "metro_pu_1b_03", "name": "Katraj",        "lat": 18.4660, "lon": 73.8510, "type": "metro_station", "line": "Purple-1B", "order": 3},
]

# --- AQUA EXTENSION WEST (Vanaz → Chandani Chowk) ---
AQUA_EXT_WEST = [
    # Vanaz is already in AQUA_LINE; Kothrud Bus Depot connects to Chandani Chowk
    {"id": "metro_aq_2w_01", "name": "Kothrud Bus Depot",  "lat": 18.5065, "lon": 73.7948, "type": "metro_station", "line": "Aqua-2W", "order": 1},
    {"id": "metro_aq_2w_02", "name": "Chandani Chowk",     "lat": 18.5005, "lon": 73.7818, "type": "metro_station", "line": "Aqua-2W", "order": 2},
]

# --- AQUA EXTENSION EAST (Ramwadi → Vitthalwadi) ---
AQUA_EXT_EAST = [
    {"id": "metro_aq_2e_01", "name": "Viman Nagar",         "lat": 18.5625, "lon": 73.9195, "type": "metro_station", "line": "Aqua-2E", "order": 1},
    {"id": "metro_aq_2e_02", "name": "Kharadi Bypass",      "lat": 18.5558, "lon": 73.9325, "type": "metro_station", "line": "Aqua-2E", "order": 2},
    {"id": "metro_aq_2e_03", "name": "Tulaja Bhavani",      "lat": 18.5598, "lon": 73.9445, "type": "metro_station", "line": "Aqua-2E", "order": 3},
    {"id": "metro_aq_2e_04", "name": "Somnath Nagar",       "lat": 18.5660, "lon": 73.9525, "type": "metro_station", "line": "Aqua-2E", "order": 4},
    {"id": "metro_aq_2e_05", "name": "Ubale Nagar",         "lat": 18.5725, "lon": 73.9580, "type": "metro_station", "line": "Aqua-2E", "order": 5},
    {"id": "metro_aq_2e_06", "name": "Wagholi",             "lat": 18.5790, "lon": 73.9680, "type": "metro_station", "line": "Aqua-2E", "order": 6},
    {"id": "metro_aq_2e_07", "name": "Upper Kharadi Road",  "lat": 18.5778, "lon": 73.9790, "type": "metro_station", "line": "Aqua-2E", "order": 7},
    {"id": "metro_aq_2e_08", "name": "Siddharth Nagar",     "lat": 18.5805, "lon": 73.9885, "type": "metro_station", "line": "Aqua-2E", "order": 8},
    {"id": "metro_aq_2e_09", "name": "Bakori Phata",        "lat": 18.5845, "lon": 73.9960, "type": "metro_station", "line": "Aqua-2E", "order": 9},
    {"id": "metro_aq_2e_10", "name": "Wageshwar Temple",    "lat": 18.5890, "lon": 74.0055, "type": "metro_station", "line": "Aqua-2E", "order": 10},
    {"id": "metro_aq_2e_11", "name": "Vitthalwadi",         "lat": 18.5935, "lon": 74.0145, "type": "metro_station", "line": "Aqua-2E", "order": 11},
]


def build_edges(line_stations, line_name):
    """Build sequential bidirectional edges for a metro line."""
    edges = []
    for i in range(len(line_stations) - 1):
        edges.append({
            "from_station": line_stations[i]["id"],
            "from_name": line_stations[i]["name"],
            "to_station": line_stations[i + 1]["id"],
            "to_name": line_stations[i + 1]["name"],
            "line": line_name,
        })
    return edges


if __name__ == "__main__":
    # --- Build all stations (deduplicate Civil Court shared node) ---
    all_lines_raw = (
        PURPLE_LINE + AQUA_LINE +
        PURPLE_EXT_NORTH + PURPLE_EXT_SOUTH +
        AQUA_EXT_WEST + AQUA_EXT_EAST
    )

    seen_ids = set()
    unique_stations = []
    for s in all_lines_raw:
        if s["id"] not in seen_ids:
            unique_stations.append(s)
            seen_ids.add(s["id"])

    # --- Build edges ---
    all_edges = []
    all_edges += build_edges(PURPLE_LINE, "Purple")
    all_edges += build_edges(AQUA_LINE, "Aqua")

    # Extension edges connect to the main line terminuses
    # Purple North: PCMC → Chinchwad → ... → Bhakti Shakti
    purple_north_full = [PURPLE_LINE[0]] + PURPLE_EXT_NORTH  # PCMC at index 0
    all_edges += build_edges(purple_north_full, "Purple-1A")

    # Purple South: Swargate → Market Yard → ... → Katraj
    purple_south_full = [PURPLE_LINE[-1]] + PURPLE_EXT_SOUTH  # Swargate at end
    all_edges += build_edges(purple_south_full, "Purple-1B")

    # Aqua West: Vanaz → Kothrud → Chandani Chowk
    aqua_west_full = [AQUA_LINE[0]] + AQUA_EXT_WEST  # Vanaz at index 0
    all_edges += build_edges(aqua_west_full, "Aqua-2W")

    # Aqua East: Ramwadi → Viman Nagar → ... → Vitthalwadi
    aqua_east_full = [AQUA_LINE[-1]] + AQUA_EXT_EAST  # Ramwadi at end
    all_edges += build_edges(aqua_east_full, "Aqua-2E")

    # --- Save JSON (backward-compatible with build_graph.py) ---
    metro_json = OUT_DIR / "metro_stations.json"
    with open(metro_json, "w", encoding="utf-8") as f:
        json.dump(unique_stations, f, indent=2, ensure_ascii=False)
    print(f"✓ Saved {len(unique_stations)} metro stations to {metro_json}")

    # --- Save CSV (metro_stations.csv) ---
    stations_csv = OUT_DIR / "metro_stations.csv"
    with open(stations_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["station_name", "lat", "lon", "line", "order", "id"])
        writer.writeheader()
        for s in unique_stations:
            writer.writerow({
                "station_name": s["name"],
                "lat": s["lat"],
                "lon": s["lon"],
                "line": s["line"],
                "order": s.get("order", 0),
                "id": s["id"],
            })
    print(f"✓ Saved metro_stations.csv to {stations_csv}")

    # --- Save CSV (metro_edges.csv) ---
    edges_csv = OUT_DIR / "metro_edges.csv"
    with open(edges_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["from_station", "to_station", "line"])
        writer.writeheader()
        for e in all_edges:
            writer.writerow({
                "from_station": e["from_station"],
                "to_station": e["to_station"],
                "line": e["line"],
            })
    print(f"✓ Saved {len(all_edges)} metro edges to {edges_csv}")

    # --- Summary ---
    print(f"\nSummary:")
    print(f"  Purple Line (operational):        {len(PURPLE_LINE)} stations")
    print(f"  Aqua Line (operational):          {len(AQUA_LINE)} stations")
    print(f"  Purple Ext North (construction):  {len(PURPLE_EXT_NORTH)} stations")
    print(f"  Purple Ext South (construction):  {len(PURPLE_EXT_SOUTH)} stations")
    print(f"  Aqua Ext West:                    {len(AQUA_EXT_WEST)} stations")
    print(f"  Aqua Ext East:                    {len(AQUA_EXT_EAST)} stations")
    print(f"  Total unique stations:            {len(unique_stations)}")
    print(f"  Total edges:                      {len(all_edges)}")
