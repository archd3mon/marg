import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error
import joblib
from pathlib import Path

OUT_DIR = Path("/home/jayant/gitgud/marg/marg/pump/data/models")
OUT_DIR.mkdir(parents=True, exist_ok=True)
MODEL_OUT = OUT_DIR / "travel_time_rf.pkl"

def generate_synthetic_data(n_samples=50000):
    print(f"Generating {n_samples} synthetic trip legs...")
    np.random.seed(42)
    
    # Features
    # 0 = Bus, 1 = Metro, 2 = Walk
    modes = np.random.choice([0, 1, 2], size=n_samples, p=[0.5, 0.2, 0.3])
    distances = np.random.uniform(50, 5000, size=n_samples) # 50m to 5km
    hours = np.random.randint(0, 24, size=n_samples)
    days = np.random.randint(0, 7, size=n_samples) # 0=Mon, 6=Sun
    congestion_zones = np.random.choice([1, 2, 3], size=n_samples) # 1=Low, 3=High
    
    # Target (Duration in seconds)
    durations = []
    for i in range(n_samples):
        mode = modes[i]
        dist = distances[i]
        hour = hours[i]
        zone = congestion_zones[i]
        
        # Base speeds (m/s)
        if mode == 1: # Metro (Very Fast, immune to traffic)
            speed = 10.0 # ~36 km/h
        elif mode == 2: # Walk (Slow, immune to traffic)
            speed = 1.4 # ~5 km/h
        else: # Bus (Variable based on hour and zone)
            base_speed = 5.0 # ~18 km/h
            
            # Rush hour penalty (8-11 AM, 5-8 PM)
            if (8 <= hour <= 11) or (17 <= hour <= 20):
                speed_penalty = 0.5 # 50% slower
            else:
                speed_penalty = 1.0
                
            # Zone penalty
            zone_penalty = 1.0 - (zone * 0.1) # Zone 3 is 30% slower than Zone 1
            
            speed = base_speed * speed_penalty * zone_penalty
            if speed < 1.0: speed = 1.0 # Minimum 3.6 km/h (walking speed)
            
        # Add slight random noise (±10%)
        duration = dist / speed
        noise = np.random.uniform(0.9, 1.1)
        durations.append(duration * noise)
        
    df = pd.DataFrame({
        'mode': modes,
        'distance_m': distances,
        'hour': hours,
        'day_of_week': days,
        'congestion_zone': congestion_zones,
        'duration_sec': durations
    })
    
    return df

def train_model(df):
    print("Training Random Forest Regressor...")
    X = df[['mode', 'distance_m', 'hour', 'day_of_week', 'congestion_zone']]
    y = df['duration_sec']
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # We use fewer estimators for the prototype to keep the pickled file small and inference fast
    rf = RandomForestRegressor(n_estimators=20, max_depth=10, random_state=42, n_jobs=-1)
    rf.fit(X_train, y_train)
    
    y_pred = rf.predict(X_test)
    mae = mean_absolute_error(y_test, y_pred)
    
    print(f"Model trained successfully. Test MAE: {mae:.2f} seconds")
    
    joblib.dump(rf, MODEL_OUT)
    print(f"Model saved to {MODEL_OUT}")

if __name__ == "__main__":
    df = generate_synthetic_data()
    train_model(df)
