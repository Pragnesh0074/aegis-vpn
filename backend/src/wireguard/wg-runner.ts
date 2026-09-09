/** One WireGuard peer as reported by, or applied to, the interface. */
export interface WgPeer {
  publicKey: string;
  allowedIps: string[];
  latestHandshakeAt: Date | null;
  transferRx: number;
  transferTx: number;
}

export interface WgPeerSpec {
  publicKey: string;
  allowedIps: string[];
}

/**
 * Port over peer manipulation on a WireGuard interface.
 *
 * Exists so the control-plane logic (allocation, reconciliation, HTTP) can be built
 * and tested on a machine without WireGuard — macOS has no `wg` and no kernel module.
 * `ExecWgRunner` is the real one; `FakeWgRunner` is for local development only and
 * `env.validation.ts` refuses to boot with it in production.
 */
export interface WgRunner {
  addPeer(spec: WgPeerSpec): Promise<void>;
  removePeer(publicKey: string): Promise<void>;
  listPeers(): Promise<WgPeer[]>;
  /** Writes the running config to disk so peers survive a reboot. */
  persist(): Promise<void>;
  readonly kind: 'exec' | 'fake';
}

export const WG_RUNNER = Symbol('WG_RUNNER');
