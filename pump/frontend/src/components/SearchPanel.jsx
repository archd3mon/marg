import ModeIcon from './ModeIcon';

/**
 * SearchPanel — Origin/destination inputs + search button.
 * Renders as a compact bar on mobile, full form in sidebar on desktop.
 */
export default function SearchPanel({
    source,
    dest,
    selectingSource,
    setSelectingSource,
    onSearch,
    loading,
    onSwap,
    isMobile,
}) {
    return (
        <div className={`search-panel ${isMobile ? 'search-panel--mobile' : 'search-panel--desktop'}`}>
            {!isMobile && (
                <div className="search-panel__header">
                    <h1 className="search-panel__title">Marg</h1>
                    <p className="search-panel__subtitle">Pune Transit Planner</p>
                </div>
            )}

            <div className="search-panel__inputs">
                <div className="search-panel__input-row">
                    <div className="search-panel__dot search-panel__dot--source" />
                    <button
                        className={`search-panel__input ${selectingSource ? 'search-panel__input--active' : ''}`}
                        onClick={() => setSelectingSource(true)}
                    >
                        {source
                            ? `${source.lat.toFixed(4)}, ${source.lng.toFixed(4)}`
                            : 'Tap map for origin'}
                    </button>
                </div>

                <button className="search-panel__swap" onClick={onSwap} title="Swap origin and destination">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                        <path d="M7 16V4m0 12l-3-3m3 3l3-3M17 8v12m0-12l3 3m-3-3l-3 3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                    </svg>
                </button>

                <div className="search-panel__input-row">
                    <div className="search-panel__dot search-panel__dot--dest" />
                    <button
                        className={`search-panel__input ${!selectingSource ? 'search-panel__input--active' : ''}`}
                        onClick={() => setSelectingSource(false)}
                    >
                        {dest
                            ? `${dest.lat.toFixed(4)}, ${dest.lng.toFixed(4)}`
                            : 'Tap map for destination'}
                    </button>
                </div>
            </div>

            <button
                className="search-panel__btn"
                onClick={onSearch}
                disabled={!source || !dest || loading}
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
