import {
  SUBSCRIPTION_DURATION_MS,
  TRIAL_DURATION_MS,
  accessRemainingMs,
  extendSubscription,
  isEntitled,
  isInTrial,
  isSubscribed,
  trialEndsAt,
} from './entitlement';

const CREATED = new Date('2026-09-18T12:00:00.000Z');
const hoursAfter = (h: number) => new Date(CREATED.getTime() + h * 60 * 60 * 1000);

const fresh = { createdAt: CREATED, subscribedUntil: null };

describe('the 24h trial', () => {
  it('covers the first day', () => {
    expect(isInTrial(fresh, hoursAfter(0))).toBe(true);
    expect(isInTrial(fresh, hoursAfter(23.9))).toBe(true);
  });

  it('is over at exactly 24h, not a tick later', () => {
    expect(isInTrial(fresh, hoursAfter(24))).toBe(false);
    expect(isInTrial(fresh, hoursAfter(25))).toBe(false);
  });

  // Anchored to createdAt, not to first use: an account that sits unopened has
  // still had its trial, and a client-reported start is a client-controlled one.
  it('runs from account creation', () => {
    expect(trialEndsAt(fresh).getTime() - CREATED.getTime()).toBe(TRIAL_DURATION_MS);
  });
});

describe('entitlement', () => {
  it('is granted by the trial, then withdrawn', () => {
    expect(isEntitled(fresh, hoursAfter(1))).toBe(true);
    expect(isEntitled(fresh, hoursAfter(30))).toBe(false);
  });

  it('is granted by a subscription after the trial lapses', () => {
    const subscriber = { createdAt: CREATED, subscribedUntil: hoursAfter(100) };
    expect(isEntitled(subscriber, hoursAfter(30))).toBe(true);
    expect(isSubscribed(subscriber, hoursAfter(30))).toBe(true);
    expect(isInTrial(subscriber, hoursAfter(30))).toBe(false);
  });

  it('lapses when the subscription expires', () => {
    const lapsed = { createdAt: CREATED, subscribedUntil: hoursAfter(50) };
    expect(isEntitled(lapsed, hoursAfter(60))).toBe(false);
  });
});

describe('accessRemainingMs', () => {
  it('counts the trial down and floors at zero', () => {
    expect(accessRemainingMs(fresh, hoursAfter(23))).toBe(60 * 60 * 1000);
    expect(accessRemainingMs(fresh, hoursAfter(99))).toBe(0);
  });

  // Whichever lasts longer wins, so paying early inside the trial never shows a
  // number that goes DOWN.
  it('reports the later of trial and subscription', () => {
    const early = { createdAt: CREATED, subscribedUntil: hoursAfter(200) };
    expect(accessRemainingMs(early, hoursAfter(1))).toBe(199 * 60 * 60 * 1000);
  });
});

describe('extendSubscription', () => {
  it('gives a full period to someone with none', () => {
    const until = extendSubscription(fresh, hoursAfter(30));
    expect(until.getTime() - hoursAfter(30).getTime()).toBe(SUBSCRIPTION_DURATION_MS);
  });

  // Renewing early must add to what is left rather than throw it away.
  it('stacks on time still remaining', () => {
    const active = { createdAt: CREATED, subscribedUntil: hoursAfter(100) };
    const until = extendSubscription(active, hoursAfter(30));
    expect(until.getTime()).toBe(hoursAfter(100).getTime() + SUBSCRIPTION_DURATION_MS);
  });
});
