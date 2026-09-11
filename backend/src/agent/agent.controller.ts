import { BadRequestException, Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { Inject } from '@nestjs/common';
import { WG_RUNNER, type WgPeer, type WgRunner } from '../wireguard/wg-runner';
import { assertValidPublicKey } from '../wireguard/wg-validation';
import { AgentTokenGuard } from './agent-token.guard';

/** The wire shape of a peer, with the handshake as an ISO string. */
interface PeerJson {
  publicKey: string;
  allowedIps: string[];
  latestHandshakeAt: string | null;
  transferRx: number;
  transferTx: number;
}

/**
 * The node-agent's entire API: the four operations `WgRunner` declares.
 *
 * `HttpWgRunner` on the API side is the only client. Keeping the surface identical
 * to the port is what lets the API treat a remote node exactly like a local one.
 */
@Controller()
@UseGuards(AgentTokenGuard)
export class AgentController {
  constructor(@Inject(WG_RUNNER) private readonly runner: WgRunner) {}

  @Post('peers')
  async addPeer(
    @Body() body: { publicKey?: unknown; allowedIps?: unknown },
  ): Promise<{ ok: true }> {
    const publicKey = requireKey(body?.publicKey);
    const allowedIps = requireAllowedIps(body?.allowedIps);

    await this.runner.addPeer({ publicKey, allowedIps });
    return { ok: true };
  }

  /**
   * Removal takes the key in a body rather than a path segment.
   *
   * A WireGuard public key is base64 and routinely contains `/`, `+` and `=`.
   * Path-encoding those is exactly what a proxy in front of this agent gets subtly
   * wrong, and the failure mode is a revoked peer that stays live.
   */
  @Post('peers/remove')
  async removePeer(@Body() body: { publicKey?: unknown }): Promise<{ ok: true }> {
    await this.runner.removePeer(requireKey(body?.publicKey));
    return { ok: true };
  }

  @Get('peers')
  async listPeers(): Promise<{ peers: PeerJson[] }> {
    const peers = await this.runner.listPeers();
    return { peers: peers.map(toJson) };
  }

  @Post('persist')
  async persist(): Promise<{ ok: true }> {
    await this.runner.persist();
    return { ok: true };
  }
}

function toJson(peer: WgPeer): PeerJson {
  return {
    publicKey: peer.publicKey,
    allowedIps: peer.allowedIps,
    latestHandshakeAt: peer.latestHandshakeAt?.toISOString() ?? null,
    transferRx: peer.transferRx,
    transferTx: peer.transferTx,
  };
}

/**
 * Validates with the same helper the runner uses.
 *
 * The runner asserts again before the value reaches an argv array — this is here so
 * a malformed key is a 400 the API can read, rather than a 500 from deeper down.
 */
function requireKey(value: unknown): string {
  if (typeof value !== 'string') throw new BadRequestException('publicKey is required');
  assertValidPublicKey(value);
  return value;
}

function requireAllowedIps(value: unknown): string[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new BadRequestException('allowedIps must be a non-empty array');
  }
  if (!value.every((ip) => typeof ip === 'string')) {
    throw new BadRequestException('allowedIps must be strings');
  }
  return value as string[];
}
