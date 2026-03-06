import math
from app.ml.inference import predictor

# --- Scoring Parameters ---
TRANSFER_PENALTY_MINS = 8.0
WALK_DISTANCE_PENALTY_PER_KM = 12.0   # Extra penalty per km walked
MAX_COMFORTABLE_WALK_M = 800           # Walking distance before heavy penalty kicks in

MODE_PENALTY = {
    "bus": 4.0,
    "metro": 0.5,     # Metro is strongly preferred
    "walk": 8.0,
}

# Comfort bonus: routes that use metro get a discount
METRO_COMFORT_BONUS = -5.0  # Negative = reduces score (better)


def score_and_rank_routes(top_k_paths, departure_hour=10, departure_day=0):
    """
    Score and rank routes using ML-predicted travel times + penalty heuristics.

    Score = TravelTime + (Transfers × TransferPenalty) + ModePenalties + WalkingPenalty + ComfortBonus
    Lower score is better.
    """
    ranked_routes = []

    for path in top_k_paths:
        total_time_sec = 0
        total_mode_penalty = 0
        total_walk_m = 0
        uses_metro = False

        for leg in path["legs"]:
            duration_sec = predictor.predict_leg_time(
                mode_str=leg["mode"],
                distance_m=leg["length_m"],
                hour=departure_hour,
                day_of_week=departure_day,
            )
            leg["duration_sec"] = duration_sec
            leg["duration_mins"] = math.ceil(duration_sec / 60)

            total_time_sec += duration_sec
            total_mode_penalty += MODE_PENALTY.get(leg["mode"], 5.0)

            if leg["mode"] == "walk":
                total_walk_m += leg["length_m"]
            if leg["mode"] == "metro":
                uses_metro = True

        total_time_mins = total_time_sec / 60
        transfers = path["transfers"]

        # Walking penalty: gentle up to threshold, steep beyond
        walk_penalty = 0
        if total_walk_m > MAX_COMFORTABLE_WALK_M:
            excess_km = (total_walk_m - MAX_COMFORTABLE_WALK_M) / 1000
            walk_penalty = excess_km * WALK_DISTANCE_PENALTY_PER_KM

        # Comfort bonus for metro usage
        comfort = METRO_COMFORT_BONUS if uses_metro else 0

        # Final scoring formula
        score = (
            total_time_mins
            + (transfers * TRANSFER_PENALTY_MINS)
            + total_mode_penalty
            + walk_penalty
            + comfort
        )

        ranked_routes.append({
            "score": round(score, 2),
            "total_time_mins": math.ceil(total_time_mins),
            "transfers": transfers,
            "total_walk_m": round(total_walk_m),
            "uses_metro": uses_metro,
            "legs": path["legs"],
        })

    # Sort ascending by score (lowest = best)
    ranked_routes.sort(key=lambda x: x["score"])

    for idx, r in enumerate(ranked_routes):
        r["rank"] = idx + 1

    return ranked_routes
