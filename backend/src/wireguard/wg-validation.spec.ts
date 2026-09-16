import { randomBytes } from 'node:crypto';
import {
  assertIpInSubnet,
  assertValidPublicKey,
  intToIp,
  ipToInt,
  parseSubnet,
  subnetContains,
} from './wg-validation';

const key = () => randomBytes(32).toString('base64');

describe('ipToInt / intToIp', () => {
  it.each(['0.0.0.0', '10.7.0.2', '127.0.0.1', '192.168.1.1', '255.255.255.255'])(
    'round-trips %s',
    (ip) => {
      expect(intToIp(ipToInt(ip))).toBe(ip);
    },
  );

  // Without `>>> 0` any address with a leading octet >= 128 goes negative and every
  // range comparison silently inverts.
  it('keeps addresses with a high leading octet unsigned', () => {
    expect(ipToInt('192.168.1.1')).toBeGreaterThan(0);
    expect(ipToInt('255.255.255.255')).toBe(4_294_967_295);
  });

  it('preserves ordering across the sign-bit boundary', () => {
    expect(ipToInt('10.0.0.0')).toBeLessThan(ipToInt('192.0.0.0'));
    expect(ipToInt('127.255.255.255')).toBeLessThan(ipToInt('128.0.0.0'));
  });

  it.each(['', '10.7.0', '10.7.0.256', '1.2.3.4.5', 'abc'])('rejects %p', (input) => {
    expect(() => ipToInt(input)).toThrow(/Not an IPv4 address/);
  });
});

describe('parseSubnet', () => {
  it('starts the host range at .2, leaving .1 for the server', () => {
    expect(intToIp(parseSubnet('10.7.0.0/24').firstHost)).toBe('10.7.0.2');
  });

  it('excludes the broadcast address', () => {
    expect(intToIp(parseSubnet('10.7.0.0/24').lastHost)).toBe('10.7.0.254');
  });

  it('handles a /16', () => {
    const s = parseSubnet('10.8.0.0/16');
    expect(intToIp(s.firstHost)).toBe('10.8.0.2');
    expect(intToIp(s.lastHost)).toBe('10.8.255.254');
  });

  it('normalises an address that is not the network address', () => {
    expect(parseSubnet('10.7.0.37/24').networkInt).toBe(ipToInt('10.7.0.0'));
  });

  // /31 and /32 leave no usable host range at all.
  it.each(['10.7.0.0/31', '10.7.0.0/32', '10.7.0.0/4'])('rejects prefix in %s', (cidr) => {
    expect(() => parseSubnet(cidr)).toThrow(/Unsupported prefix/);
  });

  it.each(['', 'not-a-cidr', '10.7.0.0'])('rejects malformed %p', (cidr) => {
    expect(() => parseSubnet(cidr)).toThrow(/Invalid CIDR/);
  });
});

describe('assertIpInSubnet', () => {
  it('accepts an assignable address', () => {
    expect(assertIpInSubnet('10.7.0.9', '10.7.0.0/24')).toBe('10.7.0.9');
  });

  it.each([
    ['10.7.0.0', 'network address'],
    ['10.7.0.1', 'server address'],
    ['10.7.0.255', 'broadcast address'],
    ['10.8.0.5', 'a different subnet'],
  ])('rejects %s (%s)', (ip) => {
    expect(() => assertIpInSubnet(ip, '10.7.0.0/24')).toThrow(/outside the assignable range/);
  });
});

describe('assertValidPublicKey', () => {
  it('accepts a real 32-byte base64 key', () => {
    const k = key();
    expect(assertValidPublicKey(k)).toBe(k);
    expect(k).toHaveLength(44);
  });

  it('rejects a private-key-shaped value that is the wrong length', () => {
    expect(() => assertValidPublicKey(key().slice(0, 40))).toThrow();
  });

  // publicKey is client-supplied and reaches an argv array, so the regex is anchored
  // and allows no shell-significant characters.
  it.each([
    '',
    'short',
    'a'.repeat(44),
    '$(whoami)aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=',
    '; rm -rf / #aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=',
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=\n',
  ])('rejects %p', (input) => {
    expect(() => assertValidPublicKey(input)).toThrow(/WireGuard public key/);
  });

  it('rejects a key with a newline appended', () => {
    expect(() => assertValidPublicKey(`${key()}\n`)).toThrow();
  });
});

describe('subnetContains', () => {
  it('matches every address in the network, edges included', () => {
    // Wider than assertIpInSubnet on purpose: .1 is the node's own wg0 address
    // and is exactly what the whoami check sees from a client on that node.
    expect(subnetContains('10.8.0.0', '10.8.0.0/24')).toBe(true);
    expect(subnetContains('10.8.0.1', '10.8.0.0/24')).toBe(true);
    expect(subnetContains('10.8.0.255', '10.8.0.0/24')).toBe(true);
  });

  it('rejects an address in a neighbouring network', () => {
    expect(subnetContains('10.9.0.2', '10.8.0.0/24')).toBe(false);
  });

  it('returns false rather than throwing on anything unparseable', () => {
    // Its input is a remote address the server did not choose.
    expect(subnetContains('not-an-ip', '10.8.0.0/24')).toBe(false);
    expect(subnetContains('::1', '10.8.0.0/24')).toBe(false);
    expect(subnetContains('10.8.0.2', 'nonsense')).toBe(false);
  });
});
