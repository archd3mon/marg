import math
from app.ml.inference import predictor

TRANSFER_PENALTY_MINS = 10.0
MODE_PENALTY = {
    "bus": 5.0,     # Bus is less comfortable
    "metro": 1.0,   # Metro is preferred
    "walk": 15.0    # Heavy walk penalty to minimize raw walking
}

def score_and_rank_routes(top_k_paths, departure_hour=10, departure_day=0):
    """
    Takes the raw structurally-viable paths from Yen's Algorithm and scores them.
    Total Cost = TravelTime + (Transfers * TransferPenalty) + ModePenalties
    """
    ranked_routes = []
    
    for path in top_k_paths:
        total_time_sec = 0
        total_mode_penalty = 0
        
        for leg in path['legs']:
            duration_sec = predictor.predict_leg_time(
                mode_str=leg['mode'],
                distance_m=leg['length_m'],
                hour=departure_hour,
                day_of_week=departure_day
            )
            leg['duration_sec'] = duration_sec
            leg['duration_mins'] = math.ceil(duration_sec / 60)
            
            total_time_sec += duration_sec
            total_mode_penalty += MODE_PENALTY.get(leg['mode'], 5.0)
            
        total_time_mins = total_time_sec / 60
        transfers = path['transfers']
        
        # Scoring Formula
        score = total_time_mins + (transfers * TRANSFER_PENALTY_MINS) + total_mode_penalty
        
        ranked_routes.append({
            "score": round(score, 2),
            "total_time_mins": math.ceil(total_time_mins),
            "transfers": transfers,
            "legs": path['legs']
        })
        
    # Sort ascending by score (lowest is best)
    ranked_routes.sort(key=lambda x: x['score'])
    
    # Assign semantic ranking
    for idx, r in enumerate(ranked_routes):
        r['rank'] = idx + 1
        
    return ranked_routes
