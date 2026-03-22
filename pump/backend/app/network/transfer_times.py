import logging

logger = logging.getLogger(__name__)

# Transfer times in minutes for known Pune transit hubs
KNOWN_TRANSFERS = {
    ("metro", "bus", "Swargate"): 4.0,
    ("bus", "metro", "Swargate"): 4.0,
    ("metro", "bus", "Shivaji Nagar"): 6.0,
    ("bus", "metro", "Shivaji Nagar"): 6.0,
    ("metro", "bus", "Pune Railway Station"): 5.0,
    ("bus", "metro", "Pune Railway Station"): 5.0,
    ("metro", "bus", "Civil Court"): 3.0,
    ("bus", "metro", "Civil Court"): 3.0,
    ("metro", "bus", "Nal Stop"): 2.0,
    ("bus", "metro", "Nal Stop"): 2.0,
    ("metro", "bus", "Deccan Gymkhana"): 3.0,
    ("bus", "metro", "Deccan Gymkhana"): 3.0,
}

DEFAULT_TRANSFER_TIMES = {
    ("metro", "metro"): 3.0,   # Changing lines
    ("bus", "bus"): 12.0,      # Waiting for next bus
    ("metro", "bus"): 8.0,     # Walking down from station + waiting
    ("bus", "metro"): 6.0,     # Walking up to station + next train
}

def get_transfer_time(from_mode: str, to_mode: str, node_name: str = None) -> float:
    """Get estimated transfer time in minutes."""
    if node_name:
        # Try exact match
        key = (from_mode, to_mode, node_name)
        if key in KNOWN_TRANSFERS:
            return KNOWN_TRANSFERS[key]
            
        # Try substring match for hubs
        for (m1, m2, hub), t_time in KNOWN_TRANSFERS.items():
            if m1 == from_mode and m2 == to_mode and hub.lower() in node_name.lower():
                return t_time

    dt_key = (from_mode, to_mode)
    return DEFAULT_TRANSFER_TIMES.get(dt_key, 8.0)
