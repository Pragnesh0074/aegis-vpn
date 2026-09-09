import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { AppConfig } from '../../config/configuration';
import type { WgPeer, WgPeerSpec, WgRunner } from '../wg-runner';
import { assertValidPublicKey } from '../wg-validation';

const run = promisify(execFile);

/** `wg` and `wg-quick` need root; the sudoers rule in docs/DEPLOY.md scopes this narrowly. */
const SUDO = '/usr/bin/sudo';

const TIMEOUT_MS = 10_000;

/**
 * Drives the real `wg` binary.
 *
 * Every call uses `execFile` with an argv array — no shell is spawned, so shell
 * metacharacters in an argument are inert rather than interpreted. `publicKey` is
 * attacker-controlled (clients upload it), which is exactly why `exec` with an
 * interpolated string must never appear in this file.
 *
 * Arguments are validated anyway. `execFile` already makes injection structurally
 * impossible; validation stops malformed input from corrupting the interface config.
 */
@Injectable()
export class ExecWgRunner implements WgRunner {
  readonly kind = 'exec' as const;
  private readonly logger = new Logger(ExecWgRunner.name);

  constructor(private readonly config: AppConfig) {}

  private get iface(): string {
    // Already regex-validated at boot by env.validation.ts.
    return this.config.wgInterface;
  }

  private async wg(args: string[]): Promise<string> {
    try {
      const { stdout } = await run(SUDO, [this.config.wgBinary, ...args], {
        timeout: TIMEOUT_MS,
      });
      return stdout;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      // Log the command shape but not a full argv dump; peer keys are not secrets,
      // yet there is no reason to scatter them through the logs either.
      this.logger.error(`wg ${args[0]} ${args[1] ?? ''} failed: ${message}`);
      throw new InternalServerErrorException('Failed to update the VPN interface');
    }
  }

  async addPeer(spec: WgPeerSpec): Promise<void> {
    assertValidPublicKey(spec.publicKey);
    const allowedIps = spec.allowedIps.join(',');
    if (!/^[0-9./,:a-fA-F]+$/.test(allowedIps)) {
      throw new InternalServerErrorException('Invalid allowed-ips');
    }
    await this.wg(['set', this.iface, 'peer', spec.publicKey, 'allowed-ips', allowedIps]);
  }

  async removePeer(publicKey: string): Promise<void> {
    assertValidPublicKey(publicKey);
    await this.wg(['set', this.iface, 'peer', publicKey, 'remove']);
  }

  /**
   * Parses `wg show <iface> dump`.
   *
   * Format is tab-separated. The FIRST line describes the interface itself
   * (private key, public key, listen port, fwmark) and must be skipped — treating it
   * as a peer would invent a phantom peer on every reconcile.
   *
   * Peer lines: publicKey, presharedKey, endpoint, allowedIps,
   *             latestHandshake (unix seconds, 0 = never), rx, tx, keepalive
   */
  async listPeers(): Promise<WgPeer[]> {
    const stdout = await this.wg(['show', this.iface, 'dump']);
    const lines = stdout.trim().split('\n').filter(Boolean);

    return lines.slice(1).map((line) => {
      const f = line.split('\t');
      const handshake = Number(f[4] ?? 0);
      return {
        publicKey: f[0],
        allowedIps: (f[3] ?? '').split(',').filter((ip) => ip && ip !== '(none)'),
        latestHandshakeAt: handshake > 0 ? new Date(handshake * 1000) : null,
        transferRx: Number(f[5] ?? 0),
        transferTx: Number(f[6] ?? 0),
      };
    });
  }

  /**
   * `wg-quick save` rewrites /etc/wireguard/<iface>.conf from the live interface, so
   * peers survive a reboot. Reconciliation on boot makes this belt-and-braces rather
   * than load-bearing — but without it a reboot before the API starts drops every peer.
   */
  async persist(): Promise<void> {
    try {
      await run(SUDO, [this.config.wgQuickBinary, 'save', this.iface], { timeout: TIMEOUT_MS });
    } catch (error) {
      // Non-fatal: the peer is live in the kernel. Postgres remains the source of
      // truth and boot reconciliation will restore it, so do not fail the request.
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`wg-quick save failed (peer is live but not persisted): ${message}`);
    }
  }
}
