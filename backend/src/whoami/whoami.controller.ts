import { Controller, Get, Req } from '@nestjs/common';
import type { Request } from 'express';
import { Public } from '../common/decorators/public.decorator';
import { WhoamiService, type WhoamiResponse } from './whoami.service';

@Controller('whoami')
export class WhoamiController {
  constructor(private readonly whoami: WhoamiService) {}

  /**
   * The address this request arrived from, and whether it is one of ours.
   *
   * Unauthenticated on purpose. The client calls it both before and after
   * connecting, and the second call has to work over a tunnel that may have come
   * up before the access token was refreshed — an expired token would turn a leak
   * check into a 401, which is the least useful possible answer to "am I
   * protected?".
   *
   * `req.ip` is Express's, so it honours `X-Forwarded-For` only when TRUST_PROXY
   * is on. That is the same setting the rate limiter depends on, and getting it
   * wrong here is visible rather than silent: every check would report Caddy's
   * address.
   *
   * Left on the default throttle rather than given a tighter one. Every client
   * connected through a given node shares that node's egress address, so a strict
   * per-IP limit here would have one user's checks lock out everyone else's.
   */
  @Public()
  @Get()
  check(@Req() request: Request): Promise<WhoamiResponse> {
    return this.whoami.check(request.ip);
  }
}
