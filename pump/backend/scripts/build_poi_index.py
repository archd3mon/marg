import sqlite3
import httpx
import time
import json
from pathlib import Path

# Paths
BACKEND_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BACKEND_DIR.parent / "data" / "processed"
DB_PATH = DATA_DIR / "pune_poi.sqlite"

PUNE_KNOWN_PLACES = {
    # Chowks
    "Deccan Gymkhana": {"lat": 18.5157, "lng": 73.8412, "type": "locality"},
    "Shivajinagar": {"lat": 18.5314, "lng": 73.8446, "type": "locality"},
    "Kothrud": {"lat": 18.5035, "lng": 73.8058, "type": "locality"},
    "Warje": {"lat": 18.4728, "lng": 73.8018, "type": "locality"},
    "Hadapsar": {"lat": 18.5089, "lng": 73.9259, "type": "locality"},
    "Magarpatta": {"lat": 18.5146, "lng": 73.9264, "type": "locality"},
    "Hinjewadi": {"lat": 18.5913, "lng": 73.7389, "type": "locality"},
    "Wakad": {"lat": 18.5987, "lng": 73.7687, "type": "locality"},
    "Baner": {"lat": 18.5590, "lng": 73.7868, "type": "locality"},
    "Aundh": {"lat": 18.5635, "lng": 73.8124, "type": "locality"},
    "Pimpri": {"lat": 18.6279, "lng": 73.7997, "type": "locality"},
    "Chinchwad": {"lat": 18.6293, "lng": 73.7825, "type": "locality"},
    "Nigdi": {"lat": 18.6508, "lng": 73.7621, "type": "locality"},
    "Dehu Road": {"lat": 18.6881, "lng": 73.7368, "type": "locality"},
    "Talegaon": {"lat": 18.7303, "lng": 73.6811, "type": "locality"},
    "Lonavala": {"lat": 18.7510, "lng": 73.4072, "type": "locality"},
    # Colleges
    "COEP": {"lat": 18.5293, "lng": 73.8565, "type": "college"},
    "PICT": {"lat": 18.4578, "lng": 73.8508, "type": "college"},
    "MIT": {"lat": 18.5186, "lng": 73.8143, "type": "college"},
    "Symbiosis": {"lat": 18.5323, "lng": 73.8291, "type": "college"},
    "Fergusson": {"lat": 18.5222, "lng": 73.8398, "type": "college"},
    "SP College": {"lat": 18.5074, "lng": 73.8497, "type": "college"},
    "Wadia": {"lat": 18.5401, "lng": 73.8824, "type": "college"},
    "Sinhgad": {"lat": 18.4659, "lng": 73.8362, "type": "college"},
    "VIT": {"lat": 18.4636, "lng": 73.8682, "type": "college"},
    "Indira": {"lat": 18.6180, "lng": 73.7480, "type": "college"},
    "Bharati": {"lat": 18.4552, "lng": 73.8550, "type": "college"},
    "BMCC": {"lat": 18.5204, "lng": 73.8336, "type": "college"},
    "Cummins": {"lat": 18.4878, "lng": 73.8164, "type": "college"},
    "VIIT": {"lat": 18.4601, "lng": 73.8833, "type": "college"},
    "SCTR": {"lat": 18.4636, "lng": 73.8682, "type": "college"},
    "DYPIET": {"lat": 18.6225, "lng": 73.8153, "type": "college"},
    "RIMS": {"lat": 18.4579, "lng": 73.8824, "type": "college"},
    "Armed Forces Medical College": {"lat": 18.4975, "lng": 73.8967, "type": "college"},
    "AFMC": {"lat": 18.4975, "lng": 73.8967, "type": "college"},
    "BJ Medical": {"lat": 18.5273, "lng": 73.8741, "type": "college"},
    "KEM": {"lat": 18.5203, "lng": 73.8722, "type": "college"},
    # Hospitals
    "Ruby Hall": {"lat": 18.5348, "lng": 73.8841, "type": "hospital"},
    "Sahyadri": {"lat": 18.5149, "lng": 73.8341, "type": "hospital"},
    "Columbia Asia": {"lat": 18.5484, "lng": 73.9317, "type": "hospital"},
    "Jehangir": {"lat": 18.5323, "lng": 73.8824, "type": "hospital"},
    "Deenanath Mangeshkar": {"lat": 18.5029, "lng": 73.8236, "type": "hospital"},
    "Poona Hospital": {"lat": 18.5085, "lng": 73.8378, "type": "hospital"},
    "Sassoon": {"lat": 18.5273, "lng": 73.8741, "type": "hospital"},
    # Landmarks
    "Pune Airport": {"lat": 18.5822, "lng": 73.9197, "type": "landmark"},
    "Shivajinagar Station": {"lat": 18.5312, "lng": 73.8444, "type": "landmark"},
    "Pune Junction": {"lat": 18.5283, "lng": 73.8745, "type": "landmark"},
    "Khadki Station": {"lat": 18.5630, "lng": 73.8465, "type": "landmark"},
    "Chinchwad Station": {"lat": 18.6295, "lng": 73.7827, "type": "landmark"},
    "Wakad Bridge": {"lat": 18.5980, "lng": 73.7600, "type": "landmark"},
    "Swargate Bus Stand": {"lat": 18.4996, "lng": 73.8586, "type": "landmark"},
    "Shivaji Nagar Bus Depot": {"lat": 18.5321, "lng": 73.8450, "type": "landmark"},
    "PMC building": {"lat": 18.5262, "lng": 73.8548, "type": "landmark"},
    "Collector Office": {"lat": 18.5244, "lng": 73.8710, "type": "landmark"},
    "Aga Khan Palace": {"lat": 18.5524, "lng": 73.9015, "type": "landmark"},
    "Shaniwar Wada": {"lat": 18.5195, "lng": 73.8553, "type": "landmark"}
}

def setup_db():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    # Create tables based on schema
    cur.execute('''
    CREATE TABLE IF NOT EXISTS pois (
      id INTEGER PRIMARY KEY,
      osm_id TEXT,
      name TEXT NOT NULL,
      name_alt TEXT,
      type TEXT,
      lat REAL NOT NULL,
      lon REAL NOT NULL,
      importance REAL DEFAULT 0.5
    )
    ''')
    cur.execute('''CREATE INDEX IF NOT EXISTS idx_name ON pois(name COLLATE NOCASE)''')
    
    cur.execute('''
    CREATE VIRTUAL TABLE IF NOT EXISTS pois_fts USING fts5(
      name, name_alt, type,
      content='pois', content_rowid='id'
    )
    ''')
    conn.commit()
    return conn

def fetch_overpass_data(query_type, overpass_query):
    url = "https://overpass-api.de/api/interpreter"
    print(f"Fetching {query_type} from Overpass API... This may take a minute.")
    
    data = {"data": overpass_query}
    try:
        response = httpx.post(url, data=data, timeout=60.0)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error fetching {query_type}: {e}")
        return None

def main():
    conn = setup_db()
    cur = conn.cursor()
    
    # Check if table already populated
    cur.execute("SELECT COUNT(*) FROM pois")
    count = cur.fetchone()[0]
    if count > 0:
        print(f"DB already has {count} entries. Dropping existing records to rebuild.")
        cur.execute("DELETE FROM pois")
        cur.execute("DELETE FROM pois_fts")
        conn.commit()

    # Inject PUNE_KNOWN_PLACES
    for name, data in PUNE_KNOWN_PLACES.items():
        cur.execute(
            "INSERT INTO pois (osm_id, name, type, lat, lon, importance) VALUES (?, ?, ?, ?, ?, ?)",
            (f"manual_{name.replace(' ', '_')}", name, data['type'], data['lat'], data['lng'], 1.0)
        )
            
    # Sub-queries
    bbox = "18.3000,73.7000,18.7000,74.2000"
    
    queries = {
        "amenities": f"""
            [out:json][timeout:50];
            (
              node["amenity"~"school|college|hospital|clinic|bank|restaurant|hotel"]({bbox});
              way["amenity"~"school|college|hospital|clinic|bank|restaurant|hotel"]({bbox});
            );
            out center;
        """,
        "places": f"""
            [out:json][timeout:50];
            (
              node["place"~"suburb|neighbourhood|village|town"]({bbox});
            );
            out center;
        """,
        "landmarks": f"""
            [out:json][timeout:50];
            (
              node["historic"~"monument"]({bbox});
              way["leisure"~"park|stadium"]({bbox});
              node["railway"~"station"]({bbox});
              node["highway"~"bus_stop"]({bbox});
              node["aeroway"~"aerodrome"]({bbox});
            );
            out center;
        """,
        "roads": f"""
            [out:json][timeout:50];
            way["highway"~"primary|secondary|tertiary|trunk"]["name"]({bbox});
            out center;
        """
    }
    
    inserted = 0
    for q_type, query in queries.items():
        res = fetch_overpass_data(q_type, query)
        if not res or "elements" not in res:
            continue
            
        for el in res["elements"]:
            tags = el.get("tags", {})
            name = tags.get("name")
            if not name:
                continue
                
            osm_id = str(el.get("id", ""))
            
            if el["type"] == "node":
                lat = el.get("lat")
                lon = el.get("lon")
            elif "center" in el:
                lat = el["center"].get("lat")
                lon = el["center"].get("lon")
            else:
                continue
                
            if not lat or not lon:
                continue

            name_alt = tags.get("alt_name") or tags.get("loc_name") or ""
            poi_type = tags.get("amenity") or tags.get("place") or tags.get("highway") or tags.get("leisure") or q_type
            
            importance = 0.5
            if poi_type in ["station", "hospital", "college", "suburb", "trunk"]:
                importance = 0.8
                
            cur.execute("""
                INSERT INTO pois (osm_id, name, name_alt, type, lat, lon, importance)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (osm_id, name, name_alt, poi_type, lat, lon, importance))
            inserted += 1
            
        time.sleep(2)
        
    conn.commit()
    print(f"Inserted {inserted} OSM POIs into pune_poi.sqlite")
    
    cur.execute("""
        INSERT INTO pois_fts (rowid, name, name_alt, type)
        SELECT id, name, name_alt, type FROM pois
    """)
    conn.commit()
    print("Rebuilt FTS5 index.")
    
    conn.close()

if __name__ == "__main__":
    main()
