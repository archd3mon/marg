import math

def haversine(p1: dict, p2: dict) -> float:
    """Returns great-circle distance in km between {lat, lng} dicts."""
    lat1 = p1.get('lat') or p1.get('latitude', 0)
    lon1 = p1.get('lng') or p1.get('lon') or p1.get('longitude', 0)
    lat2 = p2.get('lat') or p2.get('latitude', 0)
    lon2 = p2.get('lng') or p2.get('lon') or p2.get('longitude', 0)
    
    # Radius of the Earth in kilometers
    R = 6371.0
    
    lat1_rad = math.radians(float(lat1))
    lon1_rad = math.radians(float(lon1))
    lat2_rad = math.radians(float(lat2))
    lon2_rad = math.radians(float(lon2))
    
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    
    a = math.sin(dlat / 2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c

PUNE_KNOWN_PLACES = {
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
    "Ruby Hall": {"lat": 18.5348, "lng": 73.8841, "type": "hospital"},
    "Sahyadri": {"lat": 18.5149, "lng": 73.8341, "type": "hospital"},
    "Columbia Asia": {"lat": 18.5484, "lng": 73.9317, "type": "hospital"},
    "Jehangir": {"lat": 18.5323, "lng": 73.8824, "type": "hospital"},
    "Deenanath Mangeshkar": {"lat": 18.5029, "lng": 73.8236, "type": "hospital"},
    "Poona Hospital": {"lat": 18.5085, "lng": 73.8378, "type": "hospital"},
    "Sassoon": {"lat": 18.5273, "lng": 73.8741, "type": "hospital"},
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
    "Shaniwar Wada": {"lat": 18.5195, "lng": 73.8553, "type": "landmark"},
    "SIT": {"lat": 18.5362, "lng": 73.7271, "type": "college"},
    "SIT Pune": {"lat": 18.5362, "lng": 73.7271, "type": "college"},
    "Symbiosis Institute of Technology": {"lat": 18.5362, "lng": 73.7271, "type": "college"},
    "Dagdusheth": {"lat": 18.5171, "lng": 73.8553, "type": "landmark"},
    "Dagduseth Ganpati": {"lat": 18.5171, "lng": 73.8553, "type": "landmark"},
    "FC Road": {"lat": 18.5226, "lng": 73.8427, "type": "landmark"},
    "JM Road": {"lat": 18.5168, "lng": 73.8375, "type": "landmark"},
    "MG Road": {"lat": 18.5142, "lng": 73.8770, "type": "landmark"},
    "Sinhagad Fort": {"lat": 18.3663, "lng": 73.7559, "type": "landmark"},
    "Vetal Tekdi": {"lat": 18.5268, "lng": 73.8222, "type": "landmark"},
    "Pune Station": {"lat": 18.5290, "lng": 73.8755, "type": "landmark"},
    "Swargate": {"lat": 18.4996, "lng": 73.8586, "type": "landmark"},
    "Khadki": {"lat": 18.5630, "lng": 73.8465, "type": "locality"},
    "Katraj": {"lat": 18.4529, "lng": 73.8655, "type": "locality"},
    "Kondhwa": {"lat": 18.4653, "lng": 73.8938, "type": "locality"},
    "Kharadi": {"lat": 18.5511, "lng": 73.9406, "type": "locality"},
    "Viman Nagar": {"lat": 18.5679, "lng": 73.9143, "type": "locality"},
    "Koregaon Park": {"lat": 18.5362, "lng": 73.8944, "type": "locality"},
    "Camp": {"lat": 18.5130, "lng": 73.8800, "type": "locality"},
    "Yerawada": {"lat": 18.5580, "lng": 73.8830, "type": "locality"},
    "Parvati": {"lat": 18.4980, "lng": 73.8490, "type": "locality"},
    "Law College Road": {"lat": 18.5130, "lng": 73.8340, "type": "landmark"},
    "Senapati Bapat Road": {"lat": 18.5310, "lng": 73.8290, "type": "landmark"},
    "University of Pune": {"lat": 18.5547, "lng": 73.8274, "type": "college"},
    "SPPU": {"lat": 18.5547, "lng": 73.8274, "type": "college"},
}
