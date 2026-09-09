import { BadRequestException } from '@nestjs/common';

/**
 * WireGuard keys are 32 raw bytes in base64: 43 chars of alphabet plus one '=' pad.
 * Anchored, with no `.` or `*`, so nothing shell-significant can pass.
 */
export const WG_PUBLIC_KEY = /^[A-Za-z0-9+/]{43}=$/;

/** Dotted-quad IPv4, each octet 0-255. */
const IPV4 = /^(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$/;

/** e.g. "10.7.0.0/24" */
const CIDR = /^(.+)\/(\d{1,2})$/;

export function assertValidPublicKey(key: string): string {
  if (!WG_PUBLIC_KEY.test(key)) {
    throw new BadRequestException(
      'publicKey must be a WireGuard public key: 44 base64 characters ending in "="',
    );
  }
  return key;
}

export function ipToInt(ip: string): number {
  if (!IPV4.test(ip)) throw new Error(`Not an IPv4 address: ${ip}`);
  // >>> 0 keeps the result unsigned; a leading octet >= 128 would otherwise go negative.
  return ip.split('.').reduce((acc, octet) => (acc << 8) | Number(octet), 0) >>> 0;
}

export function intToIp(value: number): string {
  return [24, 16, 8, 0].map((shift) => (value >>> shift) & 255).join('.');
}

export interface ParsedSubnet {
  /** First address usable by a client. `.1` is the server, so this is `.2`. */
  firstHost: number;
  /** Last address usable by a client (excludes the broadcast address). */
  lastHost: number;
  networkInt: number;
  prefix: number;
}

/**
 * Parses a node's `subnetV4` into an inclusive host range.
 *
 * Excludes three addresses that must never be handed to a client: the network
 * address, `.1` (held by the server's own wg0 interface), and the broadcast address.
 */
export function parseSubnet(cidr: string): ParsedSubnet {
  const match = CIDR.exec(cidr.trim());
  if (!match) throw new Error(`Invalid CIDR: ${cidr}`);

  const [, address, prefixRaw] = match;
  const prefix = Number(prefixRaw);
  if (prefix < 8 || prefix > 30) {
    // /31 and /32 leave no usable host range; anything under /8 is not a sane tunnel net.
    throw new Error(`Unsupported prefix /${prefix} in ${cidr} (expected /8 to /30)`);
  }

  const addressInt = ipToInt(address);
  const mask = prefix === 0 ? 0 : (0xffffffff << (32 - prefix)) >>> 0;
  const networkInt = (addressInt & mask) >>> 0;
  const broadcastInt = (networkInt | (~mask >>> 0)) >>> 0;

  return {
    networkInt,
    prefix,
    firstHost: networkInt + 2, // +1 is the server
    lastHost: broadcastInt - 1,
  };
}

/** Guards a tunnel IP before it reaches an argv array or a peer's allowed-ips. */
export function assertIpInSubnet(ip: string, cidr: string): string {
  const { firstHost, lastHost } = parseSubnet(cidr);
  const value = ipToInt(ip);
  if (value < firstHost || value > lastHost) {
    throw new BadRequestException(`Tunnel IP ${ip} is outside the assignable range of ${cidr}`);
  }
  return ip;
}
