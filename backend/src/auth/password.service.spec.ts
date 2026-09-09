import { PasswordService } from './password.service';

describe('PasswordService', () => {
  let service: PasswordService;

  beforeAll(async () => {
    service = new PasswordService();
    await service.onModuleInit();
  });

  it('verifies a correct password', async () => {
    const hash = await service.hash('correct-horse-battery');
    await expect(service.verify(hash, 'correct-horse-battery')).resolves.toBe(true);
  });

  it('rejects an incorrect password', async () => {
    const hash = await service.hash('correct-horse-battery');
    await expect(service.verify(hash, 'wrong')).resolves.toBe(false);
  });

  it('produces a different hash for the same password (salted)', async () => {
    const [a, b] = await Promise.all([service.hash('same-password'), service.hash('same-password')]);
    expect(a).not.toBe(b);
  });

  it('uses argon2id with the pinned parameters', async () => {
    expect(await service.hash('x')).toMatch(/^\$argon2id\$v=19\$m=19456,t=2,p=1\$/);
  });

  it('treats a malformed stored hash as a wrong password, not an error', async () => {
    await expect(service.verify('not-a-hash', 'anything')).resolves.toBe(false);
  });

  describe('verifyMaybe', () => {
    it('returns false when there is no stored hash', async () => {
      await expect(service.verifyMaybe(null, 'anything')).resolves.toBe(false);
    });

    it('still verifies normally when a hash is present', async () => {
      const hash = await service.hash('right-password');
      await expect(service.verifyMaybe(hash, 'right-password')).resolves.toBe(true);
      await expect(service.verifyMaybe(hash, 'nope')).resolves.toBe(false);
    });

    /**
     * The point of the dummy hash: an unknown email must cost the same as a known one,
     * or response timing becomes an account-enumeration oracle. A hardcoded hash that
     * is subtly malformed makes argon2 throw immediately and reopens exactly that hole,
     * which is why it is generated in onModuleInit.
     */
    it('costs comparable work whether or not the account exists', async () => {
      const hash = await service.hash('some-password');

      const t0 = Date.now();
      await service.verifyMaybe(hash, 'wrong-password');
      const existing = Date.now() - t0;

      const t1 = Date.now();
      await service.verifyMaybe(null, 'wrong-password');
      const missing = Date.now() - t1;

      // Generous bounds: this asserts the same order of magnitude, not a constant.
      // A fail-fast dummy hash would return in well under a millisecond.
      expect(missing).toBeGreaterThan(existing * 0.3);
      expect(missing).toBeLessThan(existing * 3 + 20);
    });
  });
});
