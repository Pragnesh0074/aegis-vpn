import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { Observable, tap } from 'rxjs';

/**
 * One structured line per request.
 *
 * Logs method, path, status, duration and request id — never the request body or
 * headers. Bodies here carry passwords and WireGuard public keys, and an auth
 * endpoint that logs its own payload is how credentials end up in log aggregation.
 */
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();

    const http = context.switchToHttp();
    const req = http.getRequest<Request & { requestId?: string }>();
    const res = http.getResponse<Response>();
    const startedAt = Date.now();

    const line = (status: number) =>
      `${req.method} ${req.originalUrl} ${status} ${Date.now() - startedAt}ms ` +
      `[${req.requestId ?? '-'}]`;

    return next.handle().pipe(
      tap({
        next: () => this.logger.log(line(res.statusCode)),
        // The exception filter owns the status code, so read it from the error rather
        // than from the response, which has not been written yet.
        error: (error: unknown) => {
          const status =
            typeof error === 'object' && error !== null && 'status' in error
              ? Number((error as { status: unknown }).status) || 500
              : 500;
          this.logger.warn(line(status));
        },
      }),
    );
  }
}
