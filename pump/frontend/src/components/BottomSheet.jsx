import { useRef, useEffect } from 'react';
import useBottomSheet from '../hooks/useBottomSheet';
import RouteList from './RouteList';
import ItineraryPanel from './ItineraryPanel';

/**
 * BottomSheet — Mobile-only sliding panel from bottom.
 * Contains route results and itinerary.
 */
export default function BottomSheet({
    routes,
    warnings,
    selectedRouteIdx,
    onSelectRoute,
    expandedRoute,
    onExpandRoute,
    onCloseItinerary,
    loading,
    departureTime,
}) {
    const { sheetState, sheetHeight, snapTo, handlers } = useBottomSheet(
        routes.length > 0 ? 'half' : 'collapsed'
    );

    // Auto-expand when routes arrive
    useEffect(() => {
        if (routes.length > 0 && sheetState === 'collapsed') {
            snapTo('half');
        }
    }, [routes.length]);

    // Auto-expand to full when itinerary is opened
    useEffect(() => {
        if (expandedRoute !== null) {
            snapTo('full');
        }
    }, [expandedRoute]);

    return (
        <div
            className="bottom-sheet"
            style={{
                height: `${sheetHeight}px`,
                transition: 'height 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94)',
            }}
        >
            {/* Drag handle */}
            <div className="bottom-sheet__handle-area" {...handlers}>
                <div className="bottom-sheet__handle" />
            </div>

            <div className="bottom-sheet__content">
                {expandedRoute !== null && routes[expandedRoute] ? (
                    <ItineraryPanel
                        route={routes[expandedRoute]}
                        onClose={onCloseItinerary}
                    />
                ) : (
                    <RouteList
                        routes={routes}
                        warnings={warnings}
                        selectedRouteIdx={selectedRouteIdx}
                        onSelectRoute={onSelectRoute}
                        onExpandRoute={onExpandRoute}
                        loading={loading}
                        departureTime={departureTime}
                    />
                )}
            </div>
        </div>
    );
}
