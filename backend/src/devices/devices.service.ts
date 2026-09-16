import {
  ConflictException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, type Device, type Node } from '@prisma/client';
import { AppConfig } from '../config/configuration';
import { NodesService } from '../nodes/nodes.service';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { WireguardService } from '../wireguard/wireguard.service';
import type { DeviceConfigResponse, DeviceSummary } from './device.response';
import { canToggleAdBlocking, resolverFor, type AdBlockSubject } from './dns-policy';
import type { CreateDeviceDto } from './dto/create-device.dto';

/** Full-tunnel routing. IPv6 is included so it is blackholed rather than leaking. */
const ALLOWED_IPS = '0.0.0.0/0, ::/0';
const PERSISTENT_KEEPALIVE = 25;

/**
 * Attempts at allocating a tunnel IP before giving up.
 *
 * The allocator reads the used set and picks the lowest free address, so two
 * concurrent requests can choose the same one. The database's
 * `@@unique([nodeId, tunnelIpV4])` constraint is what actually prevents a
 * double-assignment; this retry is how a loser recovers.
 */
const ALLOCATION_ATTEMPTS = 5;

const NODE_SELECT = { select: { id: true, name: true, region: true } } as const;

@Injectable()
export class DevicesService {
  private readonly logger = new Logger(DevicesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly nodes: NodesService,
    private readonly wg: WireguardService,
    private readonly config: AppConfig,
  ) {}

  async issue(userId: string, dto: CreateDeviceDto): Promise<DeviceConfigResponse> {
    if (!(await this.users.hasDeviceCapacity(userId))) {
      throw new ConflictException(
        `Device limit reached (${this.config.maxDevicesPerUser}). ` +
          `Remove an existing device before adding another.`,
      );
    }

    const node = dto.nodeId
      ? await this.nodes.findActiveOrThrow(dto.nodeId)
      : await this.nodes.selectLeastLoaded();

    const device = await this.insertWithRetry(userId, node, dto);

    // The row exists but the interface does not know about the peer yet. If applying
    // fails, the row must go — otherwise the database claims a tunnel IP that wg0 has
    // never heard of, and the client gets a config that silently cannot connect.
    try {
      await this.wg.applyPeer(device, node);
    } catch (error) {
      await this.prisma.device
        .delete({ where: { id: device.id } })
        .catch((cleanupError: unknown) => {
          // Reconciliation converges on the database, so a stranded row would get a
          // peer created on the next boot. Loud log, and the address stays reserved.
          this.logger.error(
            `Failed to roll back device ${device.id} after applyPeer error: ` +
              `${cleanupError instanceof Error ? cleanupError.message : String(cleanupError)}`,
          );
        });
      throw error;
    }

    this.logger.log(
      `Issued peer ${device.tunnelIpV4} on ${node.name} for user ${userId} (device ${device.id})`,
    );

    return this.toConfig(device, node, await this.users.adBlockSubject(userId));
  }

  /**
   * The full config for a device the caller already owns.
   *
   * The client caches its config at issuance, so without this there is no way to pick
   * up a resolver change — which is how a fleet ends up with devices still pointed at
   * whatever DNS was current the day they were created. The private key is not here
   * and never was: the client holds the only copy.
   */
  async getConfig(userId: string, deviceId: string): Promise<DeviceConfigResponse> {
    const device = await this.prisma.device.findFirst({
      where: { id: deviceId, userId, revokedAt: null },
      include: { node: true },
    });
    if (!device) throw new NotFoundException('Device not found');

    return this.toConfig(device, device.node, await this.users.adBlockSubject(userId));
  }

  /**
   * Allocates an address and inserts the device, retrying when a concurrent request
   * took the same address.
   *
   * A P2002 on `publicKey` is NOT retryable — the same key would collide forever — so
   * the two constraint violations are told apart by the error's `meta.target`.
   */
  private async insertWithRetry(userId: string, node: Node, dto: CreateDeviceDto): Promise<Device> {
    for (let attempt = 1; attempt <= ALLOCATION_ATTEMPTS; attempt++) {
      const tunnelIpV4 = await this.wg.allocateIp(node);

      try {
        return await this.prisma.device.create({
          data: {
            userId,
            nodeId: node.id,
            name: dto.name.trim(),
            platform: dto.platform,
            publicKey: dto.publicKey,
            tunnelIpV4,
          },
        });
      } catch (error) {
        if (!(error instanceof Prisma.PrismaClientKnownRequestError) || error.code !== 'P2002') {
          throw error;
        }

        const fields = DevicesService.conflictFields(error);

        if (fields.includes('publicKey')) {
          throw new ConflictException('This device key is already registered');
        }

        if (!fields.includes('tunnelIpV4')) {
          throw error; // an unexpected unique constraint — do not silently retry
        }

        this.logger.warn(
          `Tunnel IP ${tunnelIpV4} was taken concurrently on ${node.name}; ` +
            `retry ${attempt}/${ALLOCATION_ATTEMPTS}`,
        );
      }
    }

    throw new InternalServerErrorException('Could not allocate a tunnel address; please try again');
  }

  /** Prisma reports the violated fields in `meta.target`, as an array or a string. */
  private static conflictFields(error: Prisma.PrismaClientKnownRequestError): string[] {
    const target = (error.meta as { target?: string[] | string } | undefined)?.target;
    if (Array.isArray(target)) return target;
    if (typeof target === 'string') return [target];
    return [];
  }

  async listForUser(userId: string): Promise<DeviceSummary[]> {
    const devices = await this.prisma.device.findMany({
      where: { userId, revokedAt: null },
      orderBy: { createdAt: 'asc' },
      include: { node: NODE_SELECT },
    });

    return devices.map((device) => ({
      id: device.id,
      name: device.name,
      platform: device.platform,
      tunnelIp: `${device.tunnelIpV4}/32`,
      createdAt: device.createdAt,
      lastSeenAt: device.lastSeenAt,
      node: device.node,
    }));
  }

  /**
   * Revokes a device.
   *
   * The database is marked first, then the peer is removed. That order matters:
   * `reconcile()` converges the interface onto the database, so a crash between the
   * two steps self-heals in the safe direction (the peer gets removed on the next
   * reconcile). Removing the peer first and then failing the write would leave the
   * database advertising an active device whose peer reconciliation would recreate.
   *
   * The tunnel IP is deliberately not freed — see the soft-delete decision.
   */
  async revoke(userId: string, deviceId: string): Promise<void> {
    // The node comes along because removing a peer means knowing which interface
    // holds it — a public key alone does not say, and removing it from the wrong
    // node would report success while the revoked device kept carrying traffic.
    const device = await this.prisma.device.findFirst({
      where: { id: deviceId, userId },
      include: { node: true },
    });

    // Scoped by userId, so another user's device is indistinguishable from a
    // nonexistent one.
    if (!device) throw new NotFoundException('Device not found');
    if (device.revokedAt) return; // idempotent

    await this.prisma.device.update({
      where: { id: device.id },
      data: { revokedAt: new Date() },
    });

    await this.wg.revokePeer(device.publicKey, device.node);

    this.logger.log(`Revoked device ${device.id} (${device.tunnelIpV4}) for user ${userId}`);
  }

  private toConfig(device: Device, node: Node, subject: AdBlockSubject): DeviceConfigResponse {
    // Resolved once: calling resolverFor twice could straddle a grant expiring
    // between the two calls and report an address that disagrees with the flag.
    const resolver = resolverFor(subject, node);
    return {
      deviceId: device.id,
      name: device.name,
      platform: device.platform,
      createdAt: device.createdAt,
      tunnelIp: `${device.tunnelIpV4}/32`,
      dns: resolver,
      adBlocking: {
        enabled: resolver === node.dns,
        // False on a node with only the one resolver, so the client can explain why
        // the switch is unavailable rather than appearing to ignore it.
        supported: canToggleAdBlocking(node),
      },
      mtu: node.mtu,
      node: { id: node.id, name: node.name, region: node.region },
      peer: {
        publicKey: node.publicKey,
        endpoint: node.endpoint,
        allowedIps: ALLOWED_IPS,
        persistentKeepalive: PERSISTENT_KEEPALIVE,
      },
    };
  }
}
