// src/utils/time.js

/**
 * Returns the current IST time formatted as a datetime-local string (YYYY-MM-DDTHH:mm).
 * Uses Intl.DateTimeFormat for correct timezone handling — no manual offset math.
 */
export function getDefaultDepartureTime() {
  const now = new Date();
  const f = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  const parts = Object.fromEntries(
    f.formatToParts(now).map(p => [p.type, p.value])
  );
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`;
}

/**
 * Format an ISO-8601 departure time string into a readable IST label.
 */
export function formatDepartureTime(isoString) {
  if (!isoString) return "";
  const d = new Date(isoString);
  if (isNaN(d.getTime())) return "";
  return d.toLocaleString("en-IN", {
    weekday: "short",
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: true,
    timeZone: "Asia/Kolkata",
  });
}
