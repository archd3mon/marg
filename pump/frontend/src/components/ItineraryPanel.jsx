import ModeIcon from './ModeIcon';

/**
 * ItineraryPanel — Step-by-step directions for a selected route.
 * Timeline UI with vertical connector line between steps.
 */
export default function ItineraryPanel({ route, onClose }) {
    if (!route || !route.legs) return null;

    // Merge consecutive legs of the same mode into consolidated steps
    const steps = [];
    let currentStep = null;

    for (const leg of route.legs) {
        if (currentStep && currentStep.mode === leg.mode) {
            // Extend current step
            currentStep.distance_m += leg.length_m;
            currentStep.duration_mins += (leg.duration_mins || 0);
            currentStep.endNode = leg.to_node;
            currentStep.legCount += 1;
        } else {
            // New step
            if (currentStep) steps.push(currentStep);
            currentStep = {
                mode: leg.mode,
                distance_m: leg.length_m,
                duration_mins: leg.duration_mins || 0,
                startNode: leg.from_node,
                endNode: leg.to_node,
                legCount: 1,
            };
        }
    }
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
            case 'bus':
                return `Board bus near ${fromName} — ride ${distStr} (${step.legCount} stop${step.legCount !== 1 ? 's' : ''})`;
            case 'metro':
                return `Board Metro at ${fromName} — ride ${distStr} (${step.legCount} station${step.legCount !== 1 ? 's' : ''})`;
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
                        <div key={idx} className="itinerary__step">
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
