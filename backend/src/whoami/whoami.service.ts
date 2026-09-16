import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { subnetContains } from '../wireguard/wg-validation';

/** The node an address was recognised as, trimmed to what a client may see. */
export interface WhoamiNode {
  id: string;
  name: string;
  region: string;
}

export interface WhoamiResponse {
  /** The source address this request actually arrived from. */
  ip: string;
  /**
   * True only when [ip] is an address the fleet owns. False means the request
   * reached the API from somewhere else — which, if the client believes it is
   * connected, is a leak.
   */
  viaTunnel: boolean;
  /** Which node [ip] belongs to, or null when it belongs to none of them. */
  node: WhoamiNode | null;
  checkedAt: string;
}

/** One node's addresses, flattened for matching. */
interface NodeAddresses {
  node: WhoamiNode;
  /** The public address clients hand to WireGuard, without its port. */
  endpointIp: string | null;
  /** The node's tunnel network, e.g. `10.9.0.0/24`. */
  subnetV4: string;
}

/**
 * How long the fleet's address table is reused for.
 *
 * `/whoami` is unauthenticated, so a database read per call would let anyone
 * amplify a trivial request into one. Node addresses change when an operator
 * edits a row, which is rare enough that half a minute of staleness costs
 * nothing.
 */
const ADDRESS_CACHE_MS = 30_000;

/**
 * Answers "where does the internet think I am?" by comparing the request's own
 * source address against the fleet's.
 *
 * This is the only check the app can make that is not self-reported. Everything
 * else on the connect screen — the interface state, the handshake counters — is
 * the client describing itself. Here the client asks a third party what address
 * its packets arrived from, and a full-tunnel config means that address is the
 * exit node's or the traffic is not in the tunnel.
 *
 * Two addresses count as "in the tunnel", for different paths:
 *
 * - the node's **endpoint IP**, which is what a client behind a node exits as
 *   once that node has SNATed it, and
 * - the node's **tunnel subnet**, which is what the API sees when the client is
 *   on the very node the API runs on. There is no NAT on that path: the packet
 *   arrives from `10.8.0.x` directly.
 *
 * The one false negative worth naming: a node whose egress address differs from
 * its endpoint address — anything behind a separate NAT gateway — is tunnelled
 * but unrecognised. That errs towards warning a protected user rather than
 * reassuring an exposed one, which is the right direction for this check, and it
 * is fixed by making the node row's endpoint match the address it egresses as.
 */
@Injectable()
export class WhoamiService {
  private readonly logger = new Logger(WhoamiService.name);

  private cache: NodeAddresses[] | null = null;
  private cachedAt = 0;

  constructor(private readonly prisma: PrismaService) {}

  async check(rawIp: string | undefined): Promise<WhoamiResponse> {
    const ip = normaliseIp(rawIp);
    const node = ip ? await this.match(ip) : null;

    return {
      ip: ip ?? 'unknown',
      viaTunnel: node !== null,
      node,
      checkedAt: new Date().toISOString(),
    };
  }

  private async match(ip: string): Promise<WhoamiNode | null> {
    for (const candidate of await this.addresses()) {
      if (candidate.endpointIp === ip) return candidate.node;
      if (subnetContains(ip, candidate.subnetV4)) return candidate.node;
    }
    return null;
  }

  private async addresses(): Promise<NodeAddresses[]> {
    if (this.cache && Date.now() - this.cachedAt < ADDRESS_CACHE_MS) return this.cache;

    try {
      const nodes = await this.prisma.node.findMany({
        where: { active: true },
        select: { id: true, name: true, region: true, endpoint: true, subnetV4: true },
      });

      this.cache = nodes.map((node) => ({
        node: { id: node.id, name: node.name, region: node.region },
        endpointIp: endpointIp(node.endpoint),
        subnetV4: node.subnetV4,
      }));
      this.cachedAt = Date.now();
    } catch (error) {
      // A database blip must not fail the check. Reporting the address with no
      // node attached is honest — "we could not confirm this is ours" — and a
      // stale table is better than none, so an existing one is kept.
      this.logger.warn(
        `Could not refresh the node address table: ` +
          `${error instanceof Error ? error.message : String(error)}`,
      );
      this.cache ??= [];
    }

    return this.cache;
  }
}

/**
 * The host half of a `host:port` endpoint, when it is an IP literal.
 *
 * A node may legitimately be seeded with a hostname, which cannot be compared to
 * a source address without resolving it. Resolving here would put a DNS lookup on
 * an unauthenticated path, so a hostname simply does not match — the node's
 * tunnel subnet still can.
 */
function endpointIp(endpoint: string): string | null {
  const host = endpoint.trim().split(':')[0]?.trim();
  if (!host) return null;
  return /^\d{1,3}(\.\d{1,3}){3}$/.test(host) ? host : null;
}

/**
 * Express hands back IPv4 addresses in IPv6-mapped form (`::ffff:3.71.204.118`)
 * whenever the listener is dual-stack, which it is. Unmapping is what makes the
 * comparison against a node's dotted-quad endpoint work at all.
 */
function normaliseIp(ip: string | undefined): string | null {
  if (!ip) return null;
  const trimmed = ip.trim();
  if (!trimmed) return null;
  const mapped = /^::ffff:(\d{1,3}(?:\.\d{1,3}){3})$/i.exec(trimmed);
  return mapped ? mapped[1] : trimmed;
}
