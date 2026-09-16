import { Injectable, Logger } from '@nestjs/common';

/** What is known about one node's reachability. */
export interface NodeHealth {
  healthy: boolean;
  /** Consecutive failed probes. Reset to 0 by any success. */
  failures: number;
  /** When the node was last reached, or null if it never has been in this process. */
  lastReachableAt: Date | null;
  /** Why the last probe failed, for the log and for ops. */
  lastError: string | null;
}

/**
 * Which nodes are answering.
 *
 * `Node.active` is an operator's intent — "this node is part of the fleet" — and
 * it is set by hand. Nothing was watching whether a node was actually *there*,
 * so a node that died stayed in selection: every new device issued on it got a
 * config that could not connect, and every existing device on it was offline
 * until somebody noticed and flipped the flag.
 *
 * This is the observed half. The two are kept apart on purpose — an operator
 * taking a node out of rotation and a node falling over are different events and
 * a single flag could not tell them apart, nor could an automatic process safely
 * write to one an operator also edits.
 *
 * ## What this actually measures
 *
 * The probe is the peer sweep `LastSeenService` already performs: for a remote
 * node that is an HTTP call to its agent, for the local one a `wg show`. So it
 * detects a node whose **control plane** is unreachable — the box is down, the
 * agent is not running, the security group changed. It does **not** detect a
 * node whose agent answers while its data plane is broken: a NAT rule gone, the
 * AWS source/destination check re-enabled, upstream transit down. Those still
 * need the exit check on the client to surface.
 *
 * ## Why in memory
 *
 * Health is what this process has observed in the last minute, which is not a
 * fact about the fleet worth persisting: a restart re-learns all of it within one
 * sweep, and a stale row read by a second instance would be worse than no row.
 * It does mean a fresh process treats every node as healthy until proven
 * otherwise, which is the right starting assumption — refusing to issue peers
 * because nothing has been probed yet would turn a restart into an outage.
 */
@Injectable()
export class NodeHealthService {
  private readonly logger = new Logger(NodeHealthService.name);

  private readonly health = new Map<string, NodeHealth>();

  /**
   * Consecutive failures before a node is taken out of selection.
   *
   * More than one, because a single timeout is the most ordinary thing in the
   * world — a slow agent, a dropped packet, a sweep that overlapped a restart —
   * and treating it as an outage would move users between countries for nothing.
   * At a 60s sweep this means a genuinely dead node is out within about two
   * minutes.
   */
  static readonly FAILURES_BEFORE_UNHEALTHY = 2;

  /** Records a successful probe. Recovery is immediate: one answer is enough. */
  reachable(nodeId: string, name: string): void {
    const previous = this.health.get(nodeId);

    this.health.set(nodeId, {
      healthy: true,
      failures: 0,
      lastReachableAt: new Date(),
      lastError: null,
    });

    if (previous && !previous.healthy) {
      this.logger.log(`Node ${name} is answering again after ${previous.failures} failures`);
    }
  }

  /** Records a failed probe, and takes the node out of selection at the threshold. */
  unreachable(nodeId: string, name: string, error: string): void {
    const previous = this.health.get(nodeId);
    const failures = (previous?.failures ?? 0) + 1;
    const healthy = failures < NodeHealthService.FAILURES_BEFORE_UNHEALTHY;

    this.health.set(nodeId, {
      healthy,
      failures,
      lastReachableAt: previous?.lastReachableAt ?? null,
      lastError: error,
    });

    if (previous?.healthy !== false && !healthy) {
      this.logger.error(
        `Node ${name} is unreachable after ${failures} probes and is out of ` +
          `selection: ${error}`,
      );
    }
  }

  /**
   * Whether [nodeId] should be offered to clients.
   *
   * A node nothing has probed yet counts as healthy. The alternative — assume the
   * worst until proven otherwise — would make every API restart an outage for as
   * long as the first sweep takes.
   */
  isHealthy(nodeId: string): boolean {
    return this.health.get(nodeId)?.healthy ?? true;
  }

  get(nodeId: string): NodeHealth | null {
    return this.health.get(nodeId) ?? null;
  }

  /** Drops a node this process no longer has any reason to remember. */
  forget(nodeId: string): void {
    this.health.delete(nodeId);
  }
}
