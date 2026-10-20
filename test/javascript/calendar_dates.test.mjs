import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const source = await readFile(new URL('../../public/calendar_dates.js', import.meta.url), 'utf8');
const { dateKey, dateFromKey, moveDays, moveMonth, monthDays, allowedDate } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

test('dates round-trip without a browser-timezone shift', () => {
  assert.equal(dateKey(dateFromKey('2026-10-20')), '2026-10-20');
  assert.equal(moveDays('2026-03-29', 1), '2026-03-30');
  assert.equal(moveDays('2026-10-25', 1), '2026-10-26');
});
test('month navigation clamps month-end dates and handles leap years', () => {
  assert.equal(moveMonth('2026-01-31', 1), '2026-02-28');
  assert.equal(moveMonth('2024-01-31', 1), '2024-02-29');
  assert.equal(moveMonth('2026-01-01', -1), '2025-12-01');
});
test('calendar has six complete Monday-first weeks', () => {
  const days = monthDays('2026-10-20');
  assert.equal(days.length, 42);
  assert.equal(dateFromKey(days[0]).getUTCDay(), 1);
  assert.equal(new Set(days).size, 42);
  assert.ok(days.includes('2026-10-01') && days.includes('2026-10-31'));
  assert.equal(days[41], moveDays(days[0], 41));
});
test('today and range endpoints are selectable but future and out-of-range days are not', () => {
  assert.ok(allowedDate('2026-10-20', '2026-10-01', '2026-10-20'));
  assert.ok(allowedDate('2026-10-01', '2026-10-01', '2026-10-20'));
  assert.ok(!allowedDate('2026-10-21', '2026-10-01', '2026-10-20'));
  assert.ok(!allowedDate('2026-09-30', '2026-10-01', '2026-10-20'));
});
