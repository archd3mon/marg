#!/usr/bin/env python3
"""
build_poi_index.py — Comprehensive POI index builder for Marg (Pune mobility planner).

Produces pump/data/processed/pune_poi.sqlite with 50,000+ entries by:
  1. Inserting hardcoded PUNE_MASTER_PLACES (250+ entries, importance=1.0)
  2. Running 12 Overpass API queries covering every POI category
  3. Expanding alternate names into separate rows
  4. Building FTS5 full-text search index

Usage:
    python scripts/build_poi_index.py
"""

import sqlite3
import requests
import time
import re
import sys
from pathlib import Path

# ── Paths ───────────────────────────────────────────────────────────────────────
BACKEND_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BACKEND_DIR.parent / "data" / "processed"
DB_PATH = DATA_DIR / "pune_poi.sqlite"

# Add backend to sys.path so we can import app.utils
sys.path.insert(0, str(BACKEND_DIR))

# ── Pune bounding box (covers Pune + PCMC + Hinjewadi + Kharadi + Wagholi) ────
BBOX = "18.20,73.60,18.80,74.30"

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
MAX_RETRIES = 3
RETRY_WAIT = 10
TIMEOUT = 120

# ── Importance scores by type ──────────────────────────────────────────────────
IMPORTANCE = {
    "metro_station": 1.0,
    "railway_station": 1.0,
    "airport": 1.0,
    "bus_station": 0.9,
    "college": 0.9,
    "university": 0.9,
    "hospital": 0.9,
    "landmark": 0.85,
    "locality": 0.8,
    "junction": 0.8,
    "government": 0.8,
    "it_park": 0.75,
    "corporate_campus": 0.7,
    "road": 0.7,
    "market": 0.7,
    "mall": 0.7,
    "police_station": 0.65,
    "bank": 0.6,
    "sports_venue": 0.6,
    "bus_stop": 0.6,
    "fuel_station": 0.55,
    "cinema": 0.55,
    "place_of_worship": 0.55,
    "hotel": 0.5,
    "residential_complex": 0.5,
    "auto_stand": 0.5,
    "park": 0.5,
    "school": 0.5,
    "atm": 0.5,
    "ev_charging": 0.45,
    "gym": 0.45,
    "parking": 0.4,
    "shop": 0.4,
    "restaurant": 0.4,
}

# ══════════════════════════════════════════════════════════════════════════════════
# PUNE_MASTER_PLACES — Imported from canonical source (app/utils.py)
# ══════════════════════════════════════════════════════════════════════════════════
from app.utils import PUNE_MASTER_PLACES


OVERPASS_QUERIES = {
    "bus_stops": f"""[out:json][timeout:120];
(
  node["highway"="bus_stop"]({BBOX});
  node["public_transport"="stop_position"]({BBOX});
  node["public_transport"="platform"]({BBOX});
);
out body;""",

    "railway": f"""[out:json][timeout:120];
(
  node["railway"~"station|halt|tram_stop|subway_entrance"]({BBOX});
  way["railway"~"station|halt"]({BBOX});
);
out center body;""",

    "places": f"""[out:json][timeout:120];
(
  node["place"~"suburb|quarter|neighbourhood|village|town|city_block|locality"]({BBOX});
  relation["place"~"suburb|quarter|neighbourhood|village|town"]({BBOX});
);
out center body;""",

    "education": f"""[out:json][timeout:120];
(
  node["amenity"~"university|college|school|kindergarten"]({BBOX});
  way["amenity"~"university|college|school"]({BBOX});
  relation["amenity"~"university|college|school"]({BBOX});
);
out center body;""",

    "healthcare": f"""[out:json][timeout:120];
(
  node["amenity"~"hospital|clinic|pharmacy|dentist|doctors"]({BBOX});
  way["amenity"~"hospital|clinic"]({BBOX});
  relation["amenity"~"hospital|clinic"]({BBOX});
);
out center body;""",

    "transit": f"""[out:json][timeout:120];
(
  node["amenity"~"bus_station|ferry_terminal"]({BBOX});
  way["amenity"~"bus_station"]({BBOX});
  node["highway"="bus_stop"]["operator"~"PMPML|MSRTC|PMC"]({BBOX});
);
out center body;""",

    "landmarks": f"""[out:json][timeout:120];
(
  node["tourism"~"attraction|museum|viewpoint|hotel|guest_house|hostel"]({BBOX});
  node["historic"~"monument|memorial|fort|palace|ruins"]({BBOX});
  node["leisure"~"park|stadium|sports_centre|swimming_pool|garden"]({BBOX});
  way["tourism"~"attraction|museum"]({BBOX});
  way["historic"~"monument|memorial|fort"]({BBOX});
  way["leisure"~"park|stadium|sports_centre|garden"]({BBOX});
);
out center body;""",

    "government": f"""[out:json][timeout:120];
(
  node["amenity"~"townhall|courthouse|police|fire_station|post_office|bank"]({BBOX});
  way["amenity"~"townhall|courthouse|police|fire_station"]({BBOX});
  node["office"~"government|administrative"]({BBOX});
);
out center body;""",

    "roads": f"""[out:json][timeout:120];
nwr["highway"~"primary|secondary|tertiary|residential"]["name"]({BBOX});
out center body;""",

    "worship": f"""[out:json][timeout:120];
(
  node["amenity"="place_of_worship"]({BBOX});
  way["amenity"="place_of_worship"]({BBOX});
  relation["amenity"="place_of_worship"]({BBOX});
);
out center body;""",

    "shopping": f"""[out:json][timeout:120];
(
  node["shop"~"mall|supermarket|marketplace"]({BBOX});
  way["shop"~"mall|supermarket|marketplace"]({BBOX});
  way["landuse"="retail"]["name"]({BBOX});
);
out center body;""",

    "it_industrial": f"""[out:json][timeout:120];
(
  way["landuse"~"industrial|commercial"]["name"]({BBOX});
  node["office"="it"]({BBOX});
  way["building"~"office|industrial"]["name"]({BBOX});
);
out center body;""",

    "food": f"""[out:json][timeout:120];
(
  node["amenity"~"restaurant|cafe|food_court|fast_food|bar|pub"]({BBOX});
  way["amenity"~"restaurant|cafe|food_court|fast_food|bar|pub"]({BBOX});
);
out center body;""",

    "residential": f"""[out:json][timeout:120];
(
  way["landuse"="residential"]["name"]({BBOX});
  way["building"~"apartments|residential"]["name"]({BBOX});
);
out center body;""",

    "entertainment": f"""[out:json][timeout:120];
(
  node["amenity"~"cinema|theatre|arts_centre"]({BBOX});
  way["amenity"~"cinema|theatre|arts_centre"]({BBOX});
);
out center body;""",

    "commercial": f"""[out:json][timeout:120];
(
  node["building"~"commercial|public|office"]["name"]({BBOX});
  way["building"~"commercial|public|office"]["name"]({BBOX});
  node["office"~"company"]["name"]({BBOX});
  way["office"~"company"]["name"]({BBOX});
);
out center body;""",

    "fuel_stations": f"""[out:json][timeout:120];
(
  node["amenity"="fuel"]["name"]({BBOX});
  way["amenity"="fuel"]["name"]({BBOX});
);
out center body;""",

    "atm_banking": f"""[out:json][timeout:120];
(
  node["amenity"~"atm|bank"]({BBOX});
  way["amenity"~"bank"]({BBOX});
);
out center body;""",

    "hotels_lodging": f"""[out:json][timeout:120];
(
  node["tourism"~"hotel|motel|guest_house|hostel"]["name"]({BBOX});
  way["tourism"~"hotel|motel|guest_house|hostel"]["name"]({BBOX});
);
out center body;""",

    "ev_charging": f"""[out:json][timeout:120];
(
  node["amenity"="charging_station"]({BBOX});
  way["amenity"="charging_station"]({BBOX});
);
out center body;""",

    "fitness_sports": f"""[out:json][timeout:120];
(
  node["leisure"~"fitness_centre|sports_centre|swimming_pool"]["name"]({BBOX});
  way["leisure"~"fitness_centre|sports_centre|swimming_pool"]["name"]({BBOX});
);
out center body;""",

    "parking": f"""[out:json][timeout:120];
(
  node["amenity"="parking"]["name"]({BBOX});
  way["amenity"="parking"]["name"]({BBOX});
);
out center body;""",

    "auto_stands": f"""[out:json][timeout:120];
(
  node["amenity"="taxi"]({BBOX});
  node["public_transport"="stop_position"]["taxi"="yes"]({BBOX});
);
out center body;""",

    "named_buildings": f"""[out:json][timeout:120];
(
  way["building"="yes"]["name"]({BBOX});
  node["addr:housename"]({BBOX});
);
out center body;""",
}


def fetch_overpass(query_name: str, query: str) -> dict | None:
    """Fetch Overpass data with retry logic."""
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            print(f"  [{attempt}/{MAX_RETRIES}] Fetching {query_name}...")
            resp = requests.post(
                OVERPASS_URL,
                data={"data": query},
                timeout=TIMEOUT,
            )
            resp.raise_for_status()
            data = resp.json()
            n = len(data.get("elements", []))
            print(f"  ✓ {query_name}: {n} elements")
            return data
        except Exception as e:
            print(f"  ✗ {query_name} attempt {attempt} failed: {e}")
            if attempt < MAX_RETRIES:
                print(f"    Waiting {RETRY_WAIT}s before retry...")
                time.sleep(RETRY_WAIT)
    print(f"  ✗✗ {query_name}: all retries exhausted")
    return None


def determine_poi_type(tags: dict) -> str:
    """Determine POI type from OSM tags."""
    if tags.get("railway") in ("station", "halt"):
        return "railway_station"
    if tags.get("railway") in ("tram_stop", "subway_entrance"):
        return "metro_station"
    if tags.get("highway") == "bus_stop" or tags.get("public_transport") in ("stop_position", "platform"):
        return "bus_stop"
    if tags.get("amenity") == "bus_station":
        return "bus_station"
    if tags.get("amenity") == "university":
        return "university"
    if tags.get("amenity") == "college":
        return "college"
    if tags.get("amenity") == "school":
        return "school"
    if tags.get("amenity") == "hospital":
        return "hospital"
    if tags.get("amenity") == "clinic":
        return "clinic"
    if tags.get("amenity") == "place_of_worship":
        return "place_of_worship"
    if tags.get("amenity") == "fuel":
        return "fuel_station"
    if tags.get("amenity") in ("townhall", "courthouse", "fire_station", "post_office"):
        return "government"
    if tags.get("amenity") == "police":
        return "police_station"
    if tags.get("office") in ("government", "administrative"):
        return "government"
    if tags.get("amenity") == "bank":
        return "bank"
    if tags.get("amenity") == "atm":
        return "atm"
    if tags.get("amenity") in ("pharmacy", "dentist", "doctors"):
        return "healthcare"
    if tags.get("amenity") == "charging_station":
        return "ev_charging"
    if tags.get("amenity") == "parking":
        return "parking"
    if tags.get("amenity") == "taxi":
        return "auto_stand"
    if tags.get("amenity") in ("cinema", "theatre"):
        return "cinema"
    if tags.get("tourism") in ("hotel", "motel", "guest_house", "hostel"):
        return "hotel"
    if tags.get("tourism"):
        return "tourism"
    if tags.get("historic"):
        return "landmark"
    if tags.get("leisure") in ("fitness_centre", "sports_centre", "swimming_pool"):
        return "gym"
    if tags.get("leisure") in ("park", "garden"):
        return "park"
    if tags.get("leisure") in ("stadium",):
        return "sports_venue"
    if tags.get("leisure"):
        return "leisure"
    if tags.get("place"):
        return "locality"
    if tags.get("shop") in ("mall", "supermarket"):
        return "mall"
    if tags.get("shop"):
        return "shop"
    if tags.get("landuse") == "retail":
        return "market"
    if tags.get("landuse") == "residential" and tags.get("name"):
        return "residential_complex"
    if tags.get("landuse") in ("industrial", "commercial"):
        return "it_park"
    if tags.get("office") == "it":
        return "it_park"
    if tags.get("office") == "company":
        return "corporate_campus"
    if tags.get("building") in ("office", "industrial"):
        return "it_park"
    if tags.get("highway"):
        return "road"
    return "other"


def get_importance(poi_type: str) -> float:
    """Get importance score for a POI type."""
    return IMPORTANCE.get(poi_type, 0.5)


def setup_db() -> sqlite3.Connection:
    """Create fresh SQLite database with proper schema."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    # Remove old DB
    if DB_PATH.exists():
        DB_PATH.unlink()

    conn = sqlite3.connect(str(DB_PATH))
    cur = conn.cursor()

    cur.executescript("""
        CREATE TABLE pois (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            osm_id TEXT,
            osm_type TEXT,
            name TEXT NOT NULL,
            name_en TEXT,
            name_mr TEXT,
            alt_names TEXT,
            poi_type TEXT,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            importance REAL DEFAULT 0.5
        );
        CREATE INDEX idx_poi_name ON pois(name COLLATE NOCASE);
        CREATE INDEX idx_poi_type ON pois(poi_type);
        CREATE INDEX idx_poi_coords ON pois(lat, lon);

        CREATE VIRTUAL TABLE pois_fts USING fts5(
            name, name_en, name_mr, alt_names, poi_type,
            content='pois', content_rowid='id',
            tokenize='unicode61 remove_diacritics 1'
        );

        CREATE TRIGGER pois_ai AFTER INSERT ON pois BEGIN
            INSERT INTO pois_fts(rowid, name, name_en, name_mr, alt_names, poi_type)
            VALUES (new.id, new.name, new.name_en, new.name_mr, new.alt_names, new.poi_type);
        END;
    """)
    conn.commit()
    return conn


def insert_master_places(conn: sqlite3.Connection) -> int:
    """Insert PUNE_MASTER_PLACES with importance=1.0. Returns count."""
    cur = conn.cursor()
    count = 0
    for name, data in PUNE_MASTER_PLACES.items():
        poi_type = str(data["type"])
        alt = str(data.get("alt", ""))
        imp = max(get_importance(poi_type), 1.0)  # Master places always 1.0

        cur.execute(
            """INSERT INTO pois (osm_id, osm_type, name, name_en, name_mr, alt_names, poi_type, lat, lon, importance)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (f"master_{name.replace(' ', '_')}", "manual", name, name, "", alt, poi_type,
             data["lat"], data["lon"], imp),
        )
        count += 1
    conn.commit()
    return count


def insert_overpass_data(conn: sqlite3.Connection) -> int:
    """Run all Overpass queries and insert results. Returns count inserted."""
    cur = conn.cursor()

    # Collect existing master place keys to avoid duplicates
    master_keys = set()
    for name, data in PUNE_MASTER_PLACES.items():
        master_keys.add((name.lower(), round(float(data["lat"]), 4), round(float(data["lon"]), 4)))

    seen = set(master_keys)
    total_inserted: int = 0

    for query_name, query in OVERPASS_QUERIES.items():
        data = fetch_overpass(query_name, query)
        if not data or "elements" not in data:
            continue

        batch = []
        for el in data.get("elements", []):
            tags = el.get("tags", {})
            name = tags.get("name")
            if not name or not name.strip():
                continue
            # Skip purely numeric names
            if re.match(r"^\d+$", name.strip()):
                continue

            # Get coordinates
            if el["type"] == "node":
                lat = el.get("lat")
                lon = el.get("lon")
            elif "center" in el:
                lat = el["center"].get("lat")
                lon = el["center"].get("lon")
            else:
                continue

            if lat is None or lon is None:
                continue

            # Deduplicate
            dedup_key = (name.lower(), round(lat, 4), round(lon, 4))
            if dedup_key in seen:
                continue
            seen.add(dedup_key)

            osm_id = str(el.get("id", ""))
            osm_type = el.get("type", "node")
            poi_type = determine_poi_type(tags)
            name_en = tags.get("name:en", name)
            name_mr = tags.get("name:mr", "")

            # Build alt_names
            alt_parts = []
            for key in ("alt_name", "old_name", "name:mr", "name:en", "name:hi"):
                val = tags.get(key, "")
                if val and val != name:
                    alt_parts.append(val)
            alt_names = ",".join(alt_parts)

            importance = get_importance(poi_type)

            batch.append((
                osm_id, osm_type, name, name_en, name_mr, alt_names,
                poi_type, lat, lon, importance,
            ))

        if batch:
            cur.executemany(
                """INSERT INTO pois (osm_id, osm_type, name, name_en, name_mr, alt_names, poi_type, lat, lon, importance)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                batch,
            )
            conn.commit()
            total_inserted += len(batch)

        # Rate-limit between Overpass queries
        time.sleep(2)

    return total_inserted


def expand_alt_names(conn: sqlite3.Connection) -> int:
    """
    For each POI with alt_names, insert ADDITIONAL rows for each alternate name
    pointing to the same coordinates. Returns count of expanded rows.
    """
    cur = conn.cursor()
    cur.execute(
        "SELECT id, name, name_en, name_mr, alt_names, poi_type, lat, lon, importance "
        "FROM pois WHERE alt_names IS NOT NULL AND alt_names != ''"
    )
    rows = cur.fetchall()

    seen_alts = set()
    batch = []
    for row in rows:
        _id, name, name_en, name_mr, alt_names, poi_type, lat, lon, importance = row
        for alt in alt_names.split(","):
            alt = alt.strip()
            if not alt or alt.lower() == name.lower():
                continue
            dedup_key = (alt.lower(), round(float(lat), 4), round(float(lon), 4))
            if dedup_key in seen_alts:
                continue
            seen_alts.add(dedup_key)

            batch.append((
                f"alt_{_id}", "alt", alt, name_en, name_mr, name,
                poi_type, lat, lon, max(importance - 0.05, 0.3),
            ))

    if batch:
        cur.executemany(
            """INSERT INTO pois (osm_id, osm_type, name, name_en, name_mr, alt_names, poi_type, lat, lon, importance)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            batch,
        )
        conn.commit()

    return len(batch)


def print_summary(conn: sqlite3.Connection, master_count: int, overpass_count: int, alt_count: int):
    """Print final summary."""
    cur = conn.cursor()
    total = cur.execute("SELECT COUNT(*) FROM pois").fetchone()[0]

    cur.execute("SELECT poi_type, COUNT(*) FROM pois GROUP BY poi_type ORDER BY COUNT(*) DESC")
    type_counts = cur.fetchall()

    print("\n" + "=" * 60)
    print(f"✓ Inserted {master_count} records from PUNE_MASTER_PLACES")
    print(f"✓ Inserted {overpass_count} records from Overpass")
    print(f"✓ Expanded {alt_count} alternate name entries")
    print(f"✓ Total unique POIs: {total}")
    print(f"✓ By type:")
    for poi_type, count in type_counts:
        print(f"    {poi_type}={count}")
    print(f"✓ Saved to {DB_PATH}")
    print("=" * 60)


def main():
    print("=" * 60)
    print("Marg POI Index Builder — Comprehensive Pune coverage")
    print("=" * 60)

    print("\n[1/5] Setting up database...")
    conn = setup_db()

    print("\n[2/5] Inserting PUNE_MASTER_PLACES...")
    master_count = insert_master_places(conn)
    print(f"  ✓ {master_count} master places inserted")

    print("\n[3/5] Fetching from Overpass API (12 queries)...")
    overpass_count = insert_overpass_data(conn)

    print("\n[4/5] Expanding alternate names...")
    alt_count = expand_alt_names(conn)
    print(f"  ✓ {alt_count} alternate name rows added")

    print("\n[5/5] Summary")
    print_summary(conn, master_count, overpass_count, alt_count)

    conn.close()


if __name__ == "__main__":
    main()
