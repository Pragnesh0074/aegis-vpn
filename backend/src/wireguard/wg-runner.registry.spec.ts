import type { Node } from '@prisma/client';
import type { AppConfig } from '../config/configuration';
import type { PrismaService } from '../prisma/prisma.service';
import { FakeWgRunner } from './runners/fake-wg.runner';
import { HttpWgRunner } from './runners/http-wg.runner';
import { WgRunnerRegistry } from './wg-runner.registry';

const local = { id: 'local-node', name: 'Mumbai #1' } as Node;

const remote = {
  id: 'remote-node',
  name: 'Frankfurt #1',
  agentUrl: 'https://fra1.internal:8787',
  agentToken: 'x'.repeat(40),
} as Node;

/** A node in another country that nobody told the API how to reach. */
const unreachable = {
  id: 'remote-node',
  name: 'Frankfurt #1',
  agentUrl: null,
  agentToken: null,
} as Node;

function build(options: { wgNodeId?: string; activeNodes?: number } = {}) {
  const prisma = {
    node: { count: async () => options.activeNodes ?? 1 },
  } as unknown as PrismaService;

  const runner = new FakeWgRunner();
  const registry = new WgRunnerRegistry(
    runner,
    { wgNodeId: options.wgNodeId } as AppConfig,
    prisma,
  );
  return { registry, runner };
}

describe('WgRunnerRegistry', () => {
  it("programs this host's own node with the local runner", async () => {
    const { registry, runner } = build({ wgNodeId: local.id });

    await expect(registry.forNode(local)).resolves.toBe(runner);
  });

  it('programs any other node through its agent', async () => {
    const { registry } = build({ wgNodeId: local.id });

    await expect(registry.forNode(remote)).resolves.toBeInstanceOf(HttpWgRunner);
  });

  /**
   * The whole point of this class. Before it, a node the API could not reach was
   * silently programmed on whatever interface this host happened to have: the
   * client got a valid-looking Frankfurt config whose peer lived on Mumbai's wg0,
   * the handshake never completed, and nothing said why.
   */
  it('refuses a node it has no way to reach rather than using the wrong interface', async () => {
    const { registry, runner } = build({ wgNodeId: local.id });

    await expect(registry.forNode(unreachable)).rejects.toThrow(/no agent configured/);
    // Emphatically not the local runner.
    await expect(registry.forNode(unreachable)).rejects.toBeDefined();
    expect(await runner.listPeers()).toHaveLength(0);
  });

  it('treats a half-configured agent as unreachable', async () => {
    const { registry } = build({ wgNodeId: local.id });
    const noToken = { ...remote, agentToken: null } as Node;

    // A URL with no token would authenticate as nobody and fail per request; better
    // to refuse at resolution than to install half a fleet.
    await expect(registry.forNode(noToken)).rejects.toThrow(/no agent configured/);
  });

  it('reuses one agent client per node', async () => {
    const { registry } = build({ wgNodeId: local.id });

    const first = await registry.forNode(remote);
    expect(await registry.forNode(remote)).toBe(first);

    // Rotating a token has to take effect without restarting the API.
    registry.forget(remote.id);
    expect(await registry.forNode(remote)).not.toBe(first);
  });

  describe('when WG_NODE_ID is not set', () => {
    it('assumes the only active node is this host, so a single-node deploy still works', async () => {
      const { registry, runner } = build({ activeNodes: 1 });

      await expect(registry.forNode(local)).resolves.toBe(runner);
    });

    it('refuses to guess once a second node exists', async () => {
      // With two nodes the inference is a coin flip, and guessing wrong means
      // writing one country's peers onto another country's interface.
      const { registry } = build({ activeNodes: 2 });

      await expect(registry.forNode(local)).rejects.toThrow(/WG_NODE_ID must be set/);
      await expect(registry.forNode(remote)).rejects.toThrow(/WG_NODE_ID must be set/);
    });
  });
});
