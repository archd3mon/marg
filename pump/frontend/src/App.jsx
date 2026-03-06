import { useState, useEffect, useCallback } from 'react';
import { searchRoutes } from './api';
import SearchPanel from './components/SearchPanel';
import RouteList from './components/RouteList';
import ItineraryPanel from './components/ItineraryPanel';
import BottomSheet from './components/BottomSheet';
import MapView from './map/MapView';
import './index.css';

/**
 * App — Layout orchestrator.
 * Mobile (<768px): map fullscreen + search bar at top + bottom sheet
 * Desktop (≥768px): sidebar on left + map on right
 */

function useIsMobile(breakpoint = 768) {
  const [isMobile, setIsMobile] = useState(window.innerWidth < breakpoint);
  useEffect(() => {
    const mq = window.matchMedia(`(max-width: ${breakpoint - 1}px)`);
    const handler = (e) => setIsMobile(e.matches);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, [breakpoint]);
  return isMobile;
}

export default function App() {
  const isMobile = useIsMobile();

  // --- State ---
  const [source, setSource] = useState(null);
  const [dest, setDest] = useState(null);
  const [selectingSource, setSelectingSource] = useState(true);
  const [routes, setRoutes] = useState([]);
  const [selectedRouteIdx, setSelectedRouteIdx] = useState(0);
  const [expandedRoute, setExpandedRoute] = useState(null);
  const [loading, setLoading] = useState(false);
  const [departureTime] = useState(new Date());

  // --- Handlers ---
  const handleMapClick = useCallback((latlng) => {
    if (selectingSource) {
      setSource(latlng);
      setSelectingSource(false);
    } else {
      setDest(latlng);
      setSelectingSource(true);
    }
  }, [selectingSource]);

  const handleSearch = useCallback(async () => {
    if (!source || !dest) return;
    setLoading(true);
    setExpandedRoute(null);
    try {
      const data = await searchRoutes(source, dest, departureTime);
      setRoutes(data.routes || []);
      setSelectedRouteIdx(0);
    } catch (err) {
      console.error('Route search error:', err);
    } finally {
      setLoading(false);
    }
  }, [source, dest, departureTime]);

  const handleSwap = useCallback(() => {
    setSource(dest);
    setDest(source);
    setRoutes([]);
    setExpandedRoute(null);
  }, [source, dest]);

  const handleSelectRoute = useCallback((idx) => {
    setSelectedRouteIdx(idx);
    setExpandedRoute(null);
  }, []);

  const handleExpandRoute = useCallback((idx) => {
    setExpandedRoute(idx);
  }, []);

  const handleCloseItinerary = useCallback(() => {
    setExpandedRoute(null);
  }, []);

  const selectedRoute = routes[selectedRouteIdx] || null;

  // --- Desktop Layout ---
  if (!isMobile) {
    return (
      <div className="app app--desktop">
        <aside className="sidebar">
          <SearchPanel
            source={source}
            dest={dest}
            selectingSource={selectingSource}
            setSelectingSource={setSelectingSource}
            onSearch={handleSearch}
            loading={loading}
            onSwap={handleSwap}
            isMobile={false}
          />

          <div className="sidebar__results">
            {expandedRoute !== null && routes[expandedRoute] ? (
              <ItineraryPanel
                route={routes[expandedRoute]}
                onClose={handleCloseItinerary}
              />
            ) : (
              <RouteList
                routes={routes}
                selectedRouteIdx={selectedRouteIdx}
                onSelectRoute={handleSelectRoute}
                onExpandRoute={handleExpandRoute}
                loading={loading}
                departureTime={departureTime}
              />
            )}
          </div>
        </aside>

        <main className="main-map">
          <MapView
            source={source}
            dest={dest}
            selectedRoute={selectedRoute}
            onMapClick={handleMapClick}
            isMobile={false}
          />
        </main>
      </div>
    );
  }

  // --- Mobile Layout ---
  return (
    <div className="app app--mobile">
      <div className="mobile-search">
        <SearchPanel
          source={source}
          dest={dest}
          selectingSource={selectingSource}
          setSelectingSource={setSelectingSource}
          onSearch={handleSearch}
          loading={loading}
          onSwap={handleSwap}
          isMobile={true}
        />
      </div>

      <MapView
        source={source}
        dest={dest}
        selectedRoute={selectedRoute}
        onMapClick={handleMapClick}
        isMobile={true}
      />

      <BottomSheet
        routes={routes}
        selectedRouteIdx={selectedRouteIdx}
        onSelectRoute={handleSelectRoute}
        expandedRoute={expandedRoute}
        onExpandRoute={handleExpandRoute}
        onCloseItinerary={handleCloseItinerary}
        loading={loading}
        departureTime={departureTime}
      />
    </div>
  );
}
