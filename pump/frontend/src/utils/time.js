// src/utils/time.js
export function getDefaultDepartureTime() {
  const now = new Date();
  const offset = 5.5 * 60 * 60 * 1000;
  const ist = new Date(now.getTime() + now.getTimezoneOffset() * 60 * 1000 + offset);
  return ist.toISOString().slice(0, 16);
}

export function formatDepartureTime(isoString) {
  if (!isoString) return "";
  const d = new Date(isoString);
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
