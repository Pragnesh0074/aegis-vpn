import { randomBytes } from 'node:crypto';
import { validateAgentEnv } from './agent-env.validation';
import { tokenMatches } from './agent-token.guard';

describe('validateAgentEnv', () => {
  const valid = { WG_AGENT_TOKEN: randomBytes(24).toString('hex') };

  it('needs only the token and defaults the rest', () => {
    const env = validateAgentEnv({ ...valid });

    expect(env.AGENT_PORT).toBe(8787);
    expect(env.WG_INTERFACE).toBe('wg0');
  });

  /**
   * The agent is reached over a private network or through a TLS proxy. Binding to
   * every interface by default would put a root-adjacent surface on a machine whose
   * entire job is to be publicly reachable.
   */
  it('binds to loopback unless told otherwise', () => {
    expect(validateAgentEnv({ ...valid }).AGENT_BIND).toBe('127.0.0.1');
  });

  it('refuses a short token', () => {
    expect(() => validateAgentEnv({ WG_AGENT_TOKEN: 'short' })).toThrow(/>= 32 chars/);
  });

  it('refuses to start with no token at all', () => {
    expect(() => validateAgentEnv({})).toThrow(/node-agent environment/);
  });

  it('rejects an interface name that could not reach an argv array safely', () => {
    expect(() => validateAgentEnv({ ...valid, WG_INTERFACE: 'wg0; rm -rf /' })).toThrow(
      /invalid interface name/,
    );
  });

  /**
   * The agent must not be able to read the API's secrets even if someone copies the
   * API's env file onto a node. Extra keys are simply not in its schema, so
   * DATABASE_URL and the JWT secrets are unreadable rather than merely unused.
   */
  it('exposes nothing beyond its own narrow surface', () => {
    const env = validateAgentEnv({
      ...valid,
      DATABASE_URL: 'postgres://user:pw@host/db',
      JWT_ACCESS_SECRET: 'a'.repeat(40),
    });

    expect(env).not.toHaveProperty('DATABASE_URL');
    expect(env).not.toHaveProperty('JWT_ACCESS_SECRET');
  });
});

describe('tokenMatches', () => {
  const token = randomBytes(24).toString('hex');

  it('accepts the exact token', () => {
    expect(tokenMatches(token, token)).toBe(true);
  });

  it('rejects a wrong token of the same length', () => {
    const wrong = `${token.slice(0, -1)}${token.endsWith('a') ? 'b' : 'a'}`;

    expect(wrong).toHaveLength(token.length);
    expect(tokenMatches(wrong, token)).toBe(false);
  });

  it('rejects a prefix rather than throwing on the length mismatch', () => {
    // timingSafeEqual throws outright on unequal lengths; that must not surface as
    // a 500 that tells an attacker their guess was the wrong size in a different
    // way from being wrong.
    expect(tokenMatches(token.slice(0, 10), token)).toBe(false);
    expect(tokenMatches('', token)).toBe(false);
  });
});
