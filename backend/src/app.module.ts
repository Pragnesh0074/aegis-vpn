import { Module } from '@nestjs/common';
import { AppConfigModule } from './config/config.module';
import { HealthModule } from './health/health.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [
    AppConfigModule,
    PrismaModule,
    HealthModule,
    // C3 AuthModule
    // C4 UsersModule
    // C5 NodesModule
    // C6 WireguardModule
    // C7 DevicesModule
  ],
})
export class AppModule {}
