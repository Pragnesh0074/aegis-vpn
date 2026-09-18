import type { Node, User } from '@prisma/client';

/** The parts of a user this decision needs. Narrow so tests need not build a User. */
export type AdBlockSubject = Pick<User, 'adBlockEnabled'>;
/** The parts of a node this decision needs. */
export type ResolverPair = Pick<Node, 'dns' | 'dnsUnfiltered'>;

/**
 * Whether this account's plan includes ad blocking at all.
 *
 * The seam for monetisation, and deliberately still here after the rewarded-ad
 * experiment was removed. `adBlockEnabled` records what the user asked for; this
 * says what they may actually have, so a lapsed subscriber keeps the preference
 * they get back on renewal instead of silently losing it.
 *
 * Every account is entitled today. When a paid plan lands, this is the one
 * function that changes.
 */
export function entitledToAdBlocking(_user: AdBlockSubject): boolean {
  return true;
}

/**
 * The resolver address to write into this device's `[Interface] DNS`.
 *
 * Both addresses live on the node and neither leaks lookups to a public
 * resolver: `dns` is Blocky, which sinkholes ad domains and forwards the rest to
 * Unbound; `dnsUnfiltered` is a second Blocky with no blocklists in front of the
 * same Unbound.
 *
 * A node provisioned before the unfiltered listener existed has `dnsUnfiltered`
 * null. There the switch cannot be honoured, and we keep filtering rather than
 * fall back to a public resolver — a user who wanted fewer restrictions should
 * not be quietly moved off the node's own DNS to get them.
 */
export function resolverFor(user: AdBlockSubject, node: ResolverPair): string {
  const filtered = user.adBlockEnabled && entitledToAdBlocking(user);
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
