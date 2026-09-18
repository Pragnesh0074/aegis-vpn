/**
 * Seeds the first VPN node from SEED_NODE_* environment variables.
 *
 * Idempotent: re-running updates the existing row rather than creating a duplicate.
 * Nodes are matched on `region` + `name`, which is the natural key for an operator.
 *
 * Run with:  npm run seed
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/** WireGuard keys are 32 raw bytes in base64: 43 chars plus '='. */
const WG_PUBLIC_KEY = /^[A-Za-z0-9+/]{43}=$/;

/** host:port — hostname or IPv4, port 1-65535. */
const ENDPOINT = /^[A-Za-z0-9._-]+:\d{1,5}$/;

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(
      `${name} is not set. Copy .env.example to .env and fill in the SEED_NODE_* values.\n` +
        `The public key comes from the VPN server: cat /etc/wireguard/server.pub`,
    );
  }
  return value;
}

async function main(): Promise<void> {
  const name = process.env.SEED_NODE_NAME?.trim() || 'Mumbai #1';
  const region = process.env.SEED_NODE_REGION?.trim() || 'in-mumbai';
  const publicKey = required('SEED_NODE_PUBLIC_KEY');
  const endpoint = required('SEED_NODE_ENDPOINT');
  const subnetV4 = process.env.SEED_NODE_SUBNET_V4?.trim() || '10.7.0.0/24';
  const dns = process.env.SEED_NODE_DNS?.trim() || '10.7.0.1';
  const mtu = Number(process.env.SEED_NODE_MTU ?? 1280);

  if (!WG_PUBLIC_KEY.test(publicKey)) {
    throw new Error(
      `SEED_NODE_PUBLIC_KEY is not a valid WireGuard public key.\n` +
        `Expected 44 base64 chars ending in '='. Got ${publicKey.length} chars.\n` +
        `Make sure you used server.pub (the PUBLIC key), not server.key.`,
    );
  }
  if (!ENDPOINT.test(endpoint)) {
    throw new Error(`SEED_NODE_ENDPOINT must be host:port, e.g. vpn.example.com:51820`);
  }
  if (!Number.isInteger(mtu) || mtu < 1280 || mtu > 1500) {
    throw new Error(`SEED_NODE_MTU must be an integer between 1280 and 1500`);
  }

  const existing = await prisma.node.findFirst({ where: { region, name } });

  const node = existing
    ? await prisma.node.update({
        where: { id: existing.id },
        data: { publicKey, endpoint, subnetV4, dns, mtu, active: true },
      })
    : await prisma.node.create({
        data: { name, region, publicKey, endpoint, subnetV4, dns, mtu, active: true },
      });

  console.log(`${existing ? 'Updated' : 'Created'} node ${node.name} (${node.region})`);
  console.log(`  id       ${node.id}`);
  console.log(`  endpoint ${node.endpoint}`);
  console.log(`  subnet   ${node.subnetV4}  dns ${node.dns}  mtu ${node.mtu}`);
}

main()
  .catch((error: unknown) => {
    console.error(`\nSeed failed: ${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  })
  .finally(() => void prisma.$disconnect());
