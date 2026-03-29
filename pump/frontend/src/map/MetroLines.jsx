import { useEffect } from 'react';
import { useMap } from 'react-leaflet';
import L from 'leaflet';

const LINE_COLORS = {
    'Purple': '#9B59B6',
    'Aqua': '#1ABC9C',
};

export default function MetroLines() {
    const map = useMap();

    useEffect(() => {
        let metroLayer = null;

        fetch('/metro_lines.geojson')
            .then(res => res.json())
            .then(data => {
                metroLayer = L.geoJSON(data, {
                    style: (feature) => {
                        const name = feature.properties?.name || '';
                        let color = '#888';
                        if (name.includes('Purple') || name.includes('Line 1')) color = LINE_COLORS.Purple;
                        else if (name.includes('Aqua') || name.includes('Line 2')) color = LINE_COLORS.Aqua;

                        return {
                            color,
                            weight: 3.5,
                            opacity: 0.7,
                            lineCap: 'round',
                            lineJoin: 'round',
                        };
                    },
                    filter: (feature) => {
                        const props = feature.properties || {};
                        // Only show main operational subway lines
                        if (props.railway !== 'subway') return false;
                        if (props.construction) return false;
                        if (props.service) return false; // Excludes yard, crossover, siding
                        if (props.usage && props.usage !== 'main') return false;
                        return true;
                    },
                    onEachFeature: (feature, layer) => {
                        const name = feature.properties?.name || 'Metro Line';
                        const shortName = name.replace('Pune Metro ', '').replace(': ', ' – ');
                        layer.bindTooltip(shortName, {
                            sticky: true,
                            className: 'metro-tooltip',
                            direction: 'top',
                            offset: [0, -8],
                        });
                    },
                });

                metroLayer.addTo(map);
            })
            .catch(err => console.warn('Failed to load metro lines:', err));

        return () => {
            if (metroLayer) {
                map.removeLayer(metroLayer);
            }
        };
    }, [map]);

    return null;
}
