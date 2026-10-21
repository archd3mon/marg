#!/usr/bin/env python3
"""Measure startup RSS memory and cold-start time for Marg backend using psutil."""
import os
import sys
import time
from pathlib import Path
import psutil

# Ensure pump/backend is on python path
REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = REPO_ROOT / "pump" / "backend"
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

def measure_startup():
    proc = psutil.Process(os.getpid())
    rss_initial_mb = proc.memory_info().rss / (1024 * 1024)
    t0 = time.perf_counter()

    # Step 1: Import app components
    t_import_start = time.perf_counter()
    from app.network.graph import engine
    from app.ml.inference import predictor
    from app.search.search import search_engine
    from app.main import app
    t_import_end = time.perf_counter()

    # Step 2: Load engines (simulating lifespan cold start)
    t_load_start = time.perf_counter()
    engine.load()
    t_engine_loaded = time.perf_counter()

    predictor.load()
    t_predictor_loaded = time.perf_counter()

    search_engine.load()
    t_search_loaded = time.perf_counter()

    # Also check POI db loading if present
    from app.paths import DATA_ROOT as DATA_DIR
    import sqlite3
    poi_db_path = DATA_DIR / "processed" / "pune_poi.sqlite"
    if poi_db_path.exists():
        conn = sqlite3.connect(str(poi_db_path), check_same_thread=False)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM pois")
        poi_count = cur.fetchone()[0]
        conn.close()
    else:
        poi_count = 0
    t_total_ready = time.perf_counter()

    # Measure memory
    mem_info = proc.memory_info()
    rss_final_mb = mem_info.rss / (1024 * 1024)
    vms_mb = mem_info.vms / (1024 * 1024)

    total_cold_start_s = t_total_ready - t0
    import_time_s = t_import_end - t_import_start
    engine_load_s = t_engine_loaded - t_load_start
    predictor_load_s = t_predictor_loaded - t_engine_loaded
    search_load_s = t_search_loaded - t_predictor_loaded

    results = {
        "python_version": sys.version.split()[0],
        "platform": sys.platform,
        "cpu_count": psutil.cpu_count(logical=True),
        "total_ram_gb": round(psutil.virtual_memory().total / (1024**3), 2),
        "initial_rss_mb": round(rss_initial_mb, 2),
        "startup_rss_mb": round(rss_final_mb, 2),
        "vms_mb": round(vms_mb, 2),
        "cold_start_total_s": round(total_cold_start_s, 2),
        "import_time_s": round(import_time_s, 2),
        "engine_load_s": round(engine_load_s, 2),
        "predictor_load_s": round(predictor_load_s, 2),
        "search_load_s": round(search_load_s, 2),
        "routing_available": engine.routing_available,
        "nodes": len(engine.G.nodes) if engine.G else 0,
        "edges": len(engine.G.edges) if engine.G else 0,
        "poi_count": poi_count,
    }

    print("--- Marg Baseline Startup Performance ---")
    for k, v in results.items():
        print(f"{k}: {v}")

    return results

if __name__ == "__main__":
    measure_startup()
