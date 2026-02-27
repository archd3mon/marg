import xml.etree.ElementTree as ET
import pandas as pd
import json
import os
from pathlib import Path

# Paths
DATA_DIR = Path("/home/jayant/gitgud/marg/marg/Datasets")
OUT_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/processed")
OUT_DIR.mkdir(parents=True, exist_ok=True)

STOPS_KML = DATA_DIR / "pune PMPML Bus Stops Map.kml"
ROUTES_CSV = DATA_DIR / "pune PMPML Bus Routes List.csv"

def parse_kml_stops(kml_path):
    print("Parsing KML Stops...")
    tree = ET.parse(kml_path)
    root = tree.getroot()
    
    # KML parsing (handling namespaces is tricky, we'll strip them for easy search)
    namespaces = {'kml': 'http://www.opengis.net/kml/2.2'}
    
    stops = []
    
    # Find all Placemarks
    for placemark in root.findall('.//kml:Placemark', namespaces):
        stop_data = {}
        
        # Get coordinates
        point = placemark.find('.//kml:Point/kml:coordinates', namespaces)
        if point is not None:
            coords = point.text.strip().split(',')
            stop_data['lon'] = float(coords[0])
            stop_data['lat'] = float(coords[1])
            
        # Get ExtendedData (SchemaData -> SimpleData)
        schema_data = placemark.find('.//kml:SchemaData', namespaces)
        if schema_data is not None:
            for simple_data in schema_data.findall('.//kml:SimpleData', namespaces):
                name = simple_data.get('name')
                value = simple_data.text
                if name == 'stop_id':
                    stop_data['id'] = f"bus_{value}"
                elif name == 'stop_name':
                    stop_data['name'] = value
                elif name == 'stop_code':
                    stop_data['code'] = value
        
        if 'id' in stop_data and 'lat' in stop_data:
            stop_data['type'] = 'bus_stop'
            stops.append(stop_data)
            
    print(f"Total bus stops parsed: {len(stops)}")
    return stops

def parse_routes_csv(csv_path):
    print("Parsing Routes CSV...")
    df = pd.read_csv(csv_path)
    routes = []
    
    for _, row in df.iterrows():
        route = {
            'id': f"route_{row['Route ID']}",
            'name': row['Route ID'],
            'description': row['Route Description'],
            'length_km': float(row['Kilometer']) if not pd.isna(row['Kilometer']) else 0.0
        }
        routes.append(route)
        
    print(f"Total routes parsed: {len(routes)}")
    return routes

if __name__ == "__main__":
    stops = parse_kml_stops(STOPS_KML)
    routes = parse_routes_csv(ROUTES_CSV)
    
    # Save to processed JSON
    stops_file = OUT_DIR / "bus_stops.json"
    routes_file = OUT_DIR / "bus_routes.json"
    
    with open(stops_file, 'w', encoding='utf-8') as f:
        json.dump(stops, f, indent=2, ensure_ascii=False)
        
    with open(routes_file, 'w', encoding='utf-8') as f:
        json.dump(routes, f, indent=2, ensure_ascii=False)
        
    print(f"Saved {len(stops)} stops to {stops_file}")
    print(f"Saved {len(routes)} routes to {routes_file}")
