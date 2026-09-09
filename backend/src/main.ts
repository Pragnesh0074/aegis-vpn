import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { AppConfig } from './config/configuration';

async function bootstrap(): Promise<void> {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bufferLogs: true });
  const config = app.get(AppConfig);

  app.use(helmet());

  // Only honour X-Forwarded-For when a proxy really is in front. Trusting it
  // unconditionally would let any client forge the header and bypass rate limiting;
  // not trusting it behind Caddy would collapse every user onto Caddy's IP and
  // throttle them all as one.
  if (config.trustProxy) {
    app.set('trust proxy', 1);
  }

  const origins = config.corsOrigins;
  if (origins.length > 0) {
    app.enableCors({ origin: origins, credentials: true });
  } else if (!config.isProduction) {
    app.enableCors({ origin: true, credentials: true });
  }
  // In production with no CORS_ORIGINS set, CORS stays off. The Flutter app is a
  // native client and does not need it; a browser origin must be listed explicitly.

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // strip unknown properties
      forbidNonWhitelisted: true, // and reject requests that send them
      transform: true,
      transformOptions: { enableImplicitConversion: false },
    }),
  );

  app.useGlobalFilters(new AllExceptionsFilter());
  app.enableShutdownHooks();

  await app.listen(config.port, '0.0.0.0');

  logger.log(`Aegis VPN API listening on :${config.port} [${config.nodeEnv}]`);
  logger.log(`WireGuard runner: ${config.wgRunner} (interface ${config.wgInterface})`);
  logger.log(`Trust proxy: ${config.trustProxy}`);
  if (config.wgRunner === 'fake') {
    logger.warn('WG_RUNNER=fake — peers are in-memory only and no tunnel will work');
  }
}

void bootstrap();
