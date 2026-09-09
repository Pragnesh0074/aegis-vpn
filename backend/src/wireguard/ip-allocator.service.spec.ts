import type { Node } from '@prisma/client';
import type { PrismaService } from '../prisma/prisma.service';
import { IpAllocatorService } from './ip-allocator.service';

const node = (overrides: Partial<Node> = {}): Node =>
  ({
    id: 'n1',
    name: 'Mumbai #1',
    subnetV4: '10.7.0.0/24',
    maxPeers: 250,
    ...overrides,
  }) as Node;

/** Only `device.findMany` is used by the allocator. */
const prismaWith = (taken: string[]): PrismaService =>
  ({
    device: { findMany: async () => taken.map((tunnelIpV4) => ({ tunnelIpV4 })) },
  }) as unknown as PrismaService;

const allocator = (taken: string[]) => new IpAllocatorService(prismaWith(taken));

describe('IpAllocatorService', () => {
  it('assigns .2 on an empty node', async () => {
    await expect(allocator([]).nextFreeIp(node())).resolves.toBe('10.7.0.2');
  });

  it('assigns the next address in sequence', async () => {
    await expect(allocator(['10.7.0.2', '10.7.0.3']).nextFreeIp(node())).resolves.toBe('10.7.0.4');
  });

  it('fills a gap left by a removed device', async () => {
    await expect(allocator(['10.7.0.2', '10.7.0.4']).nextFreeIp(node())).resolves.toBe('10.7.0.3');
  });

  it('ignores order in the stored rows', async () => {
    await expect(allocator(['10.7.0.5', '10.7.0.2']).nextFreeIp(node())).resolves.toBe('10.7.0.3');
  });

  // A malformed stored address cannot collide with a well-formed candidate, so
  // skipping it is safe and better than failing every allocation on the node.
  it('skips a malformed stored address', async () => {
    await expect(allocator(['10.7.0.2', 'not-an-ip']).nextFreeIp(node())).resolves.toBe('10.7.0.3');
  });

  describe('capacity', () => {
    it('honours maxPeers below the subnet size', async () => {
      const small = node({ maxPeers: 3 });
      await expect(allocator(['10.7.0.2', '10.7.0.3']).nextFreeIp(small)).resolves.toBe('10.7.0.4');
      await expect(
        allocator(['10.7.0.2', '10.7.0.3', '10.7.0.4']).nextFreeIp(small),
      ).rejects.toThrow(/no free tunnel addresses/);
    });

    it('reports the node name and capacity when full', async () => {
      await expect(allocator(['10.7.0.2']).nextFreeIp(node({ maxPeers: 1 }))).rejects.toThrow(
        /Mumbai #1.*capacity 1/,
      );
    });

    it('stops at the subnet boundary when maxPeers exceeds it', async () => {
      const taken = Array.from({ length: 253 }, (_, i) => `10.7.0.${i + 2}`); // .2-.254
      await expect(allocator(taken).nextFreeIp(node({ maxPeers: 1000 }))).rejects.toThrow();
    });
  });

  // Revoked rows are intentionally still in the used set: recycling an address
  // immediately would let a new device inherit traffic aimed at a stale client.
  it('counts revoked devices as still occupying their address', async () => {
    const prisma = {
      device: {
        findMany: jest.fn(async () => [{ tunnelIpV4: '10.7.0.2' }]),
      },
    } as unknown as PrismaService;

    await expect(new IpAllocatorService(prisma).nextFreeIp(node())).resolves.toBe('10.7.0.3');
    // No revokedAt filter — every row on the node counts.
    expect((prisma.device.findMany as jest.Mock).mock.calls[0][0].where).toEqual({ nodeId: 'n1' });
  });
});
