import {
  AD_BLOCK_GRANT_MS,
  AD_BLOCK_MAX_BANKED_MS,
  adBlockRemainingMs,
  canToggleAdBlocking,
  entitledToAdBlocking,
  extendAdBlockGrant,
  resolverFor,
} from './dns-policy';

const NOW = new Date('2026-09-16T12:00:00.000Z');
const filtered = { dns: '10.8.0.1', dnsUnfiltered: '10.8.0.254' };
const singleResolver = { dns: '10.9.0.1', dnsUnfiltered: null };

const granted = (msLeft: number) => ({
  adBlockEnabled: true,
  adBlockUntil: new Date(NOW.getTime() + msLeft),
});

describe('entitledToAdBlocking', () => {
  it('is false with no grant at all', () => {
    expect(entitledToAdBlocking({ adBlockEnabled: true, adBlockUntil: null }, NOW)).toBe(false);
  });

  it('is true while a grant has time left', () => {
    expect(entitledToAdBlocking(granted(60_000), NOW)).toBe(true);
  });

  it('is false once it has run out', () => {
    expect(entitledToAdBlocking(granted(-1), NOW)).toBe(false);
  });

  // Exactly-at-expiry must not still count, or a grant is perpetually one tick
  // from ending and never ends.
  it('is false exactly at the boundary', () => {
    expect(entitledToAdBlocking(granted(0), NOW)).toBe(false);
  });
});

describe('extendAdBlockGrant', () => {
  it('gives a full window to someone with no grant', () => {
    const until = extendAdBlockGrant({ adBlockEnabled: true, adBlockUntil: null }, NOW);
    expect(until.getTime() - NOW.getTime()).toBe(AD_BLOCK_GRANT_MS);
  });

  // Watching a second ad early must add to what is left, not replace it —
  // otherwise being keen costs you time.
  it('stacks on top of time still remaining', () => {
    const until = extendAdBlockGrant(granted(2 * 60_000), NOW);
    expect(until.getTime() - NOW.getTime()).toBe(2 * 60_000 + AD_BLOCK_GRANT_MS);
  });

  it('does not extend from an expiry already in the past', () => {
    const until = extendAdBlockGrant(granted(-10 * 60_000), NOW);
    expect(until.getTime() - NOW.getTime()).toBe(AD_BLOCK_GRANT_MS);
  });

  // Nothing yet proves an ad was watched, so a caller in a loop must hit a wall.
  it('caps how much can be banked', () => {
    let subject = { adBlockEnabled: true, adBlockUntil: null as Date | null };
    for (let i = 0; i < 100; i++) {
      subject = { ...subject, adBlockUntil: extendAdBlockGrant(subject, NOW) };
    }
    expect(subject.adBlockUntil!.getTime() - NOW.getTime()).toBe(AD_BLOCK_MAX_BANKED_MS);
  });
});

describe('adBlockRemainingMs', () => {
  it('is zero without a grant, and never negative', () => {
    expect(adBlockRemainingMs({ adBlockEnabled: true, adBlockUntil: null }, NOW)).toBe(0);
    expect(adBlockRemainingMs(granted(-5_000), NOW)).toBe(0);
  });

  it('counts down the time left', () => {
    expect(adBlockRemainingMs(granted(90_000), NOW)).toBe(90_000);
  });
});

describe('resolverFor', () => {
  it('filters only when the switch is on AND the grant is live', () => {
    expect(resolverFor(granted(60_000), filtered, NOW)).toBe('10.8.0.1');
    expect(resolverFor({ ...granted(60_000), adBlockEnabled: false }, filtered, NOW))
      .toBe('10.8.0.254');
    expect(resolverFor({ adBlockEnabled: true, adBlockUntil: null }, filtered, NOW))
      .toBe('10.8.0.254');
  });

  // The alternative would be handing out a public resolver, which turns "your ad
  // time ran out" into "your DNS now leaves the node".
  it('keeps filtering when the node has nowhere else to send them', () => {
    expect(resolverFor({ adBlockEnabled: true, adBlockUntil: null }, singleResolver, NOW))
      .toBe('10.9.0.1');
  });

  it('never returns an address outside the node', () => {
    for (const subject of [granted(60_000), { adBlockEnabled: true, adBlockUntil: null }]) {
      expect([filtered.dns, filtered.dnsUnfiltered]).toContain(
        resolverFor(subject, filtered, NOW),
      );
    }
  });
});

describe('canToggleAdBlocking', () => {
  it('is true only when the node has two distinct resolvers', () => {
    expect(canToggleAdBlocking(filtered)).toBe(true);
    expect(canToggleAdBlocking(singleResolver)).toBe(false);
    expect(canToggleAdBlocking({ dns: '10.8.0.1', dnsUnfiltered: '10.8.0.1' })).toBe(false);
  });
});
