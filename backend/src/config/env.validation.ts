import { z } from 'zod';

/**
 * A string env var holding a boolean. `z.coerce.boolean()` is wrong here:
 * Boolean('false') === true, so it silently turns every non-empty value into `true`.
 */
const boolFromString = (defaultValue: boolean) =>
  z
    .enum(['true', 'false', '1', '0'])
    .default(defaultValue ? 'true' : 'false')
    .transform((v) => v === 'true' || v === '1');

/** Linux network interface names: max 15 chars, and this value reaches an argv array. */
const IFACE = /^[A-Za-z0-9_-]{1,15}$/;

const PLACEHOLDER = /replace-me/i;

export const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),
    CORS_ORIGINS: z.string().default(''),

    DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),

    JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET must be >= 32 chars'),
    JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET must be >= 32 chars'),
    JWT_ACCESS_TTL: z.string().default('15m'),
    JWT_REFRESH_TTL: z.string().default('30d'),

    MAX_DEVICES_PER_USER: z.coerce.number().int().min(1).max(100).default(5),

    WG_INTERFACE: z.string().regex(IFACE, 'invalid interface name').default('wg0'),
    WG_RUNNER: z.enum(['exec', 'fake']).default('fake'),
    WG_BINARY: z.string().default('/usr/bin/wg'),
    WG_QUICK_BINARY: z.string().default('/usr/bin/wg-quick'),
    WG_RECONCILE_ON_BOOT: boolFromString(true),

    SEED_NODE_NAME: z.string().default('Mumbai #1'),
    SEED_NODE_REGION: z.string().default('in-mumbai'),
    SEED_NODE_PUBLIC_KEY: z.string().default(''),
    SEED_NODE_ENDPOINT: z.string().default(''),
    SEED_NODE_SUBNET_V4: z.string().default('10.7.0.0/24'),
    SEED_NODE_DNS: z.string().default('10.7.0.1'),
    SEED_NODE_MTU: z.coerce.number().int().min(1280).max(1500).default(1420),
  })
  .superRefine((env, ctx) => {
    if (env.JWT_ACCESS_SECRET === env.JWT_REFRESH_SECRET) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['JWT_REFRESH_SECRET'],
        message: 'JWT_REFRESH_SECRET must differ from JWT_ACCESS_SECRET',
      });
    }

    if (env.NODE_ENV !== 'production') return;

    // A fake runner in production would ACK peer creation over HTTP while never
    // touching wg0 — every client would get a config that cannot connect.
    if (env.WG_RUNNER === 'fake') {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['WG_RUNNER'],
        message: 'WG_RUNNER=fake is not allowed in production; use "exec"',
      });
    }

    for (const key of ['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET'] as const) {
      if (PLACEHOLDER.test(env[key])) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: [key],
          message: `${key} still holds the .env.example placeholder`,
        });
      }
    }
  });

export type Env = z.infer<typeof envSchema>;

/**
 * Validate at boot and fail loudly. A misconfigured VPN control plane should refuse
 * to start, not discover the problem when a user tries to connect.
 */
export function validateEnv(raw: Record<string, unknown>): Env {
  const result = envSchema.safeParse(raw);
  if (result.success) return result.data;

  const details = result.error.issues
    .map((i) => `  - ${i.path.join('.') || '(root)'}: ${i.message}`)
    .join('\n');
  throw new Error(`Invalid environment configuration:\n${details}`);
}
