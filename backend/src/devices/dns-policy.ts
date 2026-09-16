import type { Node, User } from '@prisma/client';

/** The parts of a user this decision needs. Narrow so tests need not build a User. */
export type AdBlockSubject = Pick<User, 'adBlockEnabled' | 'adBlockUntil'>;
/** The parts of a node this decision needs. */
export type ResolverPair = Pick<Node, 'dns' | 'dnsUnfiltered'>;

/** How much filtering one watched rewarded ad buys. */
export const AD_BLOCK_GRANT_MS = 5 * 60 * 1000;

/**
 * Ceiling on how much unwatched time an account can bank.
 *
 * Grants stack, so without this someone could sit through twenty ads and hold a
 * permanent entitlement that was meant to be rented five minutes at a time. It
 * also bounds the damage if the grant endpoint is ever called in a loop — which
 * it can be, because nothing yet proves an ad was actually watched.
 */
export const AD_BLOCK_MAX_BANKED_MS = 60 * 60 * 1000;

/**
 * Whether the account may have filtering right now.
 *
 * The seam for monetisation. Today entitlement is rented: it comes from watching
 * a rewarded ad and expires. A paid plan would be checked here too, ahead of the
 * grant, so a subscriber never sees an ad.
 *
 * `now` is a parameter rather than read from the clock so the boundary is
 * testable and so a single request cannot straddle two different "now"s.
 */
export function entitledToAdBlocking(user: AdBlockSubject, now: Date = new Date()): boolean {
  return user.adBlockUntil !== null && user.adBlockUntil.getTime() > now.getTime();
}

/** Milliseconds of filtering left, floored at zero. For the client's countdown. */
export function adBlockRemainingMs(user: AdBlockSubject, now: Date = new Date()): number {
  if (user.adBlockUntil === null) return 0;
  return Math.max(0, user.adBlockUntil.getTime() - now.getTime());
}

/**
 * The new expiry after one more ad is watched.
 *
 * Extends from whichever is later — now, or the existing expiry — so watching a
 * second ad early adds five minutes rather than throwing away what is left.
 */
export function extendAdBlockGrant(user: AdBlockSubject, now: Date = new Date()): Date {
  const from = Math.max(now.getTime(), user.adBlockUntil?.getTime() ?? 0);
  const extended = from + AD_BLOCK_GRANT_MS;
  return new Date(Math.min(extended, now.getTime() + AD_BLOCK_MAX_BANKED_MS));
}

/**
 * The resolver address to write into this device's `[Interface] DNS`.
 *
 * Both addresses live on the node and neither leaks lookups to a public resolver:
 * `dns` is Blocky, which sinkholes ad domains and forwards the rest to Unbound;
 * `dnsUnfiltered` is that same Unbound, reached directly.
 *
 * A node provisioned before the unfiltered listener existed has `dnsUnfiltered`
 * null. There the switch cannot be honoured, and we keep filtering rather than
 * fall back to a public resolver — a user who wanted fewer ads should not be
 * quietly moved off the node's own DNS to get them.
 */
export function resolverFor(
  user: AdBlockSubject,
  node: ResolverPair,
  now: Date = new Date(),
): string {
  const filtered = user.adBlockEnabled && entitledToAdBlocking(user, now);
  if (filtered) return node.dns;
  return node.dnsUnfiltered ?? node.dns;
}

/**
 * Whether the node can actually honour a request to switch filtering off.
 *
 * Surfaced to the client so the settings switch can explain itself instead of
 * appearing to do nothing on a node that has only the one resolver.
 */
export function canToggleAdBlocking(node: ResolverPair): boolean {
  return node.dnsUnfiltered !== null && node.dnsUnfiltered !== node.dns;
}
