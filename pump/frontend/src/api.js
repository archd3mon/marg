import axios from 'axios';

const api = axios.create({
    baseURL: '/api/v1',
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
