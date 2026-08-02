import joblib
import pandas as pd
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

# pump/backend/app/ml/inference.py → 4 parents → pump/ → /data/models/
_ML_BASE = Path(__file__).resolve().parent.parent.parent.parent / "data" / "models"
MODEL_PATH = Path(
    __import__('os').getenv("ML_MODEL_PATH", str(_ML_BASE / "travel_time_rf.pkl"))
)

class TravelTimePredictor:
    def __init__(self):
        self.model = None
        self.model_loaded = False
        
    def load(self):
        logger.info("Loading Random Forest Model...")
        try:
            self.model = joblib.load(MODEL_PATH)
            self.model_loaded = True
            logger.info("Model loaded successfully.")
            print("ML model loaded.")
        except FileNotFoundError:
            logger.error(f"[ML] Model file not found: {MODEL_PATH}")
            self.model = None
            self.model_loaded = False
        except Exception as e:
            logger.error(f"[ML] Failed to load model: {e}")
            self.model = None
            self.model_loaded = False
        
    def predict_leg_time(self, mode_str, distance_m, hour=10, day_of_week=0, zone=1):
        """
        Predict travel time for a single leg.
        
        Args:
            mode_str: "bus", "metro", or "walk"
            distance_m: distance in meters
            hour: 0-23 (hour of day)
            day_of_week: 0-6 (Mon=0, Sun=6)
            zone: congestion zone (1-3)
            
        Returns:
            Predicted duration in seconds.
        """
        if self.model is None:
            raise ValueError("Model not loaded")
            
        mode_map = {"bus": 0, "metro": 1, "walk": 2}
        mode_encoded = mode_map.get(mode_str, 2)
        
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
