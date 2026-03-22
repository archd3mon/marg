import ModeIcon from './ModeIcon';

/**
 * ItineraryPanel — Step-by-step directions for a selected route.
 * Timeline UI with vertical connector line between steps.
 */
export default function ItineraryPanel({ route, onClose, onHoverLeg }) {
    if (!route || !route.legs) return null;

    // Merge consecutive legs of the same mode + line into consolidated steps
    const steps = [];
    let currentStep = null;

    route.legs.forEach((leg, legIdx) => {
        const sameLine = currentStep && currentStep.line && leg.line && currentStep.line === leg.line;
        if (currentStep && currentStep.mode === leg.mode && (currentStep.mode === 'walk' || sameLine)) {
            // Extend current step
            currentStep.distance_m += leg.length_m;
            currentStep.duration_mins += (leg.duration_mins || 0);
            currentStep.endNode = leg.to_node;
            currentStep.legCount += 1;
            currentStep.legIndices.push(legIdx);
        } else {
            // New step
            if (currentStep) steps.push(currentStep);
            currentStep = {
                mode: leg.mode,
                distance_m: leg.length_m,
                duration_mins: leg.duration_mins || 0,
                startNode: leg.from_node,
                endNode: leg.to_node,
                line: leg.line || '',
                legCount: 1,
                legIndices: [legIdx],
            };
        }
    });
    if (currentStep) steps.push(currentStep);

    const getInstruction = (step, idx) => {
        const distStr = step.distance_m >= 1000
            ? `${(step.distance_m / 1000).toFixed(1)} km`
            : `${Math.round(step.distance_m)} m`;

        const fromName = step.startNode?.name || `${step.startNode?.lat?.toFixed(4)}, ${step.startNode?.lon?.toFixed(4)}`;
        const toName = step.endNode?.name || `${step.endNode?.lat?.toFixed(4)}, ${step.endNode?.lon?.toFixed(4)}`;

        switch (step.mode) {
            case 'walk':
                if (idx === 0) return `Walk ${distStr} from your starting point`;
                return `Walk ${distStr} to ${toName}`;
            case 'bus': {
                const lineInfo = step.line ? ` (Route ${step.line})` : '';
                return `Board bus${lineInfo} near ${fromName} — ride ${distStr} (${step.legCount} stop${step.legCount !== 1 ? 's' : ''}) — alight near ${toName}`;
            }
            case 'metro': {
                const lineInfo = step.line ? ` ${step.line} Line` : '';
                return `Board${lineInfo} Metro at ${fromName} — ride ${distStr} (${step.legCount} station${step.legCount !== 1 ? 's' : ''}) — exit at ${toName}`;
            }
            default:
                return `Travel ${distStr}`;
        }
    };

    return (
        <div className="itinerary">
            <div className="itinerary__header">
                <h3 className="itinerary__title">Step-by-step directions</h3>
                <button className="itinerary__close" onClick={onClose} aria-label="Close itinerary">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                        <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                    </svg>
                </button>
            </div>

            <div className="itinerary__summary">
                <span className="itinerary__total-time">{route.total_time_mins} min total</span>
                <span className="itinerary__total-transfers">{route.transfers} transfer{route.transfers !== 1 ? 's' : ''}</span>
                {route.total_walk_m > 0 && (
                    <span className="itinerary__total-walk">
                        {route.total_walk_m >= 1000
                            ? `${(route.total_walk_m / 1000).toFixed(1)} km walk`
                            : `${route.total_walk_m} m walk`}
                    </span>
                )}
            </div>

            <div className="itinerary__steps">
                {/* Start marker */}
                <div className="itinerary__step">
                    <div className="itinerary__timeline">
                        <div className="itinerary__dot itinerary__dot--start" />
                        <div className="itinerary__line" style={{ backgroundColor: '#6b7280' }} />
                    </div>
                    <div className="itinerary__content">
                        <span className="itinerary__instruction">Start at your location</span>
                    </div>
                </div>

                {steps.map((step, idx) => {
                    const modeColors = { walk: '#6b7280', bus: '#3b82f6', metro: '#8b5cf6' };
                    const color = modeColors[step.mode] || '#6b7280';
                    const isLast = idx === steps.length - 1;

                    return (
                        <div 
                            key={idx} 
                            className="itinerary__step"
                            onMouseEnter={() => onHoverLeg && onHoverLeg(step.legIndices)}
                            onMouseLeave={() => onHoverLeg && onHoverLeg(null)}
                            style={{ cursor: onHoverLeg ? 'pointer' : 'default' }}
                        >
                            <div className="itinerary__timeline">
                                <div className="itinerary__dot" style={{ backgroundColor: color }} />
                                {!isLast && (
                                    <div className="itinerary__line" style={{ backgroundColor: color }} />
                                )}
                            </div>
                            <div className="itinerary__content">
                                <div className="itinerary__step-header">
                                    <ModeIcon mode={step.mode} size={16} />
                                    <span className="itinerary__mode-label" style={{ color }}>
                                        {step.mode.charAt(0).toUpperCase() + step.mode.slice(1)}
                                    </span>
                                    {step.line && (
                                        <span className="itinerary__line-badge" style={{ backgroundColor: color }}>
                                            {step.line}
                                        </span>
                                    )}
                                    <span className="itinerary__step-time">{step.duration_mins} min</span>
                                </div>
                                <p className="itinerary__instruction">{getInstruction(step, idx)}</p>
                                <span className="itinerary__step-distance">
                                    {step.distance_m >= 1000
                                        ? `${(step.distance_m / 1000).toFixed(1)} km`
                                        : `${Math.round(step.distance_m)} m`}
                                </span>
                            </div>
                        </div>
                    );
                })}

                {/* End marker */}
                <div className="itinerary__step">
                    <div className="itinerary__timeline">
                        <div className="itinerary__dot itinerary__dot--end" />
                    </div>
                    <div className="itinerary__content">
                        <span className="itinerary__instruction">Arrive at your destination</span>
                    </div>
                </div>
            </div>
        </div>
    );
}
