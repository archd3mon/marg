import ModeIcon from './ModeIcon';

/**
 * RouteCard — Summary card for a single route option.
 * Shows total time, transfers, mode chain, and estimated arrival.
 */
export default function RouteCard({ route, index, isSelected, onSelect, onExpand, departureTime }) {
    // Build unique mode chain (e.g. Walk → Bus → Metro)
    const modeChain = [];
    if (route.legs) {
        let lastMode = null;
        for (const leg of route.legs) {
            if (leg.mode !== lastMode) {
                modeChain.push(leg.mode);
                lastMode = leg.mode;
            }
        }
    }

    // Calculate estimated arrival
    const getArrivalTime = () => {
        if (!departureTime || !route.total_time_mins) return null;
        const arrival = new Date(departureTime.getTime() + route.total_time_mins * 60000);
        return arrival.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    };

    const arrivalTime = getArrivalTime();

    return (
        <div
            className={`route-card ${isSelected ? 'route-card--selected' : ''}`}
            onClick={() => onSelect(index)}
            role="button"
            tabIndex={0}
            aria-label={`Route ${index + 1}: ${route.total_time_mins} minutes, ${route.transfers} transfers`}
        >
            <div className="route-card__header">
                <div className="route-card__time-block">
                    <span className="route-card__duration">{route.total_time_mins} min</span>
                    {route.route_type && route.route_type !== 'alternative' && (
                        <span style={{
                            marginLeft: '8px',
                            padding: '2px 8px',
                            borderRadius: '12px',
                            fontSize: '0.75rem',
                            fontWeight: '600',
                            backgroundColor: route.route_type === 'fastest' ? '#dcfce7' :
                                           route.route_type === 'recommended' ? '#fef08a' : '#e0e7ff',
                            color: route.route_type === 'fastest' ? '#166534' :
                                   route.route_type === 'recommended' ? '#854d0e' : '#3730a3'
                        }}>
                            {route.route_type === 'fastest' ? '⚡ Fastest' : 
                             route.route_type === 'least_walking' ? '🚶 Min Walk' : 
                             route.route_type === 'least_transfers' ? '🔄 Direct' : 
                             route.route_type === 'recommended' ? '⭐ Recommended' : null}
                        </span>
                    )}
                    {arrivalTime && (
                        <span className="route-card__arrival">Arrive {arrivalTime}</span>
                    )}
                </div>
                <span className="route-card__transfers">
                    {route.transfers} transfer{route.transfers !== 1 ? 's' : ''}
                </span>
            </div>

            <div className="route-card__modes">
                {modeChain.map((mode, i) => (
                    <span key={i} className="route-card__mode-step">
                        <ModeIcon mode={mode} size={18} />
                        <span className="route-card__mode-label">{mode}</span>
                        {i < modeChain.length - 1 && (
                            <svg className="route-card__arrow" width="14" height="14" viewBox="0 0 24 24" fill="none">
                                <path d="M9 5l7 7-7 7" stroke="#94a3b8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                            </svg>
                        )}
                    </span>
                ))}
            </div>

            {isSelected && (
                <button
                    className="route-card__expand-btn"
                    onClick={(e) => { e.stopPropagation(); onExpand(index); }}
                >
                    View step-by-step directions
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                        <path d="M6 9l6 6 6-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                    </svg>
                </button>
            )}
        </div>
    );
}
