import { Marker } from 'react-leaflet';
import L from 'leaflet';

/**
 * CustomMarkers — SVG div-icon markers for start, end, and transfer points.
 */

const createSvgIcon = (svgHtml, size = 28, anchor = null) => {
    return L.divIcon({
        html: svgHtml,
        className: 'custom-marker',
        iconSize: [size, size],
        iconAnchor: anchor || [size / 2, size / 2],
    });
};

const startIcon = createSvgIcon(
    `<svg width="28" height="28" viewBox="0 0 28 28">
    <circle cx="14" cy="14" r="12" fill="#10b981" stroke="white" stroke-width="3"/>
    <circle cx="14" cy="14" r="5" fill="white"/>
  </svg>`
);

const destIcon = createSvgIcon(
    `<svg width="28" height="36" viewBox="0 0 28 36">
    <path d="M14 0C6.268 0 0 6.268 0 14c0 10.5 14 22 14 22s14-11.5 14-22C28 6.268 21.732 0 14 0z" fill="#ef4444" stroke="white" stroke-width="2"/>
    <circle cx="14" cy="14" r="6" fill="white"/>
  </svg>`,
    28,
    [14, 36]
);

const transferIcon = (color = '#f59e0b') => createSvgIcon(
    `<svg width="18" height="18" viewBox="0 0 18 18">
    <circle cx="9" cy="9" r="7" fill="${color}" stroke="white" stroke-width="2"/>
  </svg>`,
    18
);

const MODE_COLORS = {
    walk: '#6b7280',
    bus: '#3b82f6',
    metro: '#8b5cf6',
};

export default function CustomMarkers({ source, dest, selectedRoute }) {
    // Identify transfer points (where mode changes)
    const transferPoints = [];
    if (selectedRoute && selectedRoute.legs) {
        const legs = selectedRoute.legs;
        for (let i = 1; i < legs.length; i++) {
            if (legs[i].mode !== legs[i - 1].mode) {
                const node = legs[i].from_node;
                if (node) {
                    transferPoints.push({
                        lat: node.lat,
                        lon: node.lon,
                        mode: legs[i].mode,
                    });
                }
            }
        }
    }

    return (
        <>
            {source && (
                <Marker position={source} icon={startIcon} />
            )}
            {dest && (
                <Marker position={dest} icon={destIcon} />
            )}
            {transferPoints.map((tp, idx) => (
                <Marker
                    key={`transfer-${idx}`}
                    position={[tp.lat, tp.lon]}
                    icon={transferIcon(MODE_COLORS[tp.mode] || '#f59e0b')}
                />
            ))}
        </>
    );
}
