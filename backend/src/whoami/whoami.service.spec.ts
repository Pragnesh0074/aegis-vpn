import type { PrismaService } from '../prisma/prisma.service';
import { WhoamiService } from './whoami.service';

const MUMBAI = {
  id: 'n1',
  name: 'Mumbai #1',
  region: 'in-mumbai',
  endpoint: '3.111.32.212:51820',
  subnetV4: '10.8.0.0/24',
};

const FRANKFURT = {
  id: 'n2',
  name: 'Frankfurt #1',
  region: 'de-frankfurt',
  endpoint: '3.71.204.118:51820',
  subnetV4: '10.9.0.0/24',
};

function service(nodes: unknown[] = [MUMBAI, FRANKFURT], onFindMany?: () => never) {
  let calls = 0;
  const prisma = {
    node: {
      findMany: async () => {
        calls++;
        if (onFindMany) onFindMany();
        return nodes;
      },
    },
  } as unknown as PrismaService;

  return { whoami: new WhoamiService(prisma), calls: () => calls };
}

describe('WhoamiService', () => {
  it('recognises a node endpoint as the tunnel', async () => {
    const { whoami } = service();

    await expect(whoami.check('3.71.204.118')).resolves.toMatchObject({
      ip: '3.71.204.118',
      viaTunnel: true,
      node: { id: 'n2', name: 'Frankfurt #1', region: 'de-frankfurt' },
    });
  });

  it('recognises a tunnel address on the node the API itself runs on', async () => {
    // No NAT on that path: the client's packet reaches the API from 10.8.0.x
    // directly, so matching only egress addresses would report a leak.
    const { whoami } = service();

    await expect(whoami.check('10.8.0.7')).resolves.toMatchObject({
      viaTunnel: true,
      node: { name: 'Mumbai #1' },
    });
  });

  it('reports an address outside the fleet as not tunnelled', async () => {
    const { whoami } = service();

    await expect(whoami.check('49.36.180.22')).resolves.toMatchObject({
      ip: '49.36.180.22',
      viaTunnel: false,
      node: null,
    });
  });

  it('unmaps an IPv6-mapped IPv4 source address', async () => {
    // Which is the form a dual-stack listener reports, so without unmapping every
    // check from a tunnelled client would read as a leak.
    const { whoami } = service();

    await expect(whoami.check('::ffff:3.71.204.118')).resolves.toMatchObject({
      ip: '3.71.204.118',
      viaTunnel: true,
    });
  });

  it('does not match a node whose endpoint is a hostname', async () => {
    // Resolving it would put a DNS lookup on an unauthenticated path. The node's
    // tunnel subnet is still matched.
    const { whoami } = service([{ ...FRANKFURT, endpoint: 'fra1.example.com:51820' }]);

    await expect(whoami.check('3.71.204.118')).resolves.toMatchObject({ viaTunnel: false });
    await expect(whoami.check('10.9.0.4')).resolves.toMatchObject({ viaTunnel: true });
  });

  it('caches the address table rather than reading it per request', async () => {
    const { whoami, calls } = service();

    await whoami.check('10.8.0.7');
    await whoami.check('10.8.0.8');
    await whoami.check('1.1.1.1');

    expect(calls()).toBe(1);
  });

  it('answers with no node when the database is unreachable', async () => {
    const { whoami } = service([], () => {
      throw new Error('connection refused');
    });

    await expect(whoami.check('10.8.0.7')).resolves.toMatchObject({
      ip: '10.8.0.7',
      viaTunnel: false,
      node: null,
    });
  });

  it('handles a missing source address without throwing', async () => {
    const { whoami } = service();

    await expect(whoami.check(undefined)).resolves.toMatchObject({
      ip: 'unknown',
      viaTunnel: false,
    });
  });
});
