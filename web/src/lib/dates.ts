/**
 * Helpers for Postgres `date` columns (e.g. due_date, next_due_date,
 * install_date), which come back as plain "YYYY-MM-DD" strings with no
 * timezone. `new Date("YYYY-MM-DD")` parses that as UTC midnight, so
 * `.toLocaleDateString()` shows the previous day for any timezone west of
 * UTC. These helpers treat the string as a local calendar date instead.
 */

/** Formats a "YYYY-MM-DD" date-only string using the local calendar date. */
export function formatDateOnly(
  dateStr: string | null | undefined,
  options: Intl.DateTimeFormatOptions = {}
): string {
  if (!dateStr) return "—";
  const [year, month, day] = dateStr.split("-").map(Number);
  return new Date(year, month - 1, day).toLocaleDateString("en-US", options);
}

/** Returns today's date as "YYYY-MM-DD" in the local timezone. */
export function localDateString(date: Date = new Date()): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}
