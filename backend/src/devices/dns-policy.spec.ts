import { canToggleAdBlocking, entitledToAdBlocking, resolverFor } from './dns-policy';

const filtered = { dns: '10.8.0.1', dnsUnfiltered: '10.8.0.254' };

// Created just now, so inside the 24h trial and entitled without a subscription.
const entitled = (adBlockEnabled: boolean) => ({
  adBlockEnabled,
  createdAt: new Date(),
  subscribedUntil: null,
});

/// Out of trial and unsubscribed.
const lapsed = (adBlockEnabled: boolean) => ({
  adBlockEnabled,
  createdAt: new Date(Date.now() - 48 * 60 * 60 * 1000),
  subscribedUntil: null,
});
const singleResolver = { dns: '10.9.0.1', dnsUnfiltered: null };

describe('resolverFor', () => {
  it('sends an opted-in user to the filtering resolver', () => {
    expect(resolverFor(entitled(true), filtered)).toBe('10.8.0.1');
  });

  it('sends an opted-out user to the unfiltered one', () => {
    expect(resolverFor(entitled(false), filtered)).toBe('10.8.0.254');
  });

  // The alternative would be handing out a public resolver, which turns "I want
  // fewer restrictions" into "my DNS now leaves the node".
  it('keeps filtering when the node has nowhere else to send them', () => {
    expect(resolverFor(entitled(false), singleResolver)).toBe('10.9.0.1');
  });

  it('never returns an address outside the node', () => {
    for (const enabled of [true, false]) {
      expect([filtered.dns, filtered.dnsUnfiltered]).toContain(
        resolverFor(entitled(enabled), filtered),
      );
    }
  });
});

describe('entitledToAdBlocking', () => {
  it('allows a new account, on its trial', () => {
    expect(entitledToAdBlocking(entitled(true))).toBe(true);
  });

  it('refuses one whose trial ran out with no subscription', () => {
    expect(entitledToAdBlocking(lapsed(true))).toBe(false);
  });

  // The one gate the server can actually hold: it picks the resolver ADDRESS, so
  // a modified client cannot hand itself filtering the way it could flip a local
  // switch. Worth a test of its own.
  it('sends a lapsed account to the unfiltered resolver even with the switch on', () => {
    expect(resolverFor(lapsed(true), filtered)).toBe('10.8.0.254');
  });
});

describe('canToggleAdBlocking', () => {
  it('is true only when the node has two distinct resolvers', () => {
    expect(canToggleAdBlocking(filtered)).toBe(true);
    expect(canToggleAdBlocking(singleResolver)).toBe(false);
    expect(canToggleAdBlocking({ dns: '10.8.0.1', dnsUnfiltered: '10.8.0.1' })).toBe(false);
  });
});
