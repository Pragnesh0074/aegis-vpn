import { validateEnv } from './env.validation';

const A = 'a'.repeat(48);
const B = 'b'.repeat(48);
const base = { DATABASE_URL: 'postgresql://x', JWT_ACCESS_SECRET: A, JWT_REFRESH_SECRET: B };

describe('validateEnv', () => {
  it('accepts a minimal development environment', () => {
    expect(() => validateEnv(base)).not.toThrow();
  });

  it('requires DATABASE_URL', () => {
    expect(() => validateEnv({ JWT_ACCESS_SECRET: A, JWT_REFRESH_SECRET: B })).toThrow(
      /DATABASE_URL/,
    );
  });

  it('rejects a short secret', () => {
    expect(() => validateEnv({ ...base, JWT_ACCESS_SECRET: 'short' })).toThrow(/32 chars/);
  });

  it('rejects identical access and refresh secrets', () => {
    expect(() => validateEnv({ ...base, JWT_REFRESH_SECRET: A })).toThrow(/must differ/);
  });

  it('rejects an interface name that could carry shell metacharacters', () => {
    expect(() => validateEnv({ ...base, WG_INTERFACE: 'wg0; rm -rf /' })).toThrow(
      /invalid interface name/,
    );
  });

  it('rejects an out-of-range MTU', () => {
    expect(() => validateEnv({ ...base, SEED_NODE_MTU: '9000' })).toThrow();
  });

  describe('production guards', () => {
    const prod = { ...base, NODE_ENV: 'production', WG_RUNNER: 'exec' };

    it('accepts a valid production environment', () => {
      expect(() => validateEnv(prod)).not.toThrow();
    });

    // A fake runner in production would ACK peer creation over HTTP while never
    // touching wg0 — every client would get a config that cannot connect.
    it('rejects WG_RUNNER=fake', () => {
      expect(() => validateEnv({ ...prod, WG_RUNNER: 'fake' })).toThrow(/not allowed in production/);
    });

    it('rejects a leftover .env.example placeholder secret', () => {
      expect(() =>
        validateEnv({ ...prod, JWT_ACCESS_SECRET: 'replace-me-'.repeat(4) }),
      ).toThrow(/placeholder/);
    });

    it('allows WG_RUNNER=fake outside production', () => {
      expect(() => validateEnv({ ...base, WG_RUNNER: 'fake' })).not.toThrow();
    });
  });

  // z.coerce.boolean() would make this true, because Boolean('false') === true.
  describe('boolean parsing', () => {
    it.each([
      ['false', false],
      ['0', false],
      ['true', true],
      ['1', true],
    ])('WG_RECONCILE_ON_BOOT=%s -> %s', (input, expected) => {
      expect(validateEnv({ ...base, WG_RECONCILE_ON_BOOT: input }).WG_RECONCILE_ON_BOOT).toBe(
        expected,
      );
    });

    it('defaults WG_RECONCILE_ON_BOOT to true', () => {
      expect(validateEnv(base).WG_RECONCILE_ON_BOOT).toBe(true);
    });

    it('defaults TRUST_PROXY to false', () => {
      expect(validateEnv(base).TRUST_PROXY).toBe(false);
    });
  });
});
