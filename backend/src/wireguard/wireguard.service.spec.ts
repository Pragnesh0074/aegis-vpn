import { randomBytes } from 'node:crypto';
import type { Node } from '@prisma/client';
import type { AppConfig } from '../config/configuration';
import type { PrismaService } from '../prisma/prisma.service';
import { IpAllocatorService } from './ip-allocator.service';
import { ExecWgRunner } from './runners/exec-wg.runner';
import { FakeWgRunner } from './runners/fake-wg.runner';
import { WireguardService } from './wireguard.service';

const key = () => randomBytes(32).toString('base64');

const node = {
  id: 'n1',
  name: 'Mumbai #1',
  subnetV4: '10.7.0.0/24',
  maxPeers: 250,
} as Node;

const config = { wgReconcileOnBoot: true, wgInterface: 'wg0' } as AppConfig;

function build(devices: { publicKey: string; tunnelIpV4: string }[]) {
  const prisma = {
    node: { findFirst: async () => node, findUnique: async () => node },
    device: { findMany: async () => devices },
  } as unknown as PrismaService;

  const runner = new FakeWgRunner();
  const service = new WireguardService(runner, prisma, new IpAllocatorService(prisma), config);
  return { runner, service };
}

describe('WireguardService.reconcile', () => {
  it('adds every active device to an empty interface', async () => {
    const devices = [
      { publicKey: key(), tunnelIpV4: '10.7.0.2' },
      { publicKey: key(), tunnelIpV4: '10.7.0.3' },
    ];
    const { runner, service } = build(devices);

    await expect(service.reconcile()).resolves.toEqual({ added: 2, removed: 0, unchanged: 0 });
    expect(await runner.listPeers()).toHaveLength(2);
  });

  it('is idempotent — a second run changes nothing', async () => {
    const devices = [{ publicKey: key(), tunnelIpV4: '10.7.0.2' }];
    const { service } = build(devices);

    await service.reconcile();
    await expect(service.reconcile()).resolves.toEqual({ added: 0, removed: 0, unchanged: 1 });
  });

  it('removes a peer that is not in the database', async () => {
    const devices = [{ publicKey: key(), tunnelIpV4: '10.7.0.2' }];
    const { runner, service } = build(devices);
    await service.reconcile();

    const orphan = key();
    await runner.addPeer({ publicKey: orphan, allowedIps: ['10.7.0.99/32'] });

    await expect(service.reconcile()).resolves.toMatchObject({ removed: 1 });
    expect((await runner.listPeers()).map((p) => p.publicKey)).not.toContain(orphan);
  });

  /**
   * The subtle case. A peer present with the WRONG allowed-ips routes another
   * client's traffic, so drift has to be corrected — checking only for absence
   * would leave it in place.
   */
  it('re-applies a peer whose allowed-ips drifted', async () => {
    const device = { publicKey: key(), tunnelIpV4: '10.7.0.2' };
    const { runner, service } = build([device]);

    await runner.addPeer({ publicKey: device.publicKey, allowedIps: ['10.7.0.77/32'] });

    await expect(service.reconcile()).resolves.toMatchObject({ added: 1 });
    const fixed = (await runner.listPeers()).find((p) => p.publicKey === device.publicKey);
    expect(fixed?.allowedIps).toEqual(['10.7.0.2/32']);
  });

  it('re-applies a peer carrying extra allowed-ips', async () => {
    const device = { publicKey: key(), tunnelIpV4: '10.7.0.2' };
    const { runner, service } = build([device]);

    await runner.addPeer({
      publicKey: device.publicKey,
      allowedIps: ['10.7.0.2/32', '10.7.0.50/32'],
    });

    await expect(service.reconcile()).resolves.toMatchObject({ added: 1 });
    expect(
      (await runner.listPeers()).find((p) => p.publicKey === device.publicKey)?.allowedIps,
    ).toEqual(['10.7.0.2/32']);
  });

  it('throws when there is no node row to reconcile against', async () => {
    const prisma = {
      node: { findFirst: async () => null, findUnique: async () => null },
      device: { findMany: async () => [] },
    } as unknown as PrismaService;
    const service = new WireguardService(
      new FakeWgRunner(),
      prisma,
      new IpAllocatorService(prisma),
      config,
    );

    await expect(service.reconcile()).rejects.toThrow(/No node row/);
  });
});

describe('WireguardService.applyPeer', () => {
  it('applies a /32 so a client cannot spoof another tunnel address', async () => {
    const { runner, service } = build([]);
    const device = { publicKey: key(), tunnelIpV4: '10.7.0.50' };

    await service.applyPeer(device as never, node);

    expect((await runner.listPeers())[0].allowedIps).toEqual(['10.7.0.50/32']);
  });

  it('rejects a malformed public key', async () => {
    const { service } = build([]);
    await expect(
      service.applyPeer({ publicKey: 'nope', tunnelIpV4: '10.7.0.5' } as never, node),
    ).rejects.toThrow(/WireGuard public key/);
  });

  it('rejects a tunnel IP outside the node subnet', async () => {
    const { service } = build([]);
    await expect(
      service.applyPeer({ publicKey: key(), tunnelIpV4: '10.9.9.9' } as never, node),
    ).rejects.toThrow(/outside the assignable range/);
  });
});

describe('WireguardService.onApplicationBootstrap', () => {
  it('does not reconcile when disabled', async () => {
    const { runner, service } = build([{ publicKey: key(), tunnelIpV4: '10.7.0.2' }]);
    (service as never as { config: AppConfig }).config = {
      ...config,
      wgReconcileOnBoot: false,
    } as AppConfig;

    await service.onApplicationBootstrap();
    expect(await runner.listPeers()).toHaveLength(0);
  });

  // A reconcile failure must not stop the API from serving: existing peers keep
  // working and the log is the signal that the interface may have drifted.
  it('swallows a reconcile failure so the app still starts', async () => {
    const { service } = build([]);
    jest.spyOn(service, 'reconcile').mockRejectedValue(new Error('interface is gone'));

    await expect(service.onApplicationBootstrap()).resolves.toBeUndefined();
  });
});

describe('ExecWgRunner.listPeers', () => {
  const runner = () =>
    new ExecWgRunner({ wgInterface: 'wg0', wgBinary: '/usr/bin/wg' } as AppConfig);

  const withDump = (dump: string) => {
    const r = runner();
    (r as never as { wg: (args: string[]) => Promise<string> }).wg = async () => dump;
    return r;
  };

  const kA = key();
  const kB = key();

  /**
   * `wg show <if> dump` puts the INTERFACE on the first line (private key, public
   * key, listen port, fwmark). Treating it as a peer invents a phantom peer that
   * reconciliation then "removes" on every single run.
   */
  it('skips the interface line', async () => {
    const peers = await withDump(
      [
        'SRVPRIVKEY\tSRVPUBKEY\t51820\toff',
        `${kA}\t(none)\t1.2.3.4:1234\t10.7.0.2/32\t1757000000\t1024\t2048\t25`,
        `${kB}\t(none)\t(none)\t10.7.0.3/32\t0\t0\t0\toff`,
      ].join('\n'),
    ).listPeers();

    expect(peers).toHaveLength(2);
    expect(peers.map((p) => p.publicKey)).toEqual([kA, kB]);
  });

  it('parses allowed-ips and transfer counters', async () => {
    const [peer] = await withDump(
      ['IFACE\tPUB\t51820\toff', `${kA}\t(none)\t1.2.3.4:1234\t10.7.0.2/32\t1757000000\t1024\t2048\t25`].join(
        '\n',
      ),
    ).listPeers();

    expect(peer.allowedIps).toEqual(['10.7.0.2/32']);
    expect(peer.transferRx).toBe(1024);
    expect(peer.transferTx).toBe(2048);
    expect(peer.latestHandshakeAt).toEqual(new Date(1_757_000_000_000));
  });

  it('maps a zero handshake to null rather than the unix epoch', async () => {
    const [peer] = await withDump(
      ['IFACE\tPUB\t51820\toff', `${kA}\t(none)\t(none)\t10.7.0.3/32\t0\t0\t0\toff`].join('\n'),
    ).listPeers();

    expect(peer.latestHandshakeAt).toBeNull();
  });

  it('treats "(none)" allowed-ips as an empty list', async () => {
    const [peer] = await withDump(
      ['IFACE\tPUB\t51820\toff', `${kA}\t(none)\t(none)\t(none)\t0\t0\t0\toff`].join('\n'),
    ).listPeers();

    expect(peer.allowedIps).toEqual([]);
  });

  it('returns nothing for an interface with no peers', async () => {
    await expect(withDump('IFACE\tPUB\t51820\toff').listPeers()).resolves.toEqual([]);
  });
});
