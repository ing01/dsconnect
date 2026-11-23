import { formatWait, waitSeconds } from '../waitTime';

describe('formatWait', () => {
  it('shows less than a minute', () => {
    expect(formatWait(0)).toBe('menos de 1 min');
    expect(formatWait(59)).toBe('menos de 1 min');
  });

  it('shows minutes', () => {
    expect(formatWait(60)).toBe('1 min');
    expect(formatWait(7 * 60 + 30)).toBe('7 min');
    expect(formatWait(59 * 60)).toBe('59 min');
  });

  it('shows hours with padded minutes', () => {
    expect(formatWait(3600)).toBe('1 h 00 min');
    expect(formatWait(3600 + 5 * 60)).toBe('1 h 05 min');
    expect(formatWait(23 * 3600 + 59 * 60)).toBe('23 h 59 min');
  });

  it('shows days and hours', () => {
    expect(formatWait(26 * 3600)).toBe('1 d 2 h');
  });

  it('returns nothing for a missing value', () => {
    expect(formatWait(null)).toBe('');
    expect(formatWait(undefined)).toBe('');
    expect(formatWait(NaN)).toBe('');
  });
});

describe('waitSeconds', () => {
  const now = Date.parse('2026-11-23T12:00:00Z');

  it('is null when the agent already replied', () => {
    expect(waitSeconds(null, now)).toBeNull();
  });

  it('counts from waiting_since', () => {
    expect(waitSeconds('2026-11-23T11:50:00Z', now)).toBe(600);
  });

  it('never goes negative with a skewed clock', () => {
    expect(waitSeconds('2026-11-23T12:00:05Z', now)).toBe(0);
  });
});
