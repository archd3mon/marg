# Branch Diff: `research/revision-1` vs `origin/main`

**Baseline tag:** `pre-revision-baseline`  
**Compared targets:** `pump/backend/` and `pump/data/` (referenced as `backend` and `data`)  
**Base commit:** `origin/main`  
**Current HEAD:** `research/revision-1` (`8eb763b`)  

---

## 1. Executive Summary

- **Core Routing Engine Logic:** **Identical** to `origin/main`. No changes were made to RAPTOR (`app/transit/raptor.py`), Multimodal A* graph search (`app/network/graph.py`), graph generation, or ML model architecture.
- **Dataset / Graph Pickles (`pump/data/`):** **0 differences** (binary identical).
- **Material Logic Differences:** **None**. The diff consists entirely of:
  1. Portable relative path configuration (`app/paths.py`) replacing hardcoded host paths.
  2. Additive API contract adaptations (`/`, `/api/v1/network/stops/nearby`, client response normalization `_normalize_for_clients`, and `exclude_metro` preference support).
  3. API contract tests (`tests/test_api_contract.py`) and fixture capture tooling (`scripts/capture_fixtures.py`).

---

## 2. File-by-File Analysis

### A. Data Directory (`pump/data/`)
- **Status:** Unmodified (0 files changed, 0 lines diff).

### B. Core Application (`pump/backend/app/`)
| File | Changes | Description / Impact |
|------|---------|----------------------|
| `app/paths.py` | +27 lines (new file) | Introduces dynamic path resolution (`DATA_ROOT`, `PROCESSED_DIR`, `MODELS_DIR`, `GTFS_DIR`) with fallback to relative paths, eliminating hardcoded machine paths. |
| `app/ml/inference.py` | +3, -1 lines | Replaced hardcoded path with `from app.paths import MODELS_DIR`. |
| `app/network/graph.py` | +1, -1 lines | Replaced hardcoded path with `from app.paths import PROCESSED_DIR as DATA_DIR`. |
| `app/search/search.py` | +1, -1 lines | Replaced hardcoded path with `from app.paths import PROCESSED_DIR as DATA_DIR`. |
| `app/transit/gtfs_loader.py` | +1, -4 lines | Replaced hardcoded path with `from app.paths import GTFS_DIR`. |
| `app/scoring/ranker.py` | +1, -1 lines | Added `or mode_preferences.get("less_walking")` alongside `avoid_walking` in `_build_mode_penalties`. |
| `app/main.py` | +84, -2 lines | Additive enhancements: <br>1. Added root endpoint `GET /` returning system metadata.<br>2. Added `GET /api/v1/network/stops/nearby` with haversine distance filtering and sorting.<br>3. Added `_normalize_for_clients()` helper ensuring output conforms to client contract (`route_type`, `line_options`, `uses_metro`, `total_walk_m`, fallback durations/paths).<br>4. Added `_exclude_metro()` filter handling `exclude_metro` client preference for bus-only v1 queries.<br>5. Explicitly marked direct-walk fallback route as `route_type: "fastest"`. |

### C. Backend Offline Scripts (`pump/backend/scripts/`)
| File | Changes | Description |
|------|---------|-------------|
| `scripts/capture_fixtures.py` | +55 lines (new file) | Captures real endpoint responses for mobile unit/widget test fixtures. |
| `scripts/build_graph.py` | +3, -3 lines | Replaced hardcoded paths with portable paths. |
| `scripts/build_osm_graph.py` | +2, -2 lines | Replaced hardcoded paths with portable paths. |
| `scripts/generate_synthetic_data.py` | +2, -2 lines | Replaced hardcoded paths with portable paths. |
| `scripts/parse_datasets.py` | +3, -3 lines | Replaced hardcoded paths with portable paths. |
| `scripts/train_model.py` | +2, -2 lines | Replaced hardcoded paths with portable paths. |
| `scripts/validate_datasets.py` | +2, -2 lines | Replaced hardcoded paths with portable paths. |

### D. Testing & Dependency Configuration
| File | Changes | Description |
|------|---------|-------------|
| `tests/conftest.py` | +16 lines (new file) | Configures `client` session fixture using FastAPI `TestClient`. |
| `tests/test_api_contract.py` | +243 lines (new file) | Contract test suite verifying all required API fields, schemas, and error responses. |
| `requirements.txt` | +1 line | Added `pytz`. |
| `requirements-dev.txt` | +2 lines | Added `pytest` and `httpx`. |
| `.env.example` | +2, -1 lines | Updated sample environment variables. |

---

## 3. Assessment

The routing logic, cost functions, RAPTOR structure building, multimodal A* graph expansion, and machine learning models are **materially unchanged** between `origin/main` and `research/revision-1`. All modifications are non-breaking, additive API compatibility updates and environment portability enhancements.
