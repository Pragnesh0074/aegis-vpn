import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { AllExceptionsFilter } from '../common/filters/all-exceptions.filter';
import { validateAgentEnv } from './agent-env.validation';
import { AgentModule } from './agent.module';

/**
 * Second entrypoint on the backend artifact: `node dist/agent/main`.
 *
 * The same tarball is deployed to every machine. One runs the API
 * (`dist/main`), each exit node runs this.
 */
async function bootstrap(): Promise<void> {
  const logger = new Logger('NodeAgent');

  // Validated before the app is built so a misconfigured agent dies at startup
  // rather than when the API first tries to install a peer through it.
  const env = validateAgentEnv(process.env);

  const app = await NestFactory.create<NestExpressApplication>(AgentModule, {
    bufferLogs: true,
  });
  app.use(helmet());
  app.useGlobalFilters(new AllExceptionsFilter());

  // No CORS: the only client is the API, server to server. A browser has no
  // business reaching this.
  await app.listen(env.AGENT_PORT, env.AGENT_BIND);

  logger.log(
    `node-agent listening on ${env.AGENT_BIND}:${env.AGENT_PORT} ` +
      `for interface ${env.WG_INTERFACE}`,
  );
  if (env.AGENT_BIND === '0.0.0.0') {
    logger.warn(
      'AGENT_BIND is 0.0.0.0 — the agent is reachable from any network. Put it ' +
        'behind TLS and a firewall, or bind it to a private address.',
    );
  }
}

void bootstrap();
