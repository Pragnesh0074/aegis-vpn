import type { Node, User } from '@prisma/client';

/** The parts of a user this decision needs. Narrow so tests need not build a User. */
export type AdBlockSubject = Pick<User, 'adBlockEnabled'>;
/** The parts of a node this decision needs. */
export type ResolverPair = Pick<Node, 'dns' | 'dnsUnfiltered'>;

/**
 * Whether this user's plan includes ad blocking at all.
 *
 * The seam for paid plans. Today every account is entitled, so the toggle is the
 * only thing that decides. When billing lands, this is the single function that
 * changes — `adBlockEnabled` stays what the user *asked* for, and this says what
 * they may actually have, so downgrading a lapsed subscriber does not silently
 * erase the preference they will get back when they renew.
 */
export function entitledToAdBlocking(_user: AdBlockSubject): boolean {
  return true;
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
