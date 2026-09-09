import type { ThrottlerModuleOptions } from '@nestjs/throttler';

/**
 * A single named throttler ('default') so that per-route `@Throttle()` overrides it
 * rather than stacking on top of it. Registering a second named throttler would apply
 * BOTH limits to every route, which is rarely what anyone means.
 */
export const THROTTLER_OPTIONS: ThrottlerModuleOptions = [
  { name: 'default', ttl: 60_000, limit: 120 },
];

/**
 * Tight limit for credential endpoints. `/auth/login` runs argon2 on every call, so
 * it is both a credential-stuffing target and a CPU amplification vector.
 */
export const AUTH_THROTTLE = { default: { limit: 5, ttl: 60_000 } };

/** Slightly looser: a legitimate client refreshes on a timer, not in bursts. */
export const REFRESH_THROTTLE = { default: { limit: 20, ttl: 60_000 } };
