import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { ThrottlerStorage } from '@nestjs/throttler';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { PrismaService } from '../src/prisma/prisma.service';

/**
 * Drives the real HTTP stack — guards, pipes, interceptors, the exception filter and
 * the throttler — with only PrismaService replaced. That keeps the suite fast and
 * hermetic while still proving the wiring, which is where the interesting bugs live
 * (a guard registered in the wrong order, a route that forgot @Public()).
 */
const prismaStub = {
  $connect: async () => undefined,
  $disconnect: async () => undefined,
  $queryRaw: async () => [{ '1': 1 }],
  user: {
    findUnique: async () => null,
    create: async () => {
      throw new Error('not exercised');
    },
  },
  refreshToken: {
    create: async () => ({}),
    findUnique: async () => null,
    updateMany: async () => ({ count: 0 }),
    update: async () => ({}),
    deleteMany: async () => ({ count: 0 }),
  },
  device: {
    findMany: async () => [],
    count: async () => 0,
    findFirst: async () => null,
    groupBy: async () => [],
  },
  node: { findMany: async () => [], findFirst: async () => null, findUnique: async () => null },
};

describe('Aegis API (e2e)', () => {
  let app: INestApplication;
  let http: ReturnType<INestApplication['getHttpServer']>;
  let throttlerStorage: ThrottlerStorage;

  /**
   * The throttler keeps counters in memory for the whole process, so a test that
   * floods a route leaves that route rate-limited for every test after it. Clearing
   * between tests keeps them order-independent — without this, the guard-ordering
   * test below exhausts /users/me and any later assertion on it sees 429.
   */
  const resetThrottler = () => {
    const holder = throttlerStorage as unknown as Record<string, unknown>;
    for (const field of ['storage', '_storage']) {
      const bucket = holder[field];
      if (bucket instanceof Map) {
        bucket.clear();
        return;
      }
      if (bucket && typeof bucket === 'object') {
        for (const k of Object.keys(bucket)) delete (bucket as Record<string, unknown>)[k];
        return;
      }
    }
    throw new Error(
      'Could not locate the throttler storage to reset — @nestjs/throttler internals changed',
    );
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue(prismaStub)
      .compile();

    app = moduleRef.createNestApplication();
    // Mirrors main.ts. Not applied by the testing module, so it must be set here or
    // the suite would validate nothing.
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.init();
    http = app.getHttpServer();
    throttlerStorage = moduleRef.get<ThrottlerStorage>(ThrottlerStorage);
  });

  beforeEach(() => resetThrottler());

  afterAll(async () => {
    await app?.close();
  });

  describe('authentication is on by default', () => {
    // JwtAuthGuard is a global APP_GUARD, so a new route is locked down unless it
    // opts out with @Public(). These assertions are the regression test for that.
    it.each([
      ['get', '/users/me'],
      ['get', '/nodes'],
      ['get', '/devices'],
    ])('%s %s requires a token', async (method, path) => {
      const res = await (request(http) as never as Record<string, (p: string) => request.Test>)[
        method
      ](path);
      expect(res.status).toBe(401);
    });

    it('POST /devices requires a token', async () => {
      await request(http).post('/devices').send({}).expect(401);
    });

    it('rejects a malformed bearer token', async () => {
      await request(http).get('/users/me').set('authorization', 'Bearer nonsense').expect(401);
    });
  });

  describe('GET /health', () => {
    it('is public and reports database reachability', async () => {
      const res = await request(http).get('/health').expect(200);
      expect(res.body).toMatchObject({ status: 'ok', database: 'up' });
      expect(res.body.uptimeSeconds).toBeGreaterThanOrEqual(0);
    });
  });

  describe('request id', () => {
    it('generates one when absent', async () => {
      const res = await request(http).get('/health');
      expect(res.headers['x-request-id']).toMatch(/^[0-9a-f-]{36}$/);
    });

    it('echoes a well-formed incoming id', async () => {
      const res = await request(http).get('/health').set('x-request-id', 'trace-42');
      expect(res.headers['x-request-id']).toBe('trace-42');
    });

    // The id lands in logs and in a response header, so it is not reflected verbatim.
    it('replaces a malformed incoming id rather than reflecting it', async () => {
      const res = await request(http).get('/health').set('x-request-id', 'bad id <script>');
      expect(res.headers['x-request-id']).not.toBe('bad id <script>');
      expect(res.headers['x-request-id']).toMatch(/^[0-9a-f-]{36}$/);
    });
  });

  describe('validation', () => {
    it('rejects an invalid email', async () => {
      await request(http)
        .post('/auth/register')
        .send({ email: 'not-an-email', password: 'long-enough-password' })
        .expect(400);
    });

    it('rejects a password under 10 characters', async () => {
      await request(http)
        .post('/auth/register')
        .send({ email: 'a@b.com', password: 'short' })
        .expect(400);
    });

    // forbidNonWhitelisted: a client cannot smuggle extra fields into a DTO.
    it('rejects unknown fields', async () => {
      await request(http)
        .post('/auth/register')
        .send({ email: 'a@b.com', password: 'long-enough-password', isAdmin: true })
        .expect(400);
    });

    it('rejects a non-UUID device id', async () => {
      await request(http).delete('/devices/not-a-uuid').expect(401); // auth runs first
    });
  });

  describe('rate limiting', () => {
    // /auth/login runs argon2 on every call, so it is both a credential-stuffing
    // target and a CPU amplification vector.
    it('limits /auth/login to 5 attempts per minute', async () => {
      const statuses: number[] = [];
      for (let i = 0; i < 7; i += 1) {
        const res = await request(http)
          .post('/auth/login')
          .send({ email: 'nobody@example.com', password: 'whatever-password' });
        statuses.push(res.status);
      }

      expect(statuses.slice(0, 5)).toEqual([401, 401, 401, 401, 401]);
      expect(statuses.slice(5)).toEqual([429, 429]);
    }, 30_000);

    /**
     * ThrottlerGuard is registered before JwtAuthGuard, so an unauthenticated flood
     * is rate limited rather than being allowed to 401 forever. If the order were
     * reversed this test would never see a 429.
     */
    it('throttles before authenticating', async () => {
      let sawThrottle = false;
      for (let i = 0; i < 130; i += 1) {
        const res = await request(http).get('/users/me');
        if (res.status === 429) {
          sawThrottle = true;
          break;
        }
        expect(res.status).toBe(401);
      }
      expect(sawThrottle).toBe(true);
    }, 60_000);

    it('does not throttle /health', async () => {
      for (let i = 0; i < 40; i += 1) {
        await request(http).get('/health').expect(200);
      }
    }, 30_000);
  });

  describe('error shape', () => {
    it('returns a structured body without leaking internals', async () => {
      const res = await request(http).get('/users/me');
      expect(res.body).toMatchObject({ statusCode: 401, path: '/users/me' });
      expect(res.body.timestamp).toBeDefined();
      expect(JSON.stringify(res.body)).not.toMatch(/at .*\.ts:|node_modules/);
    });

    it('404s an unknown route', async () => {
      await request(http).get('/nope').expect(404);
    });
  });
});
