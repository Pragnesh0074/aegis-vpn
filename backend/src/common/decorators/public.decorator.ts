import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Opt a route out of authentication.
 *
 * `JwtAuthGuard` is registered globally, so every endpoint requires a valid access
 * token unless explicitly marked with this decorator. Secure by default: forgetting
 * to add a guard locks a route down rather than exposing it.
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
