import type { User } from '@prisma/client';

/**
 * How long a new account gets everything for free.
 *
 * From `createdAt`, not from first use: an account that sits unopened for a week
 * has still had its trial, and anchoring to a "first launch" the server never
 * sees would mean trusting the client to say when its own trial started.
 */
export const TRIAL_DURATION_MS = 24 * 60 * 60 * 1000;

/**
 * What each plan buys.
 *
 * The checkout is a dummy, but the plan still has to mean something: a paywall
 * that offers a year and writes a month is worse than one that offers nothing,
 * because the disagreement only surfaces in the database.
 */
export const PLANS = ['monthly', 'yearly'] as const;
export type SubscriptionPlan = (typeof PLANS)[number];

const DAY_MS = 24 * 60 * 60 * 1000;

export const PLAN_DURATION_MS: Record<SubscriptionPlan, number> = {
  monthly: 30 * DAY_MS,
  yearly: 365 * DAY_MS,
};

/** The parts of a user entitlement depends on. */
export type EntitlementSubject = Pick<User, 'createdAt' | 'subscribedUntil'>;

/** When this account's free trial runs out. Always in the past eventually. */
export function trialEndsAt(user: EntitlementSubject): Date {
  return new Date(user.createdAt.getTime() + TRIAL_DURATION_MS);
}

export function isInTrial(user: EntitlementSubject, now: Date = new Date()): boolean {
  return now.getTime() < trialEndsAt(user).getTime();
}

export function isSubscribed(user: EntitlementSubject, now: Date = new Date()): boolean {
  return user.subscribedUntil !== null && now.getTime() < user.subscribedUntil.getTime();
}

/**
 * Whether the account may use the paid features right now.
 *
 * Trial OR subscription, in that order of generosity: a subscriber inside their
 * first day is entitled twice over, which costs nothing and avoids a cliff for
 * anyone who pays early.
 */
export function isEntitled(user: EntitlementSubject, now: Date = new Date()): boolean {
  return isInTrial(user, now) || isSubscribed(user, now);
}

/** Milliseconds of access left, from whichever source lasts longer. Zero when out. */
export function accessRemainingMs(
  user: EntitlementSubject,
  now: Date = new Date(),
): number {
  const ends = Math.max(
    trialEndsAt(user).getTime(),
    user.subscribedUntil?.getTime() ?? 0,
  );
  return Math.max(0, ends - now.getTime());
}

/**
 * The new expiry after a checkout of [plan].
 *
 * Extends from whichever is later — now, or an existing subscription — so
 * renewing early adds time rather than discarding what is left.
 */
export function extendSubscription(
  user: EntitlementSubject,
  plan: SubscriptionPlan = 'monthly',
  now: Date = new Date(),
): Date {
  const from = Math.max(now.getTime(), user.subscribedUntil?.getTime() ?? 0);
  return new Date(from + PLAN_DURATION_MS[plan]);
}
