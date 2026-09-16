import type { Node } from '@prisma/client';
import type { PrismaService } from '../prisma/prisma.service';
import { NodeHealthService } from './node-health.service';
import { NodesService } from './nodes.service';

const node = (id: string, name: string, maxPeers = 250): Node =>
  ({ id, name, region: 'in-mumbai', maxPeers, active: true }) as Node;

/**
 * Selection is where node health has to bite. A node that is not answering can
 * still have capacity, and handing a client a peer on it produces a config that
 * looks perfect and silently cannot connect.
 */
function harness(nodes: Node[], peersPerNode: Record<string, number> = {}) {
  const prisma = {
    node: { findMany: async () => nodes },
    device: {
      groupBy: async () =>
        Object.entries(peersPerNode).map(([nodeId, count]) => ({
          nodeId,
          _count: { _all: count },
        })),
    },
  } as unknown as PrismaService;

  const health = new NodeHealthService();
  return { service: new NodesService(prisma, health), health };
}

function killNode(health: NodeHealthService, id: string): void {
  for (let i = 0; i < NodeHealthService.FAILURES_BEFORE_UNHEALTHY; i++) {
    health.unreachable(id, id, 'unreachable');
  }
}

describe('NodesService', () => {
  describe('selectLeastLoaded', () => {
    it('skips a node that is not answering, even when it is the emptiest', async () => {
      const { service, health } = harness(
        [node('n1', 'Mumbai #1'), node('n2', 'Frankfurt #1')],
        { n1: 100 },
      );
      killNode(health, 'n2');

      // Frankfurt is completely empty and would win on load alone.
      await expect(service.selectLeastLoaded()).resolves.toMatchObject({ id: 'n1' });
    });

    it('falls back to the emptiest node when nothing is answering', async () => {
      // A whole fleet reading as down is far more likely to be a broken probe
      // than every node being dead, and refusing to issue anything would turn
      // that into a total outage.
      const { service, health } = harness([node('n1', 'Mumbai #1'), node('n2', 'Frankfurt #1')], {
        n1: 100,
      });
      killNode(health, 'n1');
      killNode(health, 'n2');

      await expect(service.selectLeastLoaded()).resolves.toMatchObject({ id: 'n2' });
    });

    it('still refuses when the fleet is genuinely full', async () => {
      const { service } = harness([node('n1', 'Mumbai #1', 2)], { n1: 2 });

      await expect(service.selectLeastLoaded()).rejects.toThrow(/capacity/i);
    });
  });

  describe('listActive', () => {
    it('reports an unreachable node as unavailable, and says why', async () => {
      const { service, health } = harness([node('n1', 'Mumbai #1')]);
      killNode(health, 'n1');

      const [summary] = await service.listActive();

      // Two different facts: a client has to be able to tell "full" from
      // "offline", because only one of them is worth waiting out.
      expect(summary.healthy).toBe(false);
      expect(summary.available).toBe(false);
    });

    it('reports a reachable node with room as available', async () => {
      const { service } = harness([node('n1', 'Mumbai #1')], { n1: 10 });

      const [summary] = await service.listActive();

      expect(summary.healthy).toBe(true);
      expect(summary.available).toBe(true);
      expect(summary.load).toBeCloseTo(10 / 250);
    });
  });
});
