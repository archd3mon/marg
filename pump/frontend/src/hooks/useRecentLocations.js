import { useState, useEffect } from 'react';

const RECENT_LOCATIONS_KEY = 'marg_recent_locations';
const MAX_RECENT = 5;

export default function useRecentLocations() {
    const [recentLocations, setRecentLocations] = useState([]);

    useEffect(() => {
        try {
            const stored = localStorage.getItem(RECENT_LOCATIONS_KEY);
            if (stored) {
                setRecentLocations(JSON.parse(stored));
            }
        } catch (e) {
            console.error('Failed to load recent locations', e);
        }
    }, []);

    const addLocation = (loc) => {
        if (!loc || !loc.name || !loc.lat || !loc.lon) return;
        
        try {
            let current = [...recentLocations];
            // Remove if already exists
            current = current.filter(item => item.name !== loc.name);
            
            // Add to front
            const updated = [loc, ...current].slice(0, MAX_RECENT);
            
            setRecentLocations(updated);
            localStorage.setItem(RECENT_LOCATIONS_KEY, JSON.stringify(updated));
        } catch (e) {
            console.error('Failed to save recent location', e);
        }
    };

    return { recentLocations, addLocation };
}
