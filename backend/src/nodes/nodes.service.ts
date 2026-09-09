import { Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import type { Node } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

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
  available: boolean;
}

@Injectable()
export class NodesService {
  constructor(private readonly prisma: PrismaService) {}

  async listActive(): Promise<NodeSummary[]> {
    const nodes = await this.prisma.node.findMany({
      where: { active: true },
      orderBy: [{ region: 'asc' }, { name: 'asc' }],
    });
    if (nodes.length === 0) return [];

    const counts = await this.peerCounts(nodes.map((n) => n.id));

    return nodes.map((node) => {
      const used = counts.get(node.id) ?? 0;
      return {
        id: node.id,
        name: node.name,
        region: node.region,
        load: node.maxPeers > 0 ? Math.min(1, used / node.maxPeers) : 1,
        available: used < node.maxPeers,
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
    return withRoom[0].node;
  }
}
