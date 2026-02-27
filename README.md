# Marg - Pune Urban Mobility Planner

Marg is a multimodal route planning application designed specifically for Pune. It integrates Metro, Bus, and Walking paths to generate efficient, time-aware, and dynamically scored routes using real-world geographic data.

## Project Structure

The project is split into two main components:
- **`pump/backend`**: A FastAPI application using NetworkX, OSMnx, and Scikit-Learn for route generation and machine learning-powered ranking.
- **`pump/frontend`**: A React application built with Vite and React-Leaflet for visualizing routes on a map.

## Setup Instructions

### 1. Backend Setup

Navigate to the backend directory:
```bash
cd pump/backend
```

Create a virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
```

Install the required Python packages:
```bash
pip install -r requirements.txt
```

Set up your environment variables:
```bash
cp .env.example .env
# Edit .env and ensure PUMP_DATA_DIR points to your processed data directory (e.g., pump/data/processed)
```

Run the FastAPI backend server:
```bash
uvicorn app.main:app --reload --port 8000
```

### 2. Frontend Setup

Navigate to the frontend directory:
```bash
cd pump/frontend
```

Install the Node dependencies:
```bash
npm install
```

Set up your environment variables (optional, defaults usually suffice for local dev):
```bash
cp .env.example .env
```

Start the Vite development server:
```bash
npm run dev
```

## Features
- **Multimodal Routing**: Combines walking, bus, and metro segments.
- **Dynamic Time-Based Routing**: Generates paths based on the requested hour and day.
- **ML Route Scoring**: Employs an intelligent inference algorithm to penalize excessive transfers or sub-optimal segments and rank routes by efficiency.
- **Interactive Visualization**: Clear Leg-by-Leg breakdown with map polylines for each mode of transport.