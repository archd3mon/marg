import RouteCard from './RouteCard';

/**
 * RouteList — Container for route option cards.
 */
export default function RouteList({
    routes,
    selectedRouteIdx,
    onSelectRoute,
    onExpandRoute,
    loading,
    departureTime,
}) {
    if (loading) {
        return (
            <div className="route-list__loading">
                <div className="route-list__spinner" />
                <p>Crunching routes…</p>
            </div>
        );
    }

    if (routes.length === 0) {
        return (
            <div className="route-list__empty">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" style={{ opacity: 0.3 }}>
                    <path d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l5.447 2.724A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" stroke="#94a3b8" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                <p>Select origin & destination on the map, then tap <strong>Find Routes</strong></p>
            </div>
        );
    }

    return (
        <div className="route-list">
            <div className="route-list__header">
                <span className="route-list__count">{routes.length} route{routes.length !== 1 ? 's' : ''} found</span>
            </div>
            {routes.map((route, idx) => (
                <RouteCard
                    key={idx}
                    route={route}
                    index={idx}
                    isSelected={selectedRouteIdx === idx}
                    onSelect={onSelectRoute}
                    onExpand={onExpandRoute}
                    departureTime={departureTime}
                />
            ))}
        </div>
    );
}
