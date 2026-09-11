import { z } from 'zod';

/** Linux network interface names: max 15 chars, and this value reaches an argv array. */
const IFACE = /^[A-Za-z0-9_-]{1,15}$/;

/**
 * The agent's entire environment.
 *
 * Deliberately not the API's schema. An exit node has no business holding a
 * `DATABASE_URL` or a JWT signing secret, and the strongest way to guarantee that
 * is for the process to have no way to read one: compromising a node yields control
 * of that node's WireGuard interface and nothing else. This is the whole reason the
 * design is an agent rather than "run the API on every node".
 */
export const agentEnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('production'),

  AGENT_PORT: z.coerce.number().int().min(1).max(65535).default(8787),

  /**
   * Bind address. Loopback by default: the agent is reached over a private network
   * or through a TLS proxy, and an agent listening on 0.0.0.0 with a guessable
   * token is a remote root-adjacent surface on a machine whose whole job is to be
   * publicly reachable on UDP.
   */
  AGENT_BIND: z.string().default('127.0.0.1'),

  /**
   * Shared with the API through the node's `agentToken` column. Long because it is
   * the only thing standing between the internet and `wg set`.
   */
  WG_AGENT_TOKEN: z.string().min(32, 'WG_AGENT_TOKEN must be >= 32 chars'),

  WG_INTERFACE: z.string().regex(IFACE, 'invalid interface name').default('wg0'),
  WG_BINARY: z.string().default('/usr/bin/wg'),
  WG_QUICK_BINARY: z.string().default('/usr/bin/wg-quick'),
});

export type AgentEnv = z.infer<typeof agentEnvSchema>;

/** Validate at boot and fail loudly, exactly as the API does. */
export function validateAgentEnv(raw: Record<string, unknown>): AgentEnv {
  const result = agentEnvSchema.safeParse(raw);
  if (result.success) return result.data;

  const details = result.error.issues
    .map((i) => `  - ${i.path.join('.') || '(root)'}: ${i.message}`)
    .join('\n');
  throw new Error(`Invalid node-agent environment:\n${details}`);
}
