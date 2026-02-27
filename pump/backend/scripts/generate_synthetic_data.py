import json
from pathlib import Path

OUT_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/processed")
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Define mock Metro lines with approximate coordinates
# Aqua Line (Vanaz to Ramwadi)
AQUA_LINE = [
    {"id": "metro_aq_1", "name": "Vanaz", "lat": 18.5133, "lon": 73.8055, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_2", "name": "Anand Nagar", "lat": 18.5140, "lon": 73.8120, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_3", "name": "Ideal Colony", "lat": 18.5148, "lon": 73.8200, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_4", "name": "Nal Stop", "lat": 18.5152, "lon": 73.8320, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_5", "name": "Garware College", "lat": 18.5160, "lon": 73.8400, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_6", "name": "Deccan Gymkhana", "lat": 18.5170, "lon": 73.8435, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_7", "name": "Chhatrapati Sambhaji Udyan", "lat": 18.5185, "lon": 73.8485, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_8", "name": "PMC Bhavan", "lat": 18.5230, "lon": 73.8540, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_9", "name": "Civil Court", "lat": 18.5280, "lon": 73.8560, "type": "metro_station", "line": "Aqua"}, # Interchange
    {"id": "metro_aq_10", "name": "Mangalwar Peth", "lat": 18.5320, "lon": 73.8680, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_11", "name": "Pune Railway Station", "lat": 18.5300, "lon": 73.8760, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_12", "name": "Ruby Hall Clinic", "lat": 18.5330, "lon": 73.8830, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_13", "name": "Bund Garden", "lat": 18.5350, "lon": 73.8900, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_14", "name": "Yerawada", "lat": 18.5450, "lon": 73.8950, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_15", "name": "Kalyani Nagar", "lat": 18.5500, "lon": 73.9050, "type": "metro_station", "line": "Aqua"},
    {"id": "metro_aq_16", "name": "Ramwadi", "lat": 18.5550, "lon": 73.9160, "type": "metro_station", "line": "Aqua"}
]

# Purple Line (PCMC to Swargate)
PURPLE_LINE = [
    {"id": "metro_pu_1", "name": "PCMC", "lat": 18.6250, "lon": 73.8050, "type": "metro_station", "line": "Purple"},
    {"id": "metro_pu_2", "name": "Sant Tukaram Nagar", "lat": 18.6180, "lon": 73.8100, "type": "metro_station", "line": "Purple"},
    {"id": "metro_pu_3", "name": "Bhosari", "lat": 18.6100, "lon": 73.8150, "type": "metro_station", "line": "Purple"},
    {"id": "metro_pu_4", "name": "Kasarwadi", "lat": 18.6010, "lon": 73.8200, "type": "metro_station", "line": "Purple"},
    {"id": "metro_pu_5", "name": "Phugewadi", "lat": 18.5900, "lon": 73.8250, "type": "metro_station", "line": "Purple"},
    {"id": "metro_pu_6", "name": "Dapodi", "lat": 18.5800, "lon": 73.8320, "type": "metro_station", "line": "Purple"},
    {"id": "metro_pu_7", "name": "Bopodi", "lat": 18.5700, "lon": 73.8370, "type": "metro_station", "line": "Purple"},
    {"id": "metro_pu_8", "name": "Khadki", "lat": 18.5550, "lon": 73.8420, "type": "metro_station", "line": "Purple"},
    {"id": "metro_pu_9", "name": "Range Hill", "lat": 18.5450, "lon": 73.8450, "type": "metro_station", "line": "Purple"},
    {"id": "metro_pu_10", "name": "Shivaji Nagar", "lat": 18.5320, "lon": 73.8500, "type": "metro_station", "line": "Purple"},
    {"id": "metro_aq_9", "name": "Civil Court", "lat": 18.5280, "lon": 73.8560, "type": "metro_station", "line": "Purple/Aqua"}, # Shared
    {"id": "metro_pu_11", "name": "Budhwar Peth", "lat": 18.5180, "lon": 73.8560, "type": "metro_station", "line": "Purple"},
    {"id": "metro_pu_12", "name": "Mandai", "lat": 18.5110, "lon": 73.8560, "type": "metro_station", "line": "Purple"},
    {"id": "metro_pu_13", "name": "Swargate", "lat": 18.5010, "lon": 73.8560, "type": "metro_station", "line": "Purple"}
]

if __name__ == "__main__":
    metro_stations = AQUA_LINE + PURPLE_LINE
    # Deduplicate Civil Court
    seen_ids = set()
    unique_stations = []
    for s in metro_stations:
        if s['id'] not in seen_ids:
            unique_stations.append(s)
            seen_ids.add(s['id'])
            
    metro_file = OUT_DIR / "metro_stations.json"
    
    with open(metro_file, 'w', encoding='utf-8') as f:
        json.dump(unique_stations, f, indent=2, ensure_ascii=False)
        
    print(f"Saved {len(unique_stations)} mock metro stations to {metro_file}")
