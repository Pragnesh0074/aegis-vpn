import { InternalServerErrorException, Logger, ServiceUnavailableException } from '@nestjs/common';
import type { WgPeer, WgPeerSpec, WgRunner } from '../wg-runner';
import { assertValidPublicKey } from '../wg-validation';

/** What this runner needs to reach one node's agent. */
export interface AgentTarget {
  id: string;
  name: string;
  agentUrl: string;
  agentToken: string;
}

const TIMEOUT_MS = 10_000;

/**
 * Drives a remote node's interface through its `node-agent`.
 *
 * This is the whole of what multi-region needs above the port: `ExecWgRunner` can
 * only reach the interface on the host the process is running on, so every node
 * that is not this host is programmed by asking the agent living on it.
 *
 * The agent speaks the same four operations the port declares, and runs the same
 * `ExecWgRunner` on the other side — so the parsing and validation of the one
 * security-critical value here, the client-supplied public key, is shared code
 * rather than a second implementation that can drift.
 */
export class HttpWgRunner implements WgRunner {
  readonly kind = 'http' as const;
  private readonly logger = new Logger(HttpWgRunner.name);

  constructor(private readonly target: AgentTarget) {}

  async addPeer(spec: WgPeerSpec): Promise<void> {
    assertValidPublicKey(spec.publicKey);
    await this.call('POST', '/peers', {
      publicKey: spec.publicKey,
      allowedIps: spec.allowedIps,
    });
  }

  /**
   * Removal posts the key in a body rather than putting it in the path.
   *
   * A WireGuard public key is base64 and routinely contains `/`, `+` and `=`. Path
   * encoding of those is exactly the kind of thing a proxy in front of the agent
   * gets subtly wrong, and the failure mode here is a revoked peer that stays live.
   */
  async removePeer(publicKey: string): Promise<void> {
    assertValidPublicKey(publicKey);
    await this.call('POST', '/peers/remove', { publicKey });
  }

  async listPeers(): Promise<WgPeer[]> {
    const body = await this.call('GET', '/peers');
    const peers = (body as { peers?: unknown })?.peers;
    if (!Array.isArray(peers)) {
      throw new InternalServerErrorException(
        `Agent on ${this.target.name} returned a malformed peer list`,
      );
    }
    return peers.map((raw) => this.toPeer(raw as Record<string, unknown>));
  }

  async persist(): Promise<void> {
    await this.call('POST', '/persist');
  }

  private toPeer(raw: Record<string, unknown>): WgPeer {
    // The agent serialises the handshake as an ISO string or null; JSON has no date
    // type, so it has to be rebuilt here rather than trusted as one.
    const handshake = raw.latestHandshakeAt;
    return {
      publicKey: String(raw.publicKey ?? ''),
      allowedIps: Array.isArray(raw.allowedIps) ? raw.allowedIps.map(String) : [],
      latestHandshakeAt: typeof handshake === 'string' ? new Date(handshake) : null,
      transferRx: Number(raw.transferRx ?? 0),
      transferTx: Number(raw.transferTx ?? 0),
    };
  }

  private async call(method: 'GET' | 'POST', path: string, body?: unknown): Promise<unknown> {
    const url = `${this.target.agentUrl.replace(/\/+$/, '')}${path}`;

    let response: Response;
    try {
      response = await fetch(url, {
        method,
        headers: {
          authorization: `Bearer ${this.target.agentToken}`,
          ...(body === undefined ? {} : { 'content-type': 'application/json' }),
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch (error) {
      // Unreachable agent: the node may be fine and only the control path down, so
      // this is a 503 the caller can retry, not a 500. `DevicesService` rolls the
      // device row back on it, which is what stops a client being handed a config
      // for a peer that was never installed.
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Agent on ${this.target.name} unreachable: ${message}`);
      throw new ServiceUnavailableException(
        `The node ${this.target.name} is not reachable right now`,
      );
    }

    if (!response.ok) {
      // The agent's own message is not forwarded to the client — it is another
      // service's internals — but it belongs in our logs.
      const detail = await response.text().catch(() => '');
      this.logger.error(
        `Agent on ${this.target.name} rejected ${method} ${path}: ` +
          `${response.status} ${detail.slice(0, 200)}`,
      );
      throw new InternalServerErrorException('Failed to update the VPN interface');
    }

    if (response.status === 204) return undefined;
    return response.json().catch(() => undefined);
  }
}
