import math
import logging
from app.network.transfer_times import get_transfer_time

logger = logging.getLogger(__name__)

# --- Default Scoring Parameters ---
TRANSFER_PENALTY_MINS = 8.0
WALK_DISTANCE_PENALTY_PER_KM = 12.0   # Extra penalty per km walked
MAX_COMFORTABLE_WALK_M = 800           # Walking distance before heavy penalty kicks in

DEFAULT_MODE_PENALTY = {
    "bus": 4.0,
    "metro": 0.5,     # Metro is strongly preferred
    "walk": 8.0,
}

# Comfort bonus: routes that use metro get a discount
METRO_COMFORT_BONUS = -15.0  # Strong preference for metro (reduces score significantly)


def _build_mode_penalties(mode_preferences):
    """Adjust mode penalties based on user preferences."""
    penalties = dict(DEFAULT_MODE_PENALTY)

    if not mode_preferences:
        return penalties

    if mode_preferences.get("prefer_metro"):
        penalties["metro"] = 0.0
        penalties["bus"] = 8.0

    if mode_preferences.get("prefer_bus"):
        penalties["bus"] = 0.0
        penalties["metro"] = 8.0

    if mode_preferences.get("avoid_walking"):
        penalties["walk"] = DEFAULT_MODE_PENALTY["walk"] * 3.0

    return penalties


def score_and_rank_routes(top_k_paths, departure_hour=10, departure_day=0,
                          mode_preferences=None, predictor=None):
    """
    Score and rank routes using ML-predicted travel times + penalty heuristics.

    Score = TravelTime + (Transfers × TransferPenalty) + ModePenalties + WalkingPenalty + ComfortBonus
    Lower score is better.

    Args:
        top_k_paths: list of route dicts from the routing engine
        departure_hour: 0-23
        departure_day: 0-6
        mode_preferences: dict with optional keys: prefer_metro, prefer_bus, avoid_walking
        predictor: TravelTimePredictor instance (optional, falls back to graph times if None)
    """
    mode_penalty = _build_mode_penalties(mode_preferences)
    ranked_routes = []

    for path in top_k_paths:
        total_time_sec = 0
        total_mode_penalty = 0
        total_walk_m = 0
        uses_metro = False

        for leg in path["legs"]:
            # --- ML-enhanced travel time prediction (Upgrade 2) ---
            duration_sec = None

            # Try ML prediction first if predictor is available
            if predictor is not None and predictor.model is not None and leg["mode"] in ("bus", "metro", "walk"):
                try:
                    duration_sec = predictor.predict_leg_time(
                        mode_str=leg["mode"],
                        distance_m=leg.get("length_m", 0.0),
                        hour=departure_hour,
                        day_of_week=departure_day,
                        zone=1,  # Default congestion zone
                    )
                except Exception as e:
                    logger.warning(f"[ML] Prediction failed for {leg['mode']} leg, falling back to graph time: {e}")
                    duration_sec = None

            # Fallback: use deterministic travel time from graph
            if duration_sec is None:
                if leg.get("travel_time", 0) > 0:
                    duration_sec = leg["travel_time"]
                else:
                    # Last resort: walk speed (1.4m/s)
                    duration_sec = leg.get("length_m", 0.0) / 1.4

            leg["duration_sec"] = duration_sec
            leg["duration_mins"] = math.ceil(duration_sec / 60)

            total_time_sec += duration_sec
            total_mode_penalty += mode_penalty.get(leg["mode"], 5.0)

            if leg["mode"] == "walk":
                total_walk_m += leg.get("length_m", 0.0)
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
        if transfers == 0:
            comfort -= 20.0 # Huge bonus for direct routes

        # Advanced Transfer Logic (Upgrade 8)
        transfer_penalty_total = 0.0
        last_transit_mode = None
        
        for i, leg in enumerate(path["legs"]):
            if leg["mode"] in ("bus", "metro"):
                if last_transit_mode:
                    # We have a consecutive or walk-interrupted transit leg
                    # Let's assess the transfer cost
                    node_name = leg["from_node"].get("name", "")
                    transfer_penalty_total += get_transfer_time(last_transit_mode, leg["mode"], node_name)
                last_transit_mode = leg["mode"]

        # Fallback if the path didn't explicitly separate legs but transfers > 0
        if transfers > 0 and transfer_penalty_total == 0:
            transfer_penalty_total = transfers * TRANSFER_PENALTY_MINS

        total_route_dist_m = sum(leg.get("length_m", 0.0) for leg in path.get("legs", []))
        if total_route_dist_m < 5000 and transfers >= 1:
            # Aggressively penalize transit-swapping on short routes (+15 mins per transfer)
            transfer_penalty_total += transfers * 15.0

        # Final scoring formula
        score = (
            total_time_mins
            + transfer_penalty_total
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

    if ranked_routes:
        # Metro priority: if a metro route is within 15 min of fastest and has
        # fewer transfers, promote it to #1 (recommended)
        fastest_time = min(r["total_time_mins"] for r in ranked_routes)
        metro_candidates = [
            r for r in ranked_routes
            if r["uses_metro"] and r["total_time_mins"] <= fastest_time + 15
        ]
        if metro_candidates:
            # Pick the best metro route (fewest transfers, then fastest)
            best_metro = min(metro_candidates, key=lambda r: (r["transfers"], r["total_time_mins"]))
            # Move it to position 0
            ranked_routes.remove(best_metro)
            ranked_routes.insert(0, best_metro)

        ranked_routes[0]["route_type"] = "recommended"
        
        # Sort by total time
        fastest = min(ranked_routes, key=lambda x: x["total_time_mins"])
        if "route_type" not in fastest:
            fastest["route_type"] = "fastest"
            
        # Sort by transfers
        least_transfers = min(ranked_routes, key=lambda x: x["transfers"])
        if "route_type" not in least_transfers:
            least_transfers["route_type"] = "least_transfers"
            
        # Sort by walking
        least_walking = min(ranked_routes, key=lambda x: x["total_walk_m"])
        if "route_type" not in least_walking:
            least_walking["route_type"] = "least_walking"
            
        # Default label for others
        for r in ranked_routes:
            if "route_type" not in r:
                r["route_type"] = "alternative"

    for idx, r in enumerate(ranked_routes):
        r["rank"] = idx + 1

    return ranked_routes
