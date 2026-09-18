import type { Node, User } from '@prisma/client';
import { isEntitled, type EntitlementSubject } from '../users/entitlement';

/** The parts of a user this decision needs. Narrow so tests need not build a User. */
export type AdBlockSubject = Pick<User, 'adBlockEnabled'> & EntitlementSubject;
/** The parts of a node this decision needs. */
export type ResolverPair = Pick<Node, 'dns' | 'dnsUnfiltered'>;

/**
 * Whether this account's plan includes ad blocking.
 *
 * `adBlockEnabled` records what the user asked for; this says what they may
 * actually have. Kept apart so a lapsed subscriber keeps the preference and gets
 * it back on renewal rather than finding the switch silently flipped off.
 *
 * This is the ONE gate that is enforced server-side: it decides which resolver
 * address the device is handed, so a modified client cannot grant itself
 * filtering. The kill switch and split tunnelling are device features and their
 * gate is UI only.
 */
export function entitledToAdBlocking(
  user: AdBlockSubject,
  now: Date = new Date(),
): boolean {
  return isEntitled(user, now);
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
