/**
 * Environment for the e2e suite, applied before any module is instantiated.
 *
 * `AppConfigModule` validates the environment when Nest builds the module graph and
 * refuses to start on a bad value, so these have to be in place first.
 */
process.env.NODE_ENV = 'development';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-'.padEnd(48, 'a');
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-'.padEnd(48, 'b');
process.env.WG_RUNNER = 'fake';
process.env.WG_RECONCILE_ON_BOOT = 'false';
process.env.TRUST_PROXY = 'false';
