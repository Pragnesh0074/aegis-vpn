import {
  Inject,
  Injectable,
  Logger,
  OnApplicationBootstrap,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { Device, Node } from '@prisma/client';
import { AppConfig } from '../config/configuration';
import { PrismaService } from '../prisma/prisma.service';
import { IpAllocatorService } from './ip-allocator.service';
import { WG_RUNNER, type WgPeer, type WgRunner } from './wg-runner';
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
    @Inject(WG_RUNNER) private readonly runner: WgRunner,
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

    await this.runner.addPeer({
      publicKey: device.publicKey,
      // /32: a peer may only source traffic from its own address. A wider mask would
      // let one client spoof another's tunnel IP.
      allowedIps: [`${device.tunnelIpV4}/32`],
    });
    await this.runner.persist();
  }

  async revokePeer(publicKey: string): Promise<void> {
    assertValidPublicKey(publicKey);
    await this.runner.removePeer(publicKey);
    await this.runner.persist();
  }

  allocateIp(node: Node): Promise<string> {
    return this.allocator.nextFreeIp(node);
  }

  /**
   * Makes the interface match the database.
   *
   * Postgres is the source of truth: any peer on the interface that is not an active
   * device is removed, and any active device missing from the interface is added. This
   * is what makes the node disposable — wipe wg0, restart the API, and the fleet is
   * restored.
   *
   * Only devices on THIS node are considered, so a future multi-node deployment does
   * not have every API instance fighting over one interface.
   */
  async reconcile(nodeId?: string): Promise<ReconcileReport> {
    const node = nodeId
      ? await this.prisma.node.findUnique({ where: { id: nodeId } })
      : await this.prisma.node.findFirst({ where: { active: true }, orderBy: { createdAt: 'asc' } });

    if (!node) {
      throw new ServiceUnavailableException('No node row to reconcile against');
    }

    const devices = await this.prisma.device.findMany({
      where: { nodeId: node.id, revokedAt: null },
      select: { publicKey: true, tunnelIpV4: true },
    });

    const live = await this.runner.listPeers();
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

      await this.runner.addPeer({ publicKey: device.publicKey, allowedIps: [expected] });
      added++;
    }

    let removed = 0;
    for (const peer of live) {
      if (!wanted.has(peer.publicKey)) {
        await this.runner.removePeer(peer.publicKey);
        removed++;
      }
    }

    if (added > 0 || removed > 0) await this.runner.persist();

    return { added, removed, unchanged };
  }

  /** Live counters, for a future usage/stats endpoint. */
  listPeers(): Promise<WgPeer[]> {
    return this.runner.listPeers();
  }

  get runnerKind(): 'exec' | 'fake' {
    return this.runner.kind;
  }
}
