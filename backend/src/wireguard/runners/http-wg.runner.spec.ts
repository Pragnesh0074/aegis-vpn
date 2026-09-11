import { randomBytes } from 'node:crypto';
import { HttpWgRunner } from './http-wg.runner';

const key = () => randomBytes(32).toString('base64');

const target = {
  id: 'n2',
  name: 'Frankfurt #1',
  agentUrl: 'https://fra1.internal:8787',
  agentToken: 'token-'.padEnd(40, 'x'),
};

type Call = { url: string; init: RequestInit };

function stubFetch(responder: (call: Call) => Response | Promise<Response>) {
  const calls: Call[] = [];
  global.fetch = jest.fn(async (url: unknown, init: unknown) => {
    const call = { url: String(url), init: init as RequestInit };
    calls.push(call);
    return responder(call);
  }) as unknown as typeof fetch;
  return calls;
}

const noContent = () => new Response(null, { status: 204 });

afterEach(() => jest.restoreAllMocks());

describe('HttpWgRunner', () => {
  it("authenticates every call with the node's own token", async () => {
    const calls = stubFetch(noContent);
    await new HttpWgRunner(target).addPeer({ publicKey: key(), allowedIps: ['10.8.0.2/32'] });

    const headers = calls[0].init.headers as Record<string, string>;
    expect(headers.authorization).toBe(`Bearer ${target.agentToken}`);
    expect(calls[0].url).toBe('https://fra1.internal:8787/peers');
  });

  it('trims a trailing slash rather than posting to a doubled path', async () => {
    const calls = stubFetch(noContent);
    await new HttpWgRunner({ ...target, agentUrl: 'https://fra1.internal:8787/' }).persist();

    expect(calls[0].url).toBe('https://fra1.internal:8787/persist');
  });

  /**
   * A WireGuard public key is base64 and routinely contains `/`, `+` and `=`.
   * Keeping it in a body is what stops a proxy mangling the one call whose silent
   * failure leaves a revoked peer carrying traffic.
   */
  it('removes a peer by body, never by path segment', async () => {
    const calls = stubFetch(noContent);
    const publicKey = key();

    await new HttpWgRunner(target).removePeer(publicKey);

    expect(calls[0].url).toBe('https://fra1.internal:8787/peers/remove');
    expect(JSON.parse(calls[0].init.body as string)).toEqual({ publicKey });
  });

  it('rejects a malformed key before it ever reaches the network', async () => {
    const calls = stubFetch(noContent);

    await expect(new HttpWgRunner(target).removePeer('not-a-key')).rejects.toThrow(
      /WireGuard public key/,
    );
    expect(calls).toHaveLength(0);
  });

  it('rebuilds the handshake time, which JSON flattened to a string', async () => {
    const when = new Date('2026-09-11T10:00:00.000Z');
    stubFetch(
      () =>
        new Response(
          JSON.stringify({
            peers: [
              {
                publicKey: 'k',
                allowedIps: ['10.8.0.2/32'],
                latestHandshakeAt: when.toISOString(),
                transferRx: 10,
                transferTx: 20,
              },
              { publicKey: 'never', allowedIps: [], latestHandshakeAt: null },
            ],
          }),
          { status: 200, headers: { 'content-type': 'application/json' } },
        ),
    );

    const peers = await new HttpWgRunner(target).listPeers();

    expect(peers[0].latestHandshakeAt).toEqual(when);
    expect(peers[0].transferRx).toBe(10);
    // A peer that has never handshaked stays null rather than becoming the epoch.
    expect(peers[1].latestHandshakeAt).toBeNull();
    expect(peers[1].transferRx).toBe(0);
  });

  /**
   * An unreachable agent is a 503, not a 500: the node itself may be carrying
   * traffic perfectly well and only the control path is down. `DevicesService`
   * rolls the device row back on it, so the client is never handed a config for a
   * peer that was never installed.
   */
  it('reports an unreachable agent as a retryable 503', async () => {
    stubFetch(() => {
      throw new Error('ECONNREFUSED');
    });

    await expect(new HttpWgRunner(target).persist()).rejects.toMatchObject({ status: 503 });
  });

  it("does not leak the agent's own error text to the caller", async () => {
    stubFetch(
      () =>
        new Response('wg: Unable to modify interface: Operation not permitted', {
          status: 500,
        }),
    );

    await expect(new HttpWgRunner(target).persist()).rejects.toMatchObject({
      status: 500,
      message: 'Failed to update the VPN interface',
    });
  });

  it('refuses a malformed peer list instead of inventing peers', async () => {
    stubFetch(
      () =>
        new Response(JSON.stringify({ peers: 'not-an-array' }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        }),
    );

    // Reconciliation removes every live peer it cannot account for, so a list it
    // misread would be a fleet-wide outage.
    await expect(new HttpWgRunner(target).listPeers()).rejects.toThrow(/malformed peer list/);
  });
});
