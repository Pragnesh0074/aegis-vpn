/**
 * Everything a client needs to build its WireGuard config, except the private key —
 * which it already holds and must never transmit.
 */
export interface DeviceConfigResponse {
  deviceId: string;
  name: string;
  platform: string;
  createdAt: Date;

  /** The client's own `[Interface] Address`. Always a /32. */
  tunnelIp: string;
  /** Resolver inside the tunnel, so DNS never leaves the node. */
  dns: string;
  /**
   * Which of the node's two resolvers `dns` points at, and whether this node offers
   * a choice at all. Both are on the node; the difference is only the blocklist.
   */
  adBlocking: { enabled: boolean; supported: boolean };
  mtu: number;

  node: { id: string; name: string; region: string };

  peer: {
    publicKey: string;
    endpoint: string;
    allowedIps: string;
    /**
     * Mandatory for mobile: carrier NAT drops an idle tunnel after ~30-60s and
     * reconnects look broken without a keepalive.
     */
    persistentKeepalive: number;
  };
}

export interface DeviceSummary {
  id: string;
  name: string;
  platform: string;
  tunnelIp: string;
  createdAt: Date;
  lastSeenAt: Date | null;
  node: { id: string; name: string; region: string };
}
