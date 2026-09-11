import { randomBytes } from 'node:crypto';
import { Prisma, type Device, type Node } from '@prisma/client';
import type { AppConfig } from '../config/configuration';
import type { NodesService } from '../nodes/nodes.service';
import type { PrismaService } from '../prisma/prisma.service';
import type { UsersService } from '../users/users.service';
import { IpAllocatorService } from '../wireguard/ip-allocator.service';
import { FakeWgRunner } from '../wireguard/runners/fake-wg.runner';
import { WgRunnerRegistry } from '../wireguard/wg-runner.registry';
import { WireguardService } from '../wireguard/wireguard.service';
import { DevicesService } from './devices.service';
import type { CreateDeviceDto } from './dto/create-device.dto';

const key = () => randomBytes(32).toString('base64');

const node = {
  id: 'n1',
  name: 'Mumbai #1',
  region: 'in-mumbai',
  subnetV4: '10.7.0.0/24',
  maxPeers: 250,
  dns: '10.7.0.1',
  mtu: 1420,
  publicKey: key(),
  endpoint: 'vpn.example.com:51820',
} as Node;

const uniqueViolation = (target: string[]) =>
  new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
    code: 'P2002',
    clientVersion: '5.22.0',
    meta: { target },
  });

const dto = (): CreateDeviceDto => ({
  publicKey: key(),
  name: 'Pixel 9',
  platform: 'android',
});

interface HarnessOptions {
  /** Called on every insert attempt; throw to simulate a constraint violation. */
  onCreate: (data: Record<string, unknown>, attempt: number) => Device;
  taken?: string[];
  hasCapacity?: boolean;
}

function harness(options: HarnessOptions) {
  const deleted: string[] = [];
  let attempts = 0;

  const prisma = {
    device: {
      findMany: async () => (options.taken ?? []).map((tunnelIpV4) => ({ tunnelIpV4 })),
      create: async ({ data }: { data: Record<string, unknown> }) => {
        attempts += 1;
        return options.onCreate(data, attempts);
      },
      delete: async ({ where }: { where: { id: string } }) => {
        deleted.push(where.id);
        return {} as Device;
      },
    },
    node: { findFirst: async () => node, findUnique: async () => node, count: async () => 1 },
  } as unknown as PrismaService;

  const config = {
    maxDevicesPerUser: 5,
    wgInterface: 'wg0',
    wgReconcileOnBoot: false,
  } as AppConfig;
  const runner = new FakeWgRunner();
  const wg = new WireguardService(
    new WgRunnerRegistry(runner, config, prisma),
    prisma,
    new IpAllocatorService(prisma),
    config,
  );

  const users = {
    hasDeviceCapacity: async () => options.hasCapacity ?? true,
  } as unknown as UsersService;

  const nodes = {
    findActiveOrThrow: async () => node,
    selectLeastLoaded: async () => node,
  } as unknown as NodesService;

  const service = new DevicesService(prisma, users, nodes, wg, config);

  return { service, runner, wg, deleted, getAttempts: () => attempts };
}

const created = (data: Record<string, unknown>, id = 'd1'): Device =>
  ({ id, createdAt: new Date(), ...data }) as Device;

describe('DevicesService.issue', () => {
  it('returns a config the client can use verbatim', async () => {
    const { service, runner } = harness({ onCreate: (data) => created(data) });

    const result = await service.issue('u1', dto());

    expect(result.tunnelIp).toBe('10.7.0.2/32');
    expect(result.dns).toBe('10.7.0.1');
    expect(result.mtu).toBe(1420);
    expect(result.peer.publicKey).toBe(node.publicKey);
    expect(result.peer.endpoint).toBe('vpn.example.com:51820');
    // ::/0 is included so IPv6 is routed into a tunnel the server does not forward,
    // blackholing it rather than leaking the real address.
    expect(result.peer.allowedIps).toBe('0.0.0.0/0, ::/0');
    // Mandatory on mobile: carrier NAT drops idle tunnels after 30-60s.
    expect(result.peer.persistentKeepalive).toBe(25);

    expect(await runner.listPeers()).toHaveLength(1);
  });

  it('applies the peer with a /32', async () => {
    const { service, runner } = harness({ onCreate: (data) => created(data) });
    await service.issue('u1', dto());
    expect((await runner.listPeers())[0].allowedIps).toEqual(['10.7.0.2/32']);
  });

  it('never returns a private key', async () => {
    const { service } = harness({ onCreate: (data) => created(data) });
    const result = await service.issue('u1', dto());
    expect(JSON.stringify(result)).not.toMatch(/privateKey/i);
  });

  describe('concurrent tunnel-IP allocation', () => {
    /**
     * The allocator reads the used set and picks the lowest free address, so two
     * requests can choose the same one. The unique constraint on
     * (nodeId, tunnelIpV4) is the authoritative guard; this retry is how the loser
     * recovers.
     */
    it('retries until the insert succeeds', async () => {
      const { service, getAttempts } = harness({
        onCreate: (data, attempt) => {
          if (attempt < 3) throw uniqueViolation(['nodeId', 'tunnelIpV4']);
          return created(data, 'd3');
        },
      });

      await expect(service.issue('u1', dto())).resolves.toMatchObject({ deviceId: 'd3' });
      expect(getAttempts()).toBe(3);
    });

    it('gives up after a bounded number of attempts', async () => {
      const { service, getAttempts } = harness({
        onCreate: () => {
          throw uniqueViolation(['nodeId', 'tunnelIpV4']);
        },
      });

      await expect(service.issue('u1', dto())).rejects.toMatchObject({ status: 500 });
      expect(getAttempts()).toBe(5);
    });
  });

  // A duplicate public key would collide on every retry, so it must fail immediately
  // rather than spinning through the allocation loop.
  it('rejects an already-registered public key without retrying', async () => {
    const { service, getAttempts } = harness({
      onCreate: () => {
        throw uniqueViolation(['publicKey']);
      },
    });

    await expect(service.issue('u1', dto())).rejects.toMatchObject({
      status: 409,
      message: expect.stringMatching(/already registered/i),
    });
    expect(getAttempts()).toBe(1);
  });

  it('rethrows an unrecognised unique constraint instead of retrying it', async () => {
    const { service, getAttempts } = harness({
      onCreate: () => {
        throw uniqueViolation(['someOtherColumn']);
      },
    });

    await expect(service.issue('u1', dto())).rejects.toMatchObject({ code: 'P2002' });
    expect(getAttempts()).toBe(1);
  });

  /**
   * Without this rollback the database would claim a tunnel IP that wg0 has never
   * heard of, and the client would receive a config that silently cannot connect.
   */
  it('deletes the row when applying the peer fails', async () => {
    const h = harness({ onCreate: (data) => created(data, 'dX') });
    jest.spyOn(h.wg, 'applyPeer').mockRejectedValue(new Error('wg set failed'));

    await expect(h.service.issue('u1', dto())).rejects.toThrow(/wg set failed/);
    expect(h.deleted).toContain('dX');
    expect(await h.runner.listPeers()).toHaveLength(0);
  });

  describe('device cap', () => {
    it('rejects once the limit is reached, before touching the database', async () => {
      const { service, getAttempts } = harness({
        hasCapacity: false,
        onCreate: (data) => created(data),
      });

      await expect(service.issue('u1', dto())).rejects.toMatchObject({
        status: 409,
        message: expect.stringMatching(/Device limit reached \(5\)/),
      });
      expect(getAttempts()).toBe(0);
    });
  });
});

describe('DevicesService.revoke', () => {
  function revokeHarness(deviceOwner: string | null) {
    const publicKey = key();
    const state: { revokedAt: Date | null } = { revokedAt: null };

    const prisma = {
      device: {
        findFirst: async ({ where }: { where: { userId: string } }) =>
          deviceOwner && where.userId === deviceOwner
            ? // `node` is included because revoking has to know which interface
              // holds the peer.
              { id: 'd1', userId: deviceOwner, publicKey, tunnelIpV4: '10.7.0.2', node, ...state }
            : null,
        update: async ({ data }: { data: { revokedAt: Date } }) => {
          state.revokedAt = data.revokedAt;
          return {} as Device;
        },
        findMany: async () => [],
      },
      node: { findFirst: async () => node, findUnique: async () => node, count: async () => 1 },
    } as unknown as PrismaService;

    const config = {
      maxDevicesPerUser: 5,
      wgInterface: 'wg0',
      wgReconcileOnBoot: false,
    } as AppConfig;
    const runner = new FakeWgRunner();
    const wg = new WireguardService(
      new WgRunnerRegistry(runner, config, prisma),
      prisma,
      new IpAllocatorService(prisma),
      config,
    );
    const service = new DevicesService(prisma, {} as UsersService, {} as NodesService, wg, config);

    return { service, runner, publicKey, state };
  }

  it('marks the database and removes the peer', async () => {
    const { service, runner, publicKey, state } = revokeHarness('u1');
    await runner.addPeer({ publicKey, allowedIps: ['10.7.0.2/32'] });

    await service.revoke('u1', 'd1');

    expect(state.revokedAt).toBeInstanceOf(Date);
    expect(await runner.listPeers()).toHaveLength(0);
  });

  it('is idempotent', async () => {
    const { service, publicKey, runner } = revokeHarness('u1');
    await runner.addPeer({ publicKey, allowedIps: ['10.7.0.2/32'] });

    await service.revoke('u1', 'd1');
    await expect(service.revoke('u1', 'd1')).resolves.toBeUndefined();
  });

  // 403 would confirm the id exists. Scoping the lookup by userId makes another
  // user's device indistinguishable from one that was never created.
  it("returns 404, not 403, for another user's device", async () => {
    const { service } = revokeHarness('owner');
    await expect(service.revoke('attacker', 'd1')).rejects.toMatchObject({ status: 404 });
  });

  it('returns 404 for a device that does not exist', async () => {
    const { service } = revokeHarness(null);
    await expect(service.revoke('u1', 'nope')).rejects.toMatchObject({ status: 404 });
  });
});
