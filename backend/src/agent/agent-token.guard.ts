import {
  CanActivate,
  ExecutionContext,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { timingSafeEqual } from 'node:crypto';
import type { Request } from 'express';
import type { AgentEnv } from './agent-env.validation';
import { AGENT_ENV } from './agent.tokens';

/**
 * The agent's only authentication: a bearer token shared with the API through the
 * node's `agentToken` column.
 *
 * Compared in constant time. A short-circuiting compare on a secret an attacker can
 * probe at will is the textbook way to leak it a byte at a time, and this one grants
 * peer control over the interface.
 */
@Injectable()
export class AgentTokenGuard implements CanActivate {
  constructor(@Inject(AGENT_ENV) private readonly env: AgentEnv) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const header = request.headers.authorization ?? '';
    const presented = header.startsWith('Bearer ') ? header.slice(7) : '';

    if (!tokenMatches(presented, this.env.WG_AGENT_TOKEN)) {
      throw new UnauthorizedException('Invalid agent token');
    }
    return true;
  }
}

export function tokenMatches(presented: string, expected: string): boolean {
  const a = Buffer.from(presented, 'utf8');
  const b = Buffer.from(expected, 'utf8');
  // timingSafeEqual throws outright on a length mismatch, so lengths are checked
  // first. That leaks the length of the expected token and nothing else; the
  // comparison of equal-length candidates stays constant time, which is the part
  // that matters.
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}
