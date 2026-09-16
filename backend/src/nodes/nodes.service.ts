import {
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { Node } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NodeHealthService } from './node-health.service';

/**
 * What a client is told about a node.
 *
 * Deliberately excludes `publicKey`, `subnetV4` and `dns`. Those are only meaningful
 * alongside an issued peer and are returned by POST /devices instead — no reason to
 * hand the whole fleet's tunnel topology to anyone with an account.
 */
export interface NodeSummary {
  id: string;
  name: string;
  region: string;
  /** 0.0-1.0 — active peers divided by capacity. */
  load: number;
  /** False once the node is full, or once it has stopped answering. */
  available: boolean;
  /**
   * Whether the API can currently reach this node's control plane.
   *
   * Separate from `available` so a client can say *why* a node cannot be used —
   * "full" and "offline" are different things to a person choosing a country.
   */
  healthy: boolean;
}

@Injectable()
export class NodesService {
  private readonly logger = new Logger(NodesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly health: NodeHealthService,
  ) {}

  async listActive(): Promise<NodeSummary[]> {
    const nodes = await this.prisma.node.findMany({
      where: { active: true },
      orderBy: [{ region: 'asc' }, { name: 'asc' }],
    });
    if (nodes.length === 0) return [];

    const counts = await this.peerCounts(nodes.map((n) => n.id));

    return nodes.map((node) => {
      const used = counts.get(node.id) ?? 0;
      const healthy = this.health.isHealthy(node.id);
      return {
        id: node.id,
        name: node.name,
        region: node.region,
        load: node.maxPeers > 0 ? Math.min(1, used / node.maxPeers) : 1,
        // A node that is not answering cannot take a peer, whatever its capacity
        // says: the peer would be written to an interface nobody can reach and
        // the client would get a config that silently cannot connect.
        available: healthy && used < node.maxPeers,
        healthy,
      };
    });
  }

  /**
   * Active peers per node, in one query.
   *
   * `groupBy` omits nodes with zero devices entirely, so callers must treat a missing
   * key as 0 rather than assuming every node id is present.
   */
  private async peerCounts(nodeIds: string[]): Promise<Map<string, number>> {
    const grouped = await this.prisma.device.groupBy({
      by: ['nodeId'],
      where: { nodeId: { in: nodeIds }, revokedAt: null },
      _count: { _all: true },
    });
    return new Map(grouped.map((row) => [row.nodeId, row._count._all]));
  }

  async findActiveOrThrow(nodeId: string): Promise<Node> {
    const node = await this.prisma.node.findFirst({ where: { id: nodeId, active: true } });
    if (!node) throw new NotFoundException('Node not found or inactive');
    return node;
  }

  /**
   * Picks the emptiest node with room left. Used by C7 when a client does not name one.
   *
   * No longer what "automatic" means to a user. The app ranks the fleet by distance
   * from the device and names the node it wants, because the server cannot tell where
   * a client is without geolocating its address — which, for a VPN, is the one lookup
   * it should not be doing. This rule was standing in for that and got it wrong in an
   * obvious way: sorted purely by free slots, it sent a user in Mumbai to Frankfurt
   * the moment Frankfurt was quieter.
   *
   * It remains the fallback for a request that names no node — an old client, or a new
   * one with nothing to rank by — so the endpoint always has an answer.
   *
   * This is a read, so the chosen node can fill up before the peer is actually
   * inserted. The allocator in C6 is the real guard against overfilling — this only
   * spreads load and gives a clear error when the whole fleet is full.
   */
  async selectLeastLoaded(): Promise<Node> {
    const nodes = await this.prisma.node.findMany({ where: { active: true } });
    if (nodes.length === 0) {
      throw new ServiceUnavailableException('No VPN nodes are configured');
    }

    const counts = await this.peerCounts(nodes.map((n) => n.id));

    const withRoom = nodes
      .map((node) => ({ node, free: node.maxPeers - (counts.get(node.id) ?? 0) }))
      .filter((candidate) => candidate.free > 0)
      .sort((a, b) => b.free - a.free);

    if (withRoom.length === 0) {
      throw new ServiceUnavailableException('All VPN nodes are at capacity');
    }

    // Unreachable nodes are skipped, but not at the cost of having no answer: if
    // the whole fleet looks down, the probe is more likely to be wrong than every
    // node to be dead, and issuing a peer that might work beats refusing outright.
    const reachable = withRoom.filter((candidate) => this.health.isHealthy(candidate.node.id));
    if (reachable.length > 0) return reachable[0].node;

    this.logger.warn('No node is answering; falling back to the emptiest one');
    return withRoom[0].node;
  }
}
