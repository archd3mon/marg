import { Polyline } from 'react-leaflet';

/**
 * RoutePolylines — Color-coded polylines for the selected route.
 * Walk: gray dashed, Bus: blue solid, Metro: purple solid.
 */

const MODE_STYLES = {
    walk: { color: '#6b7280', weight: 4, dashArray: '6, 10', opacity: 0.8 },
    bus: { color: '#3b82f6', weight: 5, dashArray: null, opacity: 0.9 },
    metro: { color: '#8b5cf6', weight: 6, dashArray: null, opacity: 0.9 },
};

export default function RoutePolylines({ route }) {
    if (!route || !route.legs) return null;

    return (
        <>
            {route.legs.map((leg, idx) => {
                const from = leg.from_node;
                const to = leg.to_node;
                if (!from || !to) return null;

                const style = MODE_STYLES[leg.mode] || MODE_STYLES.walk;

                return (
                    <Polyline
                        key={idx}
                        positions={leg.path || [
                            [from.lat, from.lon],
                            [to.lat, to.lon],
                        ]}
                        pathOptions={{
                            color: style.color,
                            weight: style.weight,
                            dashArray: style.dashArray,
                            opacity: style.opacity,
                            lineJoin: 'round',
                            lineCap: 'round',
                        }}
                    />
                );
            })}
        </>
    );
}
