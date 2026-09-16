import { Injectable, Logger, OnApplicationBootstrap, OnModuleDestroy } from '@nestjs/common';
import type { Node } from '@prisma/client';
import { AppConfig } from '../config/configuration';
import { NodeHealthService } from '../nodes/node-health.service';
import { PrismaService } from '../prisma/prisma.service';
import { WireguardService } from '../wireguard/wireguard.service';

/** What one pass over the fleet did. Returned so a test can assert on it. */
export interface SweepReport {
  /** Nodes whose peers were read successfully. */
  swept: number;
  /** Nodes that could not be reached, and were skipped. */
  failed: number;
  /** Device rows whose `lastSeenAt` moved forward. */
  updated: number;
}

/** The columns a sweep needs. A whole `Node` is more than the reader wants. */
type SweepNode = Pick<Node, 'id' | 'name' | 'agentUrl' | 'agentToken'>;

/**
 * Keeps `Device.lastSeenAt` honest.
 *
 * The column has existed since C2 and was never written, so every device in the
 * account screen read "Last seen never" no matter how much traffic it had
 * carried. WireGuard already knows the answer — `wg show dump` reports each
 * peer's latest handshake — but nothing was asking, and nothing can: a peer does
 * not check in with the API, it talks to a kernel interface that has no idea an
 * API exists. A poll is the only way this data reaches the database.
 *
 * Why the handshake and not, say, a client heartbeat: the handshake is the one
 * event that cannot be faked by a client that is not actually connected. It is
 * proof the peer completed a key exchange with the node, which is precisely what
 * "this device is in use" should mean.
 *
 * The sweep is deliberately one-directional — it only ever moves a timestamp
 * forward. A node rebuilt from its config starts with no handshake history at
 * all, and a device that last connected a week ago must not have its timestamp
 * blanked or walked backwards because the interface has forgotten.
 *
 * ## It is also the fleet's health probe
 *
 * Reading a node's peers means reaching that node — an HTTP call to its agent,
 * or `wg show` locally — so every sweep already answers "is this node there?".
 * That answer goes to [NodeHealthService], which takes an unreachable node out
 * of selection. A second poller doing the same work on its own timer would be
 * two things to keep in step and twice the traffic to an agent that is already
 * being asked.
 */
@Injectable()
export class LastSeenService implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger(LastSeenService.name);

  private timer: NodeJS.Timeout | null = null;
  private stopped = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly wg: WireguardService,
    private readonly config: AppConfig,
    private readonly health: NodeHealthService,
  ) {}

  onApplicationBootstrap(): void {
    const seconds = this.config.lastSeenPollSeconds;
    if (seconds <= 0) {
      this.logger.log('Handshake sweeps disabled (DEVICE_LAST_SEEN_POLL_SECONDS=0)');
      return;
    }
    this.logger.log(`Sweeping peer handshakes every ${seconds}s`);
    this.schedule(seconds);
  }

  onModuleDestroy(): void {
    this.stopped = true;
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
  }

  /**
   * Chained `setTimeout` rather than `setInterval`: a sweep that takes longer
   * than the interval — an agent timing out, say — must not have the next one
   * start on top of it and queue writes behind a call that is already stuck.
   *
   * `unref` so this timer alone never keeps the process alive. Without it a test
   * run or a `SIGTERM` during the idle gap would wait out the full interval.
   */
  private schedule(seconds: number): void {
    this.timer = setTimeout(() => void this.tick(seconds), seconds * 1_000);
    this.timer.unref();
  }

  private async tick(seconds: number): Promise<void> {
    try {
      const report = await this.sweep();
      if (report.updated > 0 || report.failed > 0) {
        this.logger.log(
          `Handshake sweep: ${report.updated} updated, ${report.swept} nodes read, ` +
            `${report.failed} unreachable`,
        );
      }
    } catch (error) {
      this.logger.error(
        `Handshake sweep failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
    // Rescheduled after the failure too. A node that is down now is exactly the
    // one whose devices need re-checking in a minute.
    if (!this.stopped) this.schedule(seconds);
  }

  /**
   * Reads every active node's peers and moves the matching devices forward.
   *
   * Each node is independent: one unreachable agent must not cost the rest of the
   * fleet its timestamps, so a failure there is counted and skipped rather than
   * thrown.
   */
  async sweep(): Promise<SweepReport> {
    const nodes = await this.prisma.node.findMany({
      where: { active: true },
      select: { id: true, name: true, agentUrl: true, agentToken: true },
    });

    let swept = 0;
    let failed = 0;
    let updated = 0;

    for (const node of nodes) {
      try {
        updated += await this.sweepNode(node);
        swept++;
        this.health.reachable(node.id, node.name);
      } catch (error) {
        failed++;
        const message = error instanceof Error ? error.message : String(error);
        // Reaching the node is the probe; the health service decides how many
        // failures in a row amount to an outage rather than a bad minute.
        this.health.unreachable(node.id, node.name, message);
        this.logger.warn(`Could not read peers on ${node.name}: ${message}`);
      }
    }

    return { swept, failed, updated };
  }

  private async sweepNode(node: SweepNode): Promise<number> {
    const handshakes = new Map<string, Date>();
    for (const peer of await this.wg.listPeers(node)) {
      // A peer with no handshake has never completed one — not the same as one
      // whose handshake is old, and it carries no timestamp to write.
      if (peer.latestHandshakeAt) handshakes.set(peer.publicKey, peer.latestHandshakeAt);
    }
    if (handshakes.size === 0) return 0;

    // Scoped to this node's own devices as well as to the keys seen: a public key
    // is globally unique, but querying by key alone would let a stale peer left on
    // one node's interface write a timestamp for a device issued on another.
    const devices = await this.prisma.device.findMany({
      where: {
        nodeId: node.id,
        revokedAt: null,
        publicKey: { in: [...handshakes.keys()] },
      },
      select: { id: true, publicKey: true, lastSeenAt: true },
    });

    let updated = 0;
    for (const device of devices) {
      const seenAt = handshakes.get(device.publicKey);
      if (!seenAt) continue;
      // Forward only, and skip the no-op. An idle device handshakes roughly every
      // two minutes, so without this every sweep would write every row.
      if (device.lastSeenAt && device.lastSeenAt.getTime() >= seenAt.getTime()) continue;

      await this.prisma.device.update({
        where: { id: device.id },
        data: { lastSeenAt: seenAt },
      });
      updated++;
    }

    return updated;
  }
}
