import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { Device, Node } from '@prisma/client';
import { AppConfig } from '../config/configuration';
import { PrismaService } from '../prisma/prisma.service';
import { IpAllocatorService } from './ip-allocator.service';
import { WgRunnerRegistry } from './wg-runner.registry';
import type { WgPeer } from './wg-runner';
import { assertIpInSubnet, assertValidPublicKey } from './wg-validation';

export interface ReconcileReport {
  added: number;
  removed: number;
  unchanged: number;
}

@Injectable()
export class WireguardService implements OnApplicationBootstrap {
  private readonly logger = new Logger(WireguardService.name);

  constructor(
    private readonly runners: WgRunnerRegistry,
    private readonly prisma: PrismaService,
    private readonly allocator: IpAllocatorService,
    private readonly config: AppConfig,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    if (!this.config.wgReconcileOnBoot) {
      this.logger.log('Boot reconciliation disabled (WG_RECONCILE_ON_BOOT=false)');
      return;
    }
    try {
      const report = await this.reconcile();
      this.logger.log(
        `Reconciled ${this.config.wgInterface}: +${report.added} -${report.removed} ` +
          `=${report.unchanged}`,
      );
    } catch (error) {
      // A reconcile failure must not stop the API from serving. Existing peers keep
      // working; the log is the signal that the interface may have drifted.
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Boot reconciliation failed: ${message}`);
    }
  }

  /**
   * Adds a peer for an already-persisted device row.
   *
   * Called after the database insert so the unique constraint has already settled who
   * owns the address. Validation runs again here because this is the last point before
   * the values reach the runner.
   */
  async applyPeer(device: Pick<Device, 'publicKey' | 'tunnelIpV4'>, node: Node): Promise<void> {
    assertValidPublicKey(device.publicKey);
    assertIpInSubnet(device.tunnelIpV4, node.subnetV4);

    // Resolved from the node, not from this host. The address was just validated
    // against this node's subnet, and writing it to a different node's interface
    // would install a peer nobody can reach.
    const runner = await this.runners.forNode(node);

    await runner.addPeer({
      publicKey: device.publicKey,
      // /32: a peer may only source traffic from its own address. A wider mask would
      // let one client spoof another's tunnel IP.
      allowedIps: [`${device.tunnelIpV4}/32`],
    });
    await runner.persist();
  }

  /**
   * Removes a peer from the node that holds it.
   *
   * [node] is required rather than inferred. A public key alone does not say which
   * interface the peer is on, and removing it from the wrong one would report
   * success while leaving a revoked device able to carry traffic.
   */
  async revokePeer(
    publicKey: string,
    node: Pick<Node, 'id' | 'name' | 'agentUrl' | 'agentToken'>,
  ): Promise<void> {
    assertValidPublicKey(publicKey);
    const runner = await this.runners.forNode(node);
    await runner.removePeer(publicKey);
    await runner.persist();
  }

  allocateIp(node: Node): Promise<string> {
    return this.allocator.nextFreeIp(node);
  }

  /**
   * Makes a node's interface match the database.
   *
   * Postgres is the source of truth: any peer on the interface that is not an active
   * device is removed, and any active device missing from the interface is added. This
   * is what makes a node disposable — wipe its wg0, reconcile, and the fleet is
   * restored.
   *
   * Only devices on the target node are considered, so reconciling one node never
   * touches another's peers. Passing a remote node's id works and goes through its
   * agent; boot reconciliation deliberately only does this host's own node.
   */
  async reconcile(nodeId?: string): Promise<ReconcileReport> {
    const target = nodeId ?? this.config.wgNodeId;

    const node = target
      ? await this.prisma.node.findUnique({ where: { id: target } })
      : await this.prisma.node.findFirst({
          where: { active: true },
          orderBy: { createdAt: 'asc' },
        });

    if (!node) {
      throw new ServiceUnavailableException('No node row to reconcile against');
    }

    const runner = await this.runners.forNode(node);

    const devices = await this.prisma.device.findMany({
      where: { nodeId: node.id, revokedAt: null },
      select: { publicKey: true, tunnelIpV4: true },
    });

    const live = await runner.listPeers();
    const liveByKey = new Map<string, WgPeer>(live.map((p) => [p.publicKey, p]));
    const wanted = new Map(devices.map((d) => [d.publicKey, d]));

    let added = 0;
    let unchanged = 0;

    for (const device of devices) {
      const existing = liveByKey.get(device.publicKey);
      const expected = `${device.tunnelIpV4}/32`;

      // Re-apply when the allowed-ips drifted, not just when the peer is missing:
      // a peer present with the wrong address routes another client's traffic.
      if (existing && existing.allowedIps.length === 1 && existing.allowedIps[0] === expected) {
        unchanged++;
        continue;
      }

      await runner.addPeer({ publicKey: device.publicKey, allowedIps: [expected] });
      added++;
    }

    let removed = 0;
    for (const peer of live) {
      if (!wanted.has(peer.publicKey)) {
        await runner.removePeer(peer.publicKey);
        removed++;
      }
    }

    if (added > 0 || removed > 0) await runner.persist();

    return { added, removed, unchanged };
  }

  /** Live counters for one node, for a future usage/stats endpoint. */
  async listPeers(node: Pick<Node, 'id' | 'name' | 'agentUrl' | 'agentToken'>): Promise<WgPeer[]> {
    return (await this.runners.forNode(node)).listPeers();
  }
}
