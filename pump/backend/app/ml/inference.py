import joblib
import pandas as pd
from pathlib import Path

MODEL_PATH = Path("/home/jayant/gitgud/marg/marg/pump/data/models/travel_time_rf.pkl")

class TravelTimePredictor:
    def __init__(self):
        self.model = None
        
    def load(self):
        print("Loading Random Forest Model...")
        self.model = joblib.load(MODEL_PATH)
        print("Model loaded.")
        
    def predict_leg_time(self, mode_str, distance_m, hour=10, day_of_week=0, zone=1):
        """
        mode_str: "bus", "metro", "walk"
        hour: 0-23
        day_of_week: 0-6
        """
        if self.model is None:
            raise ValueError("Model not loaded")
            
        mode_map = {"bus": 0, "metro": 1, "walk": 2}
        mode_encoded = mode_map.get(mode_str, 2)
        
        # In a real app, congestion_zone is a geo-fence lookup. Here we mock it as Zone 1.
        df = pd.DataFrame([{
            'mode': mode_encoded,
            'distance_m': distance_m,
            'hour': hour,
            'day_of_week': day_of_week,
            'congestion_zone': zone
        }])
        
        # Returns duration in seconds
        return self.model.predict(df)[0]

predictor = TravelTimePredictor()
