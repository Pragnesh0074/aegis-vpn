import { Injectable, Logger } from '@nestjs/common';
import type { WgPeer, WgPeerSpec, WgRunner } from '../wg-runner';
import { assertValidPublicKey } from '../wg-validation';

/**
 * In-memory stand-in for `wg`, for development on machines without WireGuard.
 *
 * Applies the same validation as the real runner so a bad public key fails in dev
 * exactly as it would in production. Peers live only for the process lifetime.
 *
 * `env.validation.ts` rejects `WG_RUNNER=fake` when `NODE_ENV=production`: the API
 * would otherwise confirm peer creation over HTTP while never touching wg0, handing
 * every client a config that silently cannot connect.
 */
@Injectable()
export class FakeWgRunner implements WgRunner {
  readonly kind = 'fake' as const;
  private readonly logger = new Logger(FakeWgRunner.name);
  private readonly peers = new Map<string, WgPeer>();

  async addPeer(spec: WgPeerSpec): Promise<void> {
    assertValidPublicKey(spec.publicKey);
    this.peers.set(spec.publicKey, {
      publicKey: spec.publicKey,
      allowedIps: spec.allowedIps,
      latestHandshakeAt: null,
      transferRx: 0,
      transferTx: 0,
    });
    this.logger.debug(`[fake] added peer ${spec.publicKey.slice(0, 8)}… -> ${spec.allowedIps}`);
  }

  async removePeer(publicKey: string): Promise<void> {
    assertValidPublicKey(publicKey);
    this.peers.delete(publicKey);
    this.logger.debug(`[fake] removed peer ${publicKey.slice(0, 8)}…`);
  }

  async listPeers(): Promise<WgPeer[]> {
    return [...this.peers.values()];
  }

  async persist(): Promise<void> {
    // Nothing to persist.
  }
}
