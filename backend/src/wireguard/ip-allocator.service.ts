import { ConflictException, Injectable } from '@nestjs/common';
import type { Node } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { intToIp, ipToInt, parseSubnet } from './wg-validation';

@Injectable()
export class IpAllocatorService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Picks the lowest free tunnel IP in the node's subnet.
   *
   * This is advisory only. Two concurrent requests can both read the same set of used
   * addresses and pick the same IP — the authoritative guard is the
   * `@@unique([nodeId, tunnelIpV4])` constraint on `devices`, which makes the second
   * insert fail with P2002. Callers must catch that and retry (see
   * `WireguardService.issuePeer`), not assume this returns an uncontested address.
   *
   * Revoked devices still occupy their address: recycling one immediately would let a
   * new device inherit traffic aimed at a stale client that has not yet noticed its
   * peer is gone.
   */
  async nextFreeIp(node: Node): Promise<string> {
    const { firstHost, lastHost } = parseSubnet(node.subnetV4);

    const taken = await this.prisma.device.findMany({
      where: { nodeId: node.id },
      select: { tunnelIpV4: true },
    });

    const used = new Set<number>();
    for (const row of taken) {
      try {
        used.add(ipToInt(row.tunnelIpV4));
      } catch {
        // A malformed stored address must not stop allocation; skipping it is safe
        // because it also cannot collide with a well-formed candidate.
      }
    }

    // maxPeers can be smaller than the subnet, so it caps the range independently.
    const capacityLimit = Math.min(lastHost, firstHost + node.maxPeers - 1);

    for (let candidate = firstHost; candidate <= capacityLimit; candidate++) {
      if (!used.has(candidate)) return intToIp(candidate);
    }

    throw new ConflictException(
      `Node ${node.name} has no free tunnel addresses (capacity ${node.maxPeers})`,
    );
  }
}
