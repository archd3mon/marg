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

export const searchRoutes = async (source, dest, date) => {
    const res = await api.post('/routes/search', {
        source: { lat: source.lat, lng: source.lng },
        destination: { lat: dest.lat, lng: dest.lng },
        departure_time: date.toISOString()
    });
    return res.data;
};
