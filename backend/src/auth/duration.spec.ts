import { durationFromNow, durationToSeconds } from './duration';

describe('durationToSeconds', () => {
  it.each([
    ['15m', 900],
    ['30d', 2_592_000],
    ['2h', 7200],
    ['45s', 45],
    ['3600', 3600],
  ])('parses %s -> %i seconds', (input, expected) => {
    expect(durationToSeconds(input)).toBe(expected);
  });

  it('tolerates surrounding whitespace', () => {
    expect(durationToSeconds('  15m ')).toBe(900);
  });

  it.each(['', 'abc', '15x', '-5m', '1.5h', 'm15'])('rejects %p', (input) => {
    expect(() => durationToSeconds(input)).toThrow(/Invalid duration/);
  });
});

describe('durationFromNow', () => {
  it('returns a date the given duration ahead', () => {
    const before = Date.now();
    const result = durationFromNow('1h').getTime();
    expect(result - before).toBeGreaterThanOrEqual(3_600_000);
    expect(result - before).toBeLessThan(3_601_000);
  });
});
