import RouteCard from './RouteCard';
import { motion, AnimatePresence } from 'framer-motion';

/**
 * RouteList — Container for route option cards.
 */
export default function RouteList({
    routes,
    warnings,
    selectedRouteIdx,
    onSelectRoute,
    onExpandRoute,
    loading,
    departureTime,
    departureTimeUsed,
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
            {warnings && warnings.length > 0 && (
                <div className="route-list__warnings" style={{ backgroundColor: '#fff3cd', color: '#856404', padding: '12px', borderRadius: '8px', marginBottom: '16px', fontSize: '0.9rem', border: '1px solid #ffeeba' }}>
                    {warnings.map((w, i) => <div key={i}>⚠️ {w}</div>)}
                </div>
            )}
            <div className="route-list__header">
                <span className="route-list__count">{routes.length} route{routes.length !== 1 ? 's' : ''} found</span>
            </div>
            <AnimatePresence>
                {routes.map((route, idx) => (
                    <motion.div
                        key={idx}
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -20 }}
                        transition={{ duration: 0.3, delay: idx * 0.1 }}
                    >
                        <RouteCard
                            route={route}
                            index={idx}
                            isSelected={selectedRouteIdx === idx}
                            onSelect={onSelectRoute}
                            onExpand={onExpandRoute}
                            departureTime={departureTime}
                            departureTimeUsed={departureTimeUsed}
                        />
                    </motion.div>
                ))}
            </AnimatePresence>
        </div>
    );
}
