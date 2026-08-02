import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  // Confirmed with user: app name = "Marg", package ID = "com.archd3mon.marg"
  appId: 'com.archd3mon.marg',
  appName: 'Marg',

  // The webDir must match Vite's output directory (default: dist).
  webDir: 'dist',

  server: {
    // androidScheme: 'https' makes the WebView load content via https://
    // rather than the default file:// or capacitor:// schemes.
    // This is important for:
    //   1. Service workers (if added later)
    //   2. Consistent cookie / storage behavior
    //   3. CORS — the request origin becomes https://localhost
    //      (update ALLOWED_ORIGINS in backend if you change this)
    androidScheme: 'https',

    // allowNavigation: restrict which external URLs the WebView can load.
    // CARTO tile CDN and OSM Nominatim are the only external hosts Marg uses.
    allowNavigation: [
      '*.basemaps.cartocdn.com',
      'nominatim.openstreetmap.org',
      'fonts.googleapis.com',
      'fonts.gstatic.com',
    ],
  },

  android: {
    // minSdkVersion confirmed by user: API 31 (Android 12).
    // This enables native CSS backdrop-filter blur in the WebView without fallback.
    minSdkVersion: 31,

    // backgroundColor behind the WebView while the app loads.
    // Using white (#FFFFFF) — matches the map background to avoid flash-of-color.
    backgroundColor: '#FFFFFF',
  },

  plugins: {
    // No plugins configured yet. @capacitor/preferences will be added in Phase 3.
  },
};

export default config;
