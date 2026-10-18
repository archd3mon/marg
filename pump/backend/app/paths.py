"""Single source of truth for data locations.

Resolution order for the data root (the folder that contains processed/, gtfs/, models/):
  1. PUMP_DATA_DIR env var. For backwards compatibility a value that ends in
     "processed" is accepted and its parent is used.
  2. <repo>/pump/data, found relative to this file (works on any machine, in
     Docker and on Render, with no configuration).
"""
import os
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
_default_root = BACKEND_DIR.parent / "data"


def _resolve_root() -> Path:
    raw = os.getenv("PUMP_DATA_DIR")
    if not raw:
        return _default_root
    p = Path(raw).expanduser()
    return p.parent if p.name == "processed" else p


DATA_ROOT = _resolve_root()
PROCESSED_DIR = DATA_ROOT / "processed"
MODELS_DIR = DATA_ROOT / "models"
GTFS_DIR = Path(os.getenv("GTFS_DATA_DIR", str(DATA_ROOT / "gtfs"))).expanduser()
