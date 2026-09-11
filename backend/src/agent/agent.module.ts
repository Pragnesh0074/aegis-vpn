import { Module } from '@nestjs/common';
import { ExecWgRunner } from '../wireguard/runners/exec-wg.runner';
import { WG_EXEC_OPTIONS, WG_RUNNER, type WgExecOptions } from '../wireguard/wg-runner';
import { validateAgentEnv, type AgentEnv } from './agent-env.validation';
import { AgentTokenGuard } from './agent-token.guard';
import { AgentController } from './agent.controller';
import { AGENT_ENV } from './agent.tokens';

/**
 * The node-agent.
 *
 * Note what is absent: no Prisma, no auth module, no JWT strategy, no throttler
 * keyed on user identity. The agent runs `ExecWgRunner` — the same class the API
 * uses for its own interface — behind one bearer token, and holds nothing else
 * worth stealing.
 *
 * `ExecWgRunner` is bound to `WG_RUNNER` directly here. There is no fake variant:
 * an agent exists only on a machine that has WireGuard, and a no-op agent would
 * acknowledge peers it never installed, which is the exact failure this whole
 * series is about.
 */
@Module({
  controllers: [AgentController],
  providers: [
    {
      provide: AGENT_ENV,
      useFactory: (): AgentEnv => validateAgentEnv(process.env),
    },
    {
      provide: WG_EXEC_OPTIONS,
      inject: [AGENT_ENV],
      useFactory: (env: AgentEnv): WgExecOptions => ({
        interfaceName: env.WG_INTERFACE,
        binary: env.WG_BINARY,
        quickBinary: env.WG_QUICK_BINARY,
      }),
    },
    { provide: WG_RUNNER, useClass: ExecWgRunner },
    ExecWgRunner,
    AgentTokenGuard,
  ],
})
export class AgentModule {}
