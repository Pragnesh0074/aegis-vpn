import type { Node } from '@prisma/client';
import type { AppConfig } from '../config/configuration';
import { NodeHealthService } from '../nodes/node-health.service';
import type { PrismaService } from '../prisma/prisma.service';
import type { WgPeer } from '../wireguard/wg-runner';
import type { WireguardService } from '../wireguard/wireguard.service';
import { LastSeenService } from './last-seen.service';

const HOUR_AGO = new Date('2026-09-15T09:00:00.000Z');
const NOW = new Date('2026-09-15T10:00:00.000Z');

const peer = (publicKey: string, latestHandshakeAt: Date | null): WgPeer => ({
  publicKey,
  allowedIps: ['10.8.0.2/32'],
  latestHandshakeAt,
  transferRx: 0,
  transferTx: 0,
});

interface DeviceRow {
  id: string;
  nodeId: string;
  publicKey: string;
  lastSeenAt: Date | null;
  revokedAt?: Date | null;
}

interface HarnessOptions {
  nodes?: { id: string; name: string }[];
  devices: DeviceRow[];
  /** Peers per node id; a node absent from the map throws, as an unreachable one does. */
  peers: Record<string, WgPeer[] | Error>;
}

function harness(options: HarnessOptions) {
  const nodes = options.nodes ?? [{ id: 'n1', name: 'Mumbai #1' }];
  const rows = options.devices.map((row) => ({ ...row }));
  const writes: { id: string; lastSeenAt: Date }[] = [];

  const prisma = {
    node: { findMany: async () => nodes },
    device: {
      findMany: async ({
        where,
      }: {
        where: { nodeId: string; publicKey: { in: string[] } };
      }) =>
        rows.filter(
          (row) =>
            row.nodeId === where.nodeId &&
            !row.revokedAt &&
            where.publicKey.in.includes(row.publicKey),
        ),
      update: async ({
        where,
        data,
      }: {
        where: { id: string };
        data: { lastSeenAt: Date };
      }) => {
        writes.push({ id: where.id, lastSeenAt: data.lastSeenAt });
        const row = rows.find((candidate) => candidate.id === where.id);
        if (row) row.lastSeenAt = data.lastSeenAt;
        return row;
      },
    },
  } as unknown as PrismaService;

  const wg = {
    listPeers: async (node: Pick<Node, 'id'>) => {
      const result = options.peers[node.id];
      if (result instanceof Error) throw result;
      return result ?? [];
    },
  } as unknown as WireguardService;

  const config = { lastSeenPollSeconds: 0 } as AppConfig;
  // The real one: it holds no dependencies and its thresholds are part of what
  // the sweep is for, so a stub would only be able to check that it was called.
  const health = new NodeHealthService();

  return { service: new LastSeenService(prisma, wg, config, health), writes, health };
}

describe('LastSeenService', () => {
  it('writes the handshake of a peer that has never been seen', async () => {
    const { service, writes } = harness({
      devices: [{ id: 'd1', nodeId: 'n1', publicKey: 'k1', lastSeenAt: null }],
      peers: { n1: [peer('k1', NOW)] },
    });

    await expect(service.sweep()).resolves.toEqual({ swept: 1, failed: 0, updated: 1 });
    expect(writes).toEqual([{ id: 'd1', lastSeenAt: NOW }]);
  });

  it('never moves a timestamp backwards', async () => {
    // A node rebuilt from its config reports old or absent handshakes. Writing
    // those would tell the user a live device went quiet an hour ago.
    const { service, writes } = harness({
      devices: [{ id: 'd1', nodeId: 'n1', publicKey: 'k1', lastSeenAt: NOW }],
      peers: { n1: [peer('k1', HOUR_AGO)] },
    });

    await expect(service.sweep()).resolves.toMatchObject({ updated: 0 });
    expect(writes).toEqual([]);
  });

  it('ignores a peer that has never handshaked', async () => {
    const { service, writes } = harness({
      devices: [{ id: 'd1', nodeId: 'n1', publicKey: 'k1', lastSeenAt: null }],
      peers: { n1: [peer('k1', null)] },
    });

    await expect(service.sweep()).resolves.toMatchObject({ updated: 0 });
    expect(writes).toEqual([]);
  });

  it('does not credit a device on another node with the same key', async () => {
    // A stale peer left on one interface must not write a timestamp for the
    // device that key actually belongs to somewhere else.
    const { service, writes } = harness({
      nodes: [{ id: 'n1', name: 'Mumbai #1' }],
      devices: [{ id: 'd1', nodeId: 'n2', publicKey: 'k1', lastSeenAt: null }],
      peers: { n1: [peer('k1', NOW)] },
    });

    await expect(service.sweep()).resolves.toMatchObject({ updated: 0 });
    expect(writes).toEqual([]);
  });

  it('skips a revoked device', async () => {
    const { service, writes } = harness({
      devices: [
        { id: 'd1', nodeId: 'n1', publicKey: 'k1', lastSeenAt: null, revokedAt: HOUR_AGO },
      ],
      peers: { n1: [peer('k1', NOW)] },
    });

    await expect(service.sweep()).resolves.toMatchObject({ updated: 0 });
    expect(writes).toEqual([]);
  });

  it('keeps sweeping the fleet when one node is unreachable', async () => {
    const { service, writes, health } = harness({
      nodes: [
        { id: 'n1', name: 'Mumbai #1' },
        { id: 'n2', name: 'Frankfurt #1' },
      ],
      devices: [{ id: 'd2', nodeId: 'n2', publicKey: 'k2', lastSeenAt: null }],
      peers: {
        n1: new Error('agent unreachable'),
        n2: [peer('k2', NOW)],
      },
    });

    await expect(service.sweep()).resolves.toEqual({ swept: 1, failed: 1, updated: 1 });
    expect(writes).toEqual([{ id: 'd2', lastSeenAt: NOW }]);

    // The sweep is also the fleet's health probe. One failure is a bad minute,
    // not an outage, so the node stays in selection for now.
    expect(health.get('n1')?.failures).toBe(1);
    expect(health.isHealthy('n1')).toBe(true);
    expect(health.isHealthy('n2')).toBe(true);
  });

  it('takes a node out of selection once it stops answering', async () => {
    const { service, health } = harness({
      devices: [],
      peers: { n1: new Error('agent unreachable') },
    });

    for (let attempt = 0; attempt < NodeHealthService.FAILURES_BEFORE_UNHEALTHY; attempt++) {
      await service.sweep();
    }

    expect(health.isHealthy('n1')).toBe(false);
    expect(health.get('n1')?.lastError).toContain('agent unreachable');
  });
});
