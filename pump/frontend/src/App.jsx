import { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Polyline, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import { getStops, searchRoutes } from './api';
import './index.css';

// Fix leaflet icon paths
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// Map click handler component
function MapClickHandler({ setSource, setDest, selectingSource }) {
  useMapEvents({
    click(e) {
      if (selectingSource) {
        setSource(e.latlng);
      } else {
        setDest(e.latlng);
      }
    },
  });
  return null;
}

export default function App() {
  const [source, setSource] = useState(null);
  const [dest, setDest] = useState(null);
  const [selectingSource, setSelectingSource] = useState(true);

  const [routes, setRoutes] = useState([]);
  const [selectedRouteIdx, setSelectedRouteIdx] = useState(0);
  const [loading, setLoading] = useState(false);

  // default pune coords
  const puneCenter = [18.5204, 73.8567];

  const handleSearch = async () => {
    if (!source || !dest) return;
    setLoading(true);
    try {
      const data = await searchRoutes(source, dest, new Date());
      setRoutes(data.routes || []);
      setSelectedRouteIdx(0);
    } catch (err) {
      console.error(err);
      alert("Error finding routes. Check backend connection.");
    } finally {
      setLoading(false);
    }
  };

  const getLegColor = (mode) => {
    if (mode === 'metro') return '#0ea5e9';
    if (mode === 'bus') return '#ef4444';
    return '#8b5cf6'; // walk
  };

  return (
    <div className="app-container">
      {/* SIDEBAR */}
      <div className="sidebar">
        <div className="sidebar-header">
          <h1>Marg</h1>
          <p>Pune Urban Mobility Planner</p>
        </div>

        <div className="search-form">
          <div className="input-group">
            <label>Source {selectingSource && "(Click on Map)"}</label>
            <input
              type="text"
              readOnly
              value={source ? `${source.lat.toFixed(4)}, ${source.lng.toFixed(4)}` : ''}
              placeholder="Select on Map"
              onClick={() => setSelectingSource(true)}
              style={{ borderColor: selectingSource ? '#2563eb' : '#e2e8f0' }}
            />
          </div>

          <div className="input-group">
            <label>Destination {!selectingSource && "(Click on Map)"}</label>
            <input
              type="text"
              readOnly
              value={dest ? `${dest.lat.toFixed(4)}, ${dest.lng.toFixed(4)}` : ''}
              placeholder="Select on Map"
              onClick={() => setSelectingSource(false)}
              style={{ borderColor: !selectingSource ? '#2563eb' : '#e2e8f0' }}
            />
          </div>

          <button
            className="search-btn"
            onClick={handleSearch}
            disabled={!source || !dest || loading}
          >
            {loading ? 'Crunching Routes...' : 'Find Routes'}
          </button>
        </div>

        <div className="results-area">
          {routes.length === 0 && !loading && (
            <p style={{ color: '#64748b', textAlign: 'center' }}>No routes generated. Pick start and end nodes.</p>
          )}

          {routes.map((route, idx) => (
            <div
              key={idx}
              className={`route-card ${selectedRouteIdx === idx ? 'selected' : ''}`}
              onClick={() => setSelectedRouteIdx(idx)}
            >
              <div className="route-header">
                <span className="route-time">{route.total_time_mins} min</span>
                <span className="route-transfers">{route.transfers} transfer{route.transfers !== 1 ? 's' : ''}</span>
              </div>

              <div className="leg-visualizer">
                {route.legs.map((leg, lIdx) => (
                  <div key={lIdx} className="leg-item">
                    <div className={`leg-icon ${leg.mode}`}>
                      {leg.mode === 'metro' ? '🚇' : leg.mode === 'bus' ? '🚌' : '🚶'}
                    </div>
                    <span>
                      {leg.mode.toUpperCase()} for {leg.duration_mins} min ({(leg.length_m / 1000).toFixed(1)} km)
                    </span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* MAP AREA */}
      <div className="map-area">
        <MapContainer center={puneCenter} zoom={13} style={{ height: '100%', width: '100%' }}>
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
            url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
          />
          <MapClickHandler setSource={setSource} setDest={setDest} selectingSource={selectingSource} />

          {source && <Marker position={source} />}
          {dest && <Marker position={dest} />}

          {/* Render selected route polylines */}
          {routes[selectedRouteIdx] && routes[selectedRouteIdx].legs.map((leg, idx) => {
            const startNode = leg.from_node;
            const endNode = leg.to_node;
            return (
              <Polyline
                key={idx}
                positions={[
                  [startNode.lat, startNode.lon],
                  [endNode.lat, endNode.lon]
                ]}
                color={getLegColor(leg.mode)}
                weight={leg.mode === 'walk' ? 4 : 6}
                dashArray={leg.mode === 'walk' ? '5, 10' : ''}
              />
            )
          })}
        </MapContainer>
      </div>
    </div>
  );
}
