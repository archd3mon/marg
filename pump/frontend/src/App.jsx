import { useState, useEffect, useCallback } from 'react';
import { ToastContainer, toast } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';
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
  const [sourceName, setSourceName] = useState('');
  const [destName, setDestName] = useState('');
  const [selectingSource, setSelectingSource] = useState(true);
  const [routes, setRoutes] = useState([]);
  const [warnings, setWarnings] = useState([]);
  const [selectedRouteIdx, setSelectedRouteIdx] = useState(0);
  const [expandedRoute, setExpandedRoute] = useState(null);
  const [loading, setLoading] = useState(false);
  const [departureTime] = useState(new Date());
  const [hoveredLegIndex, setHoveredLegIndex] = useState(null);
  const [modePreferences, setModePreferences] = useState({
    prefer_metro: false,
    prefer_bus: false,
    avoid_walking: false,
  });

  // --- Handlers ---
  const handleMapClick = useCallback((latlng) => {
    if (selectingSource) {
      setSource(latlng);
      setSourceName('');
      setSelectingSource(false);
      toast.info("📍 Origin set. Tap map for destination.", {
        position: "top-center",
        autoClose: 2500,
        hideProgressBar: true,
        closeOnClick: true,
        pauseOnHover: false,
        draggable: true,
        theme: "colored"
      });
    } else {
      setDest(latlng);
      setDestName('');
      setSelectingSource(true);
      toast.success("🏁 Destination set.", {
        position: "top-center",
        autoClose: 2000,
        hideProgressBar: true,
        closeOnClick: true,
        pauseOnHover: false,
        draggable: true,
        theme: "colored"
      });
    }
  }, [selectingSource]);

  const handleSelectSource = useCallback((point, name) => {
    setSource(point);
    setSourceName(name || '');
    setSelectingSource(false);
  }, []);

  const handleSelectDest = useCallback((point, name) => {
    setDest(point);
    setDestName(name || '');
    setSelectingSource(true);
  }, []);

  const handleSearch = useCallback(async () => {
    if (!source || !dest) return;
    setLoading(true);
    setExpandedRoute(null);
    try {
      // Build mode prefs — only send non-false values
      const activePrefs = {};
      for (const [k, v] of Object.entries(modePreferences)) {
        if (v) activePrefs[k] = true;
      }
      const prefs = Object.keys(activePrefs).length > 0 ? activePrefs : null;

      const data = await searchRoutes(source, dest, departureTime, prefs);
      setRoutes(data.routes || []);
      setWarnings(data.warnings || []);
      setSelectedRouteIdx(0);
    } catch (err) {
      console.error('Route search error:', err);
    } finally {
      setLoading(false);
    }
  }, [source, dest, departureTime, modePreferences]);

  const handleSwap = useCallback(() => {
    setSource(dest);
    setDest(source);
    const tmpName = sourceName;
    setSourceName(destName);
    setDestName(tmpName);
    setRoutes([]);
    setExpandedRoute(null);
  }, [source, dest, sourceName, destName]);

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

  const handleModePreferenceChange = useCallback((key) => {
    setModePreferences((prev) => ({ ...prev, [key]: !prev[key] }));
  }, []);

  const selectedRoute = routes[selectedRouteIdx] || null;

  // --- Desktop Layout ---
  if (!isMobile) {
    return (
      <div className="app app--desktop">
        <ToastContainer />
        <aside className="sidebar">
          <SearchPanel
            source={source}
            dest={dest}
            sourceName={sourceName}
            destName={destName}
            onSelectSource={handleSelectSource}
            onSelectDest={handleSelectDest}
            selectingSource={selectingSource}
            setSelectingSource={setSelectingSource}
            onSearch={handleSearch}
            loading={loading}
            onSwap={handleSwap}
            isMobile={false}
            modePreferences={modePreferences}
            onModePreferenceChange={handleModePreferenceChange}
          />

          <div className="sidebar__results">
            {expandedRoute !== null && routes[expandedRoute] ? (
              <ItineraryPanel
                route={routes[expandedRoute]}
                onClose={handleCloseItinerary}
                hoveredLegIndex={hoveredLegIndex}
                onHoverLeg={setHoveredLegIndex}
              />
            ) : (
              <RouteList
                routes={routes}
                warnings={warnings}
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
            hoveredLegIndex={hoveredLegIndex}
          />
        </main>
      </div>
    );
  }

  // --- Mobile Layout ---
  return (
    <div className="app app--mobile">
      <ToastContainer />
      <div className="mobile-search">
        <SearchPanel
          source={source}
          dest={dest}
          sourceName={sourceName}
          destName={destName}
          onSelectSource={handleSelectSource}
          onSelectDest={handleSelectDest}
          selectingSource={selectingSource}
          setSelectingSource={setSelectingSource}
          onSearch={handleSearch}
          loading={loading}
          onSwap={handleSwap}
          isMobile={true}
          modePreferences={modePreferences}
          onModePreferenceChange={handleModePreferenceChange}
        />
      </div>

      <MapView
        source={source}
        dest={dest}
        selectedRoute={selectedRoute}
        onMapClick={handleMapClick}
        isMobile={true}
        hoveredLegIndex={hoveredLegIndex}
      />

      <BottomSheet
        routes={routes}
        warnings={warnings}
        selectedRouteIdx={selectedRouteIdx}
        onSelectRoute={handleSelectRoute}
        expandedRoute={expandedRoute}
        onExpandRoute={handleExpandRoute}
        onCloseItinerary={handleCloseItinerary}
        loading={loading}
        departureTime={departureTime}
        hoveredLegIndex={hoveredLegIndex}
        onHoverLeg={setHoveredLegIndex}
      />
    </div>
  );
}
