import { canToggleAdBlocking, entitledToAdBlocking, resolverFor } from './dns-policy';

const filtered = { dns: '10.8.0.1', dnsUnfiltered: '10.8.0.254' };
const singleResolver = { dns: '10.9.0.1', dnsUnfiltered: null };

describe('resolverFor', () => {
  it('sends an opted-in user to the filtering resolver', () => {
    expect(resolverFor({ adBlockEnabled: true }, filtered)).toBe('10.8.0.1');
  });

  it('sends an opted-out user to the unfiltered one', () => {
    expect(resolverFor({ adBlockEnabled: false }, filtered)).toBe('10.8.0.254');
  });

  // The alternative would be handing out a public resolver, which turns "I want ads"
  // into "my DNS now leaves the node". Keeping the filter on is the lesser surprise.
  it('keeps filtering when the node has nowhere else to send them', () => {
    expect(resolverFor({ adBlockEnabled: false }, singleResolver)).toBe('10.9.0.1');
  });

  it('never returns an address outside the node', () => {
    for (const enabled of [true, false]) {
      const chosen = resolverFor({ adBlockEnabled: enabled }, filtered);
      expect([filtered.dns, filtered.dnsUnfiltered]).toContain(chosen);
    }
  });
});

describe('entitledToAdBlocking', () => {
  // Pins today's behaviour so the paid-plan change is a deliberate edit to this test
  // and not something that quietly slips in with a billing refactor.
  it('allows every account while there are no plans', () => {
    expect(entitledToAdBlocking({ adBlockEnabled: true })).toBe(true);
    expect(entitledToAdBlocking({ adBlockEnabled: false })).toBe(true);
  });
});

describe('canToggleAdBlocking', () => {
  it('is true only when the node has two distinct resolvers', () => {
    expect(canToggleAdBlocking(filtered)).toBe(true);
    expect(canToggleAdBlocking(singleResolver)).toBe(false);
    expect(canToggleAdBlocking({ dns: '10.8.0.1', dnsUnfiltered: '10.8.0.1' })).toBe(false);
  });
});
