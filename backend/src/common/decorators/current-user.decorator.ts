import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { Request } from 'express';
import type { AuthenticatedUser } from '../../auth/auth.types';

/**
 * Injects the authenticated user. Only valid on routes behind `JwtAuthGuard`
 * (i.e. anything not marked `@Public()`).
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthenticatedUser => {
    const request = ctx.switchToHttp().getRequest<Request & { user?: AuthenticatedUser }>();
    if (!request.user) {
      // Reaching here means the decorator was used on a @Public() route — a wiring
      // bug, not a client error. Fail loudly instead of returning undefined.
      throw new Error('@CurrentUser() used on a route without JwtAuthGuard');
    }
    return request.user;
  },
);
