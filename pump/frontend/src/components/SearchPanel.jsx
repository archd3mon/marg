import { useState, useRef, useEffect, useCallback } from 'react';
import { geocodeSearch } from '../api';
import ModeIcon from './ModeIcon';
import useRecentLocations from '../hooks/useRecentLocations';

/**
 * SearchPanel — Origin/destination inputs with autocomplete + mode toggles.
 * Renders as a compact bar on mobile, full form in sidebar on desktop.
 */
export default function SearchPanel({
    source,
    dest,
    sourceName,
    destName,
    onSelectSource,
    onSelectDest,
    selectingSource,
    setSelectingSource,
    onSearch,
    loading,
    onSwap,
    isMobile,
    modePreferences,
    onModePreferenceChange,
}) {
    const [sourceQuery, setSourceQuery] = useState('');
    const [destQuery, setDestQuery] = useState('');
    const [sourceSuggestions, setSourceSuggestions] = useState([]);
    const [destSuggestions, setDestSuggestions] = useState([]);
    const [showSourceDropdown, setShowSourceDropdown] = useState(false);
    const [showDestDropdown, setShowDestDropdown] = useState(false);
    const [activeIndex, setActiveIndex] = useState(-1);
    const [activeField, setActiveField] = useState(null); // 'source' or 'dest'
    const sourceRef = useRef(null);
    const destRef = useRef(null);
    const debounceRef = useRef(null);
    const { recentLocations, addLocation } = useRecentLocations();

    // Sync display text with selected place names
    useEffect(() => {
        if (sourceName && !showSourceDropdown) setSourceQuery(sourceName);
    }, [sourceName]);
    useEffect(() => {
        if (destName && !showDestDropdown) setDestQuery(destName);
    }, [destName]);

    // Sync when source/dest set by map click
    useEffect(() => {
        if (source && !sourceName) {
            setSourceQuery(`${source.lat.toFixed(4)}, ${source.lng.toFixed(4)}`);
        }
    }, [source]);
    useEffect(() => {
        if (dest && !destName) {
            setDestQuery(`${dest.lat.toFixed(4)}, ${dest.lng.toFixed(4)}`);
        }
    }, [dest]);

    const debouncedSearch = useCallback((query, field) => {
        clearTimeout(debounceRef.current);
        if (query.length < 2) {
            if (field === 'source') setSourceSuggestions([]);
            else setDestSuggestions([]);
            return;
        }
        debounceRef.current = setTimeout(async () => {
            try {
                const data = await geocodeSearch(query);
                if (field === 'source') {
                    setSourceSuggestions(data.results || []);
                    setShowSourceDropdown(true);
                } else {
                    setDestSuggestions(data.results || []);
                    setShowDestDropdown(true);
                }
                setActiveIndex(-1);
            } catch (err) {
                console.error('Geocode error:', err);
            }
        }, 250);
    }, []);

    const handleSourceChange = (e) => {
        const val = e.target.value;
        setSourceQuery(val);
        setActiveField('source');
        debouncedSearch(val, 'source');
    };

    const handleDestChange = (e) => {
        const val = e.target.value;
        setDestQuery(val);
        setActiveField('dest');
        debouncedSearch(val, 'dest');
    };

    const selectSuggestion = (suggestion, field) => {
        const point = { lat: suggestion.lat, lng: suggestion.lon };
        const name = suggestion.name;
        
        addLocation({ name, lat: suggestion.lat, lon: suggestion.lon, display_name: suggestion.display_name });

        if (field === 'source') {
            setSourceQuery(name);
            setShowSourceDropdown(false);
            setSourceSuggestions([]);
            onSelectSource(point, name);
        } else {
            setDestQuery(name);
            setShowDestDropdown(false);
            setDestSuggestions([]);
            onSelectDest(point, name);
        }
    };

    const handleKeyDown = (e, field) => {
        const suggestions = field === 'source' ? sourceSuggestions : destSuggestions;
        if (!suggestions.length) return;

        if (e.key === 'ArrowDown') {
            e.preventDefault();
            setActiveIndex((prev) => Math.min(prev + 1, suggestions.length - 1));
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            setActiveIndex((prev) => Math.max(prev - 1, 0));
        } else if (e.key === 'Enter' && activeIndex >= 0) {
            e.preventDefault();
            selectSuggestion(suggestions[activeIndex], field);
        } else if (e.key === 'Escape') {
            setShowSourceDropdown(false);
            setShowDestDropdown(false);
        }
    };

    // Close dropdowns when clicking outside
    useEffect(() => {
        const handleClick = (e) => {
            if (sourceRef.current && !sourceRef.current.contains(e.target)) {
                setShowSourceDropdown(false);
            }
            if (destRef.current && !destRef.current.contains(e.target)) {
                setShowDestDropdown(false);
            }
        };
        document.addEventListener('mousedown', handleClick);
        return () => document.removeEventListener('mousedown', handleClick);
    }, []);

    const handleSwapClick = () => {
        const tmpQuery = sourceQuery;
        setSourceQuery(destQuery);
        setDestQuery(tmpQuery);
        onSwap();
    };

    const modeToggles = [
        { key: 'prefer_metro', label: 'Metro', mode: 'metro' },
        { key: 'prefer_bus', label: 'Bus', mode: 'bus' },
        { key: 'avoid_walking', label: 'Less Walking', mode: 'walk' },
    ];

    return (
        <div className={`search-panel ${isMobile ? 'search-panel--mobile' : 'search-panel--desktop'}`}>
            {!isMobile && (
                <div className="search-panel__header">
                    <h1 className="search-panel__title">Marg</h1>
                    <p className="search-panel__subtitle">Pune Transit Planner</p>
                </div>
            )}

            <div className="search-panel__inputs">
                <div className="search-panel__input-row" ref={sourceRef}>
                    <div className="search-panel__dot search-panel__dot--source" />
                    <div className="search-panel__input-wrapper">
                        <input
                            className={`search-panel__input ${selectingSource ? 'search-panel__input--active' : ''}`}
                            type="text"
                            placeholder="Search origin (e.g. FC Road)"
                            value={sourceQuery}
                            onChange={handleSourceChange}
                            onFocus={() => { setSelectingSource(true); setActiveField('source'); setShowSourceDropdown(true); }}
                            onKeyDown={(e) => handleKeyDown(e, 'source')}
                            autoComplete="off"
                            id="source-input"
                        />
                        {showSourceDropdown && (sourceSuggestions.length > 0 || (sourceQuery.length < 2 && recentLocations.length > 0)) && (
                            <div className="autocomplete-dropdown" id="source-dropdown">
                                {sourceQuery.length < 2 && recentLocations.length > 0 ? (
                                    <>
                                        <div className="autocomplete-dropdown__header" style={{padding: '8px 16px', fontSize: '0.75rem', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600}}>Recent</div>
                                        {recentLocations.map((s, i) => (
                                            <div
                                                key={`recent-src-${i}`}
                                                className="autocomplete-item"
                                                onClick={() => selectSuggestion(s, 'source')}
                                            >
                                                <svg className="autocomplete-item__icon" width="16" height="16" viewBox="0 0 24 24" fill="none">
                                                    <circle cx="12" cy="12" r="10" stroke="#94a3b8" strokeWidth="2" strokeDasharray="4 4"/>
                                                </svg>
                                                <div className="autocomplete-item__text">
                                                    <span className="autocomplete-item__name">{s.name}</span>
                                                    <span className="autocomplete-item__detail">{s.display_name || 'Recent Location'}</span>
                                                </div>
                                            </div>
                                        ))}
                                    </>
                                ) : (
                                    sourceSuggestions.map((s, i) => (
                                        <div
                                            key={i}
                                            className={`autocomplete-item ${i === activeIndex && activeField === 'source' ? 'autocomplete-item--active' : ''}`}
                                            onClick={() => selectSuggestion(s, 'source')}
                                            onMouseEnter={() => setActiveIndex(i)}
                                        >
                                            <span className="suggestion-source">
                                                {s.source === 'local' ? '📍' : s.source === 'fuzzy' ? '~' : '🌐'}
                                            </span>
                                            <div className="autocomplete-item__text">
                                                <span className="autocomplete-item__name">{s.name}</span>
                                                <span className="autocomplete-item__detail">{s.display_name}</span>
                                            </div>
                                        </div>
                                    ))
                                )}
                            </div>
                        )}
                    </div>
                </div>

                <button className="search-panel__swap" onClick={handleSwapClick} title="Swap origin and destination">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                        <path d="M7 16V4m0 12l-3-3m3 3l3-3M17 8v12m0-12l3 3m-3-3l-3 3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                    </svg>
                </button>

                <div className="search-panel__input-row" ref={destRef}>
                    <div className="search-panel__dot search-panel__dot--dest" />
                    <div className="search-panel__input-wrapper">
                        <input
                            className={`search-panel__input ${!selectingSource ? 'search-panel__input--active' : ''}`}
                            type="text"
                            placeholder="Search destination (e.g. Pune Airport)"
                            value={destQuery}
                            onChange={handleDestChange}
                            onFocus={() => { setSelectingSource(false); setActiveField('dest'); setShowDestDropdown(true); }}
                            onKeyDown={(e) => handleKeyDown(e, 'dest')}
                            autoComplete="off"
                            id="dest-input"
                        />
                        {showDestDropdown && (destSuggestions.length > 0 || (destQuery.length < 2 && recentLocations.length > 0)) && (
                            <div className="autocomplete-dropdown" id="dest-dropdown">
                                {destQuery.length < 2 && recentLocations.length > 0 ? (
                                    <>
                                        <div className="autocomplete-dropdown__header" style={{padding: '8px 16px', fontSize: '0.75rem', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600}}>Recent</div>
                                        {recentLocations.map((s, i) => (
                                            <div
                                                key={`recent-dst-${i}`}
                                                className="autocomplete-item"
                                                onClick={() => selectSuggestion(s, 'dest')}
                                            >
                                                <svg className="autocomplete-item__icon" width="16" height="16" viewBox="0 0 24 24" fill="none">
                                                    <circle cx="12" cy="12" r="10" stroke="#94a3b8" strokeWidth="2" strokeDasharray="4 4"/>
                                                </svg>
                                                <div className="autocomplete-item__text">
                                                    <span className="autocomplete-item__name">{s.name}</span>
                                                    <span className="autocomplete-item__detail">{s.display_name || 'Recent Location'}</span>
                                                </div>
                                            </div>
                                        ))}
                                    </>
                                ) : (
                                    destSuggestions.map((s, i) => (
                                        <div
                                            key={i}
                                            className={`autocomplete-item ${i === activeIndex && activeField === 'dest' ? 'autocomplete-item--active' : ''}`}
                                            onClick={() => selectSuggestion(s, 'dest')}
                                            onMouseEnter={() => setActiveIndex(i)}
                                        >
                                            <span className="suggestion-source">
                                                {s.source === 'local' ? '📍' : s.source === 'fuzzy' ? '~' : '🌐'}
                                            </span>
                                            <div className="autocomplete-item__text">
                                                <span className="autocomplete-item__name">{s.name}</span>
                                                <span className="autocomplete-item__detail">{s.display_name}</span>
                                            </div>
                                        </div>
                                    ))
                                )}
                            </div>
                        )}
                    </div>
                </div>
            </div>

            {/* Mode Preference Toggles */}
            <div className="mode-toggles">
                {modeToggles.map((t) => (
                    <button
                        key={t.key}
                        className={`mode-toggle ${modePreferences[t.key] ? 'mode-toggle--active' : ''}`}
                        onClick={() => onModePreferenceChange(t.key)}
                        title={t.label}
                    >
                        <ModeIcon mode={t.mode} size={16} />
                        <span>{t.label}</span>
                    </button>
                ))}
            </div>

            <button
                className="search-panel__btn"
                onClick={onSearch}
                disabled={!source || !dest || loading}
                id="find-routes-btn"
            >
                {loading ? (
                    <span className="search-panel__loading">
                        <span className="search-panel__spinner" />
                        Finding routes…
                    </span>
                ) : (
                    'Find Routes'
                )}
            </button>
        </div>
    );
}
