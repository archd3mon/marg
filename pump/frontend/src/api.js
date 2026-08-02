import axios from 'axios';

// In the Capacitor native build, VITE_API_BASE_URL must be the full HTTPS URL
// of the deployed backend (e.g. https://marg-api.onrender.com/api/v1).
// In local web dev it falls back to the Vite proxy path '/api/v1'.
const API_BASE = import.meta.env.VITE_API_BASE_URL || '/api/v1';

const api = axios.create({
    baseURL: API_BASE,
    headers: {
        'Content-Type': 'application/json'
    }
});

export const getHealth = async () => {
    const res = await api.get('/health');
    return res.data;
};

export const getStops = async () => {
    const res = await api.get('/network/stops');
    return res.data;
};

export const searchRoutes = async (source, dest, departureTime, modePreferences = null) => {
    const res = await api.post('/routes/search', {
        source: { lat: source.lat, lng: source.lng },
        destination: { lat: dest.lat, lng: dest.lng },
        departure_time: departureTime || new Date().toISOString(),
        mode_preferences: modePreferences,
    });
    return res.data;
};

export const geocodeSearch = async (query) => {
    const res = await api.get('/geocode/search', {
        params: { q: query },
    });
    return res.data;
};
