import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { RequestIdMiddleware } from './common/middleware/request-id.middleware';
import { THROTTLER_OPTIONS } from './common/throttler.config';
import { AppConfigModule } from './config/config.module';
import { DevicesModule } from './devices/devices.module';
import { HealthModule } from './health/health.module';
import { NodesModule } from './nodes/nodes.module';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';
import { WireguardModule } from './wireguard/wireguard.module';

@Module({
  imports: [
    AppConfigModule,
    PrismaModule,
    ThrottlerModule.forRoot(THROTTLER_OPTIONS),
    AuthModule,
    HealthModule,
    UsersModule,
    NodesModule,
    WireguardModule,
    DevicesModule,
  ],
  providers: [
    // Order matters: global guards run in registration order, so rate limiting is
    // applied before authentication. Otherwise every throttled login attempt would
    // still pay for an argon2 verification.
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    // Authentication is on by default for every route. Opt out with @Public().
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_INTERCEPTOR, useClass: LoggingInterceptor },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(RequestIdMiddleware).forRoutes('*');
  }
}
