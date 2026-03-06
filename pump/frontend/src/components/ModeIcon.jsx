/**
 * ModeIcon — SVG transport mode icons with proper colors.
 * No external icon library needed.
 */
export default function ModeIcon({ mode, size = 20, className = '' }) {
    const colors = {
        walk: '#6b7280',
        bus: '#3b82f6',
        metro: '#8b5cf6',
    };

    const color = colors[mode] || colors.walk;

    if (mode === 'metro') {
        return (
            <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
                <rect x="4" y="2" width="16" height="16" rx="3" fill={color} />
                <rect x="7" y="5" width="10" height="5" rx="1" fill="white" />
                <circle cx="8.5" cy="14" r="1.5" fill="white" />
                <circle cx="15.5" cy="14" r="1.5" fill="white" />
                <line x1="7" y1="20" x2="10" y2="18" stroke={color} strokeWidth="2" strokeLinecap="round" />
                <line x1="17" y1="20" x2="14" y2="18" stroke={color} strokeWidth="2" strokeLinecap="round" />
            </svg>
        );
    }

    if (mode === 'bus') {
        return (
            <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
                <rect x="3" y="3" width="18" height="15" rx="3" fill={color} />
                <rect x="5" y="5" width="6" height="5" rx="1" fill="white" />
                <rect x="13" y="5" width="6" height="5" rx="1" fill="white" />
                <circle cx="7" cy="16" r="1.5" fill="white" />
                <circle cx="17" cy="16" r="1.5" fill="white" />
                <rect x="3" y="18" width="3" height="2" rx="0.5" fill={color} />
                <rect x="18" y="18" width="3" height="2" rx="0.5" fill={color} />
            </svg>
        );
    }

    // Walk (default)
    return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
            <circle cx="12" cy="4" r="2.5" fill={color} />
            <path
                d="M10 9h4l2 5h-2l-1-3-1.5 4 3 5h-2l-2.5-4.5L8.5 20H6.5l3-7L8 9z"
                fill={color}
            />
        </svg>
    );
}
