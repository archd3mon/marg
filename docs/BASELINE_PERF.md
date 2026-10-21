# Baseline Performance: Marg Backend Engine

**Commit Baseline:** `pre-revision-baseline` (`8eb763b`)  
**Measurement Tool:** `scripts/measure_baseline_perf.py` using `psutil`  
**Measurement Date:** 2026-10-21  

---

## 1. System Environment

| Attribute | Value |
|-----------|-------|
| **Operating System** | Windows (win32) |
| **Python Version** | 3.11.17 |
| **Logical CPU Cores** | 16 |
| **Total System RAM** | 13.86 GB |

---

## 2. Startup & Cold-Start Latency

| Phase | Duration (seconds) | Notes |
|-------|--------------------|-------|
| **Module Imports** | 2.55 s | FastAPI, NetworkX, RAPTOR, Scikit-learn, RapidFuzz |
| **Transit Graph & KD-Tree** | 5.45 s | 91,714 nodes, 239,280 edges loaded from pickle |
| **RAPTOR In-Memory Build** | 17.41 s | 8,075 stops, 1,135 routes, 55,081 trips, 1,113 route patterns, 12,626 interior footpaths |
| **ML Inference Predictor** | 1.50 s | RandomForestRegressor & DecisionTreeRegressor unpickled |
| **Local Search Engine** | 0.03 s | 5,661 searchable points + 27,567 POI SQLite records |
| **Total Cold-Start Time** | **26.97 s** | Clean process launch to `routing_available: True` |

---

## 3. Memory Footprint (psutil RSS)

| Metric | Size (MB) | Details |
|--------|-----------|---------|
| **Initial Base Process RSS** | 20.12 MB | Clean Python interpreter startup |
| **Post-Load Startup RSS** | **1,148.30 MB** | Full multimodal network + RAPTOR timetable + KD-trees in RAM |
| **Virtual Memory Size (VMS)** | 2,081.99 MB | Allocated address space |

---

## 4. Graph & Network State

- **Nodes:** 91,714
- **Edges:** 239,280
  - Road edges: 192,455
  - Walk edges: 33,250
  - Bus edges: 13,519
  - Metro edges: 56
- **POIs:** 27,567
- **Routing Available:** `True`
