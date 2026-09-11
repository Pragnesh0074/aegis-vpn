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
  readonly kind: 'exec' | 'fake' | 'http';
}

/** The runner for the interface on *this* host. See `WgRunnerRegistry`. */
export const WG_RUNNER = Symbol('WG_RUNNER');

/**
 * What `ExecWgRunner` needs to drive `wg`, and nothing else.
 *
 * Narrower than `AppConfig` on purpose: the node agent runs the same runner
 * without a database URL or a JWT secret anywhere in its environment, and it
 * could not do that if the runner demanded the API's whole config object.
 */
export interface WgExecOptions {
  /** Interface name, already regex-validated — this value reaches an argv array. */
  interfaceName: string;
  binary: string;
  quickBinary: string;
}

export const WG_EXEC_OPTIONS = Symbol('WG_EXEC_OPTIONS');
