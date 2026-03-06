import { MapContainer, TileLayer, useMapEvents, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import RoutePolylines from './RoutePolylines';
import CustomMarkers from './CustomMarkers';
import { useEffect } from 'react';

// Fix leaflet icon paths
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// Map click handler
function MapClickHandler({ onMapClick }) {
    useMapEvents({
        click(e) {
            onMapClick(e.latlng);
        },
    });
    return null;
}

// Fit bounds to route when selected
function FitRouteBounds({ route }) {
    const map = useMap();

    useEffect(() => {
        if (!route || !route.legs || route.legs.length === 0) return;

        const bounds = [];
        for (const leg of route.legs) {
            if (leg.from_node) bounds.push([leg.from_node.lat, leg.from_node.lon]);
            if (leg.to_node) bounds.push([leg.to_node.lat, leg.to_node.lon]);
        }

        if (bounds.length > 1) {
            map.flyToBounds(L.latLngBounds(bounds), {
                padding: [50, 50],
                duration: 0.8,
                maxZoom: 15,
            });
        }
    }, [route, map]);

    return null;
}

const PUNE_CENTER = [18.5204, 73.8567];

export default function MapView({
    source,
    dest,
    selectedRoute,
    onMapClick,
    isMobile,
}) {
    return (
        <div className="map-view">
            <MapContainer
                center={PUNE_CENTER}
                zoom={13}
                style={{ height: '100%', width: '100%' }}
                zoomControl={!isMobile}
                attributionControl={false}
            >
                <TileLayer
                    attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/">CARTO</a>'
                    url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
                />

                <MapClickHandler onMapClick={onMapClick} />
                <CustomMarkers source={source} dest={dest} selectedRoute={selectedRoute} />
                <RoutePolylines route={selectedRoute} />
                <FitRouteBounds route={selectedRoute} />
            </MapContainer>
        </div>
    );
}
