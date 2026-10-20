// UTC arithmetic avoids daylight-saving drift; "today" comes from Rails.
export function dateFromKey(key: string): Date {
  const [year, month, day] = key.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day));
}
export function dateKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}
export function moveDays(key: string, days: number): string {
  const date = dateFromKey(key);
  date.setUTCDate(date.getUTCDate() + days);
  return dateKey(date);
}
export function moveMonth(key: string, months: number): string {
  const date = dateFromKey(key);
  const day = date.getUTCDate();
  date.setUTCDate(1);
  date.setUTCMonth(date.getUTCMonth() + months);
  const lastDay = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate();
  date.setUTCDate(Math.min(day, lastDay));
  return dateKey(date);
}
export function monthDays(key: string): string[] {
  const date = dateFromKey(key);
  date.setUTCDate(1);
  // Monday-first grid, with surrounding days to keep six consistent rows.
  const start = moveDays(dateKey(date), -((date.getUTCDay() + 6) % 7));
  return Array.from({ length: 42 }, (_, index) => moveDays(start, index));
}
export function allowedDate(key: string, min: string, max: string): boolean {
  return key >= min && key <= max;
}
