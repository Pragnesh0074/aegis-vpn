import { Inject, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import type { Node } from '@prisma/client';
import { AppConfig } from '../config/configuration';
import { PrismaService } from '../prisma/prisma.service';
import { HttpWgRunner } from './runners/http-wg.runner';
import { WG_RUNNER, type WgRunner } from './wg-runner';

/**
 * Decides which runner programs a given node.
 *
 * This exists because `WireguardService` used to hold one runner for the whole
 * fleet. `applyPeer` took the chosen node, validated the tunnel address against
 * that node's subnet — and then wrote the peer to whatever interface this host
 * happened to have. With a second node in the database that is not a small bug:
 * the client is handed a valid-looking config for Frankfurt whose peer lives on
 * Mumbai's `wg0`, so the handshake never completes and nothing in the system says
 * why.
 *
 * The rule is deliberately narrow. A node is programmed locally only when it is
 * *this* host's node; anything else must say how to reach it. A node that is
 * neither throws, because there is no safe guess — and a loud failure at issue
 * time is worth far more than a tunnel that comes up and carries nothing.
 */
@Injectable()
export class WgRunnerRegistry {
  private readonly logger = new Logger(WgRunnerRegistry.name);

  /** One runner per remote node, so a fetch agent and its config are not rebuilt per call. */
  private readonly remote = new Map<string, HttpWgRunner>();

  private warnedAboutImplicitLocal = false;

  constructor(
    @Inject(WG_RUNNER) private readonly local: WgRunner,
    private readonly config: AppConfig,
    private readonly prisma: PrismaService,
  ) {}

  async forNode(node: Pick<Node, 'id' | 'name' | 'agentUrl' | 'agentToken'>): Promise<WgRunner> {
    if (await this.isLocal(node.id)) return this.local;

    if (node.agentUrl && node.agentToken) {
      const cached = this.remote.get(node.id);
      if (cached) return cached;

      const runner = new HttpWgRunner({
        id: node.id,
        name: node.name,
        agentUrl: node.agentUrl,
        agentToken: node.agentToken,
      });
      this.remote.set(node.id, runner);
      return runner;
    }

    throw new ServiceUnavailableException(
      `Node ${node.name} is not this host's node and has no agent configured. ` +
        `Set agentUrl and agentToken on it, or point WG_NODE_ID at it.`,
    );
  }

  /**
   * Whether this process programs [nodeId] directly.
   *
   * `WG_NODE_ID` is the answer when it is set. It is allowed to be unset only while
   * a single node is active, which is what keeps the original single-node
   * deployment working without a config change — there is exactly one node it could
   * mean. The moment a second node exists that inference is a coin flip, so it
   * refuses rather than guessing.
   */
  private async isLocal(nodeId: string): Promise<boolean> {
    const configured = this.config.wgNodeId;
    if (configured) return nodeId === configured;

    const active = await this.prisma.node.count({ where: { active: true } });
    if (active > 1) {
      throw new ServiceUnavailableException(
        'WG_NODE_ID must be set once more than one node is active, so the API knows ' +
          'which interface it owns.',
      );
    }

    if (!this.warnedAboutImplicitLocal) {
      this.warnedAboutImplicitLocal = true;
      this.logger.warn(
        'WG_NODE_ID is not set; assuming the only active node is this host. Set it ' +
          'before adding a second node.',
      );
    }
    return true;
  }

  /** Clears cached agent clients, so a rotated token takes effect without a restart. */
  forget(nodeId: string): void {
    this.remote.delete(nodeId);
  }
}
