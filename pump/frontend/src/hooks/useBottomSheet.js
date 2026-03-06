import { useState, useRef, useCallback } from 'react';

/**
 * useBottomSheet — Touch gesture logic for mobile bottom sheet.
 *
 * States:
 *   'collapsed'  — only handle + peek visible (~80px)
 *   'half'       — shows route cards (~50% viewport)
 *   'full'       — fully expanded, shows itinerary (~90% viewport)
 */

const SNAP_POINTS = {
    collapsed: 80,
    half: null,   // computed as 50% of window height
    full: null,   // computed as 90% of window height
};

const VELOCITY_THRESHOLD = 0.3; // px/ms — flick detection

export default function useBottomSheet(initialState = 'collapsed') {
    const [sheetState, setSheetState] = useState(initialState);
    const [sheetHeight, setSheetHeight] = useState(SNAP_POINTS.collapsed);
    const sheetRef = useRef(null);
    const touchStartY = useRef(0);
    const touchStartHeight = useRef(0);
    const touchStartTime = useRef(0);

    const getSnapHeight = useCallback((state) => {
        const vh = window.innerHeight;
        switch (state) {
            case 'collapsed': return 80;
            case 'half': return Math.round(vh * 0.5);
            case 'full': return Math.round(vh * 0.9);
            default: return 80;
        }
    }, []);

    const snapTo = useCallback((state) => {
        setSheetState(state);
        setSheetHeight(getSnapHeight(state));
    }, [getSnapHeight]);

    const onTouchStart = useCallback((e) => {
        touchStartY.current = e.touches[0].clientY;
        touchStartHeight.current = sheetHeight;
        touchStartTime.current = Date.now();
    }, [sheetHeight]);

    const onTouchMove = useCallback((e) => {
        const dy = touchStartY.current - e.touches[0].clientY;
        const newHeight = Math.max(80, Math.min(window.innerHeight * 0.95, touchStartHeight.current + dy));
        setSheetHeight(newHeight);
    }, []);

    const onTouchEnd = useCallback((e) => {
        const endY = e.changedTouches[0].clientY;
        const dy = touchStartY.current - endY;
        const dt = Date.now() - touchStartTime.current;
        const velocity = Math.abs(dy) / Math.max(dt, 1);

        const vh = window.innerHeight;
        const snapPoints = [
            { state: 'collapsed', height: 80 },
            { state: 'half', height: vh * 0.5 },
            { state: 'full', height: vh * 0.9 },
        ];

        // Flick detection
        if (velocity > VELOCITY_THRESHOLD) {
            if (dy > 0) {
                // Swiped up — expand to next state
                if (sheetState === 'collapsed') { snapTo('half'); return; }
                if (sheetState === 'half') { snapTo('full'); return; }
            } else {
                // Swiped down — collapse to previous state
                if (sheetState === 'full') { snapTo('half'); return; }
                if (sheetState === 'half') { snapTo('collapsed'); return; }
            }
        }

        // Snap to closest point
        let closest = snapPoints[0];
        let minDist = Infinity;
        for (const sp of snapPoints) {
            const dist = Math.abs(sheetHeight - sp.height);
            if (dist < minDist) {
                minDist = dist;
                closest = sp;
            }
        }
        snapTo(closest.state);
    }, [sheetState, sheetHeight, snapTo]);

    return {
        sheetRef,
        sheetState,
        sheetHeight,
        snapTo,
        handlers: {
            onTouchStart,
            onTouchMove,
            onTouchEnd,
        },
    };
}
