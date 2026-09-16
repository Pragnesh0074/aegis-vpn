import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from './env.validation';

/**
 * Typed accessor over the validated environment. Inject this instead of
 * ConfigService so consumers get real types and no string keys.
 */
@Injectable()
export class AppConfig {
  constructor(private readonly config: ConfigService<Env, true>) {}

  private get<K extends keyof Env>(key: K): Env[K] {
    return this.config.get(key, { infer: true });
  }

  get nodeEnv() {
    return this.get('NODE_ENV');
  }
  get isProduction() {
    return this.nodeEnv === 'production';
  }
  get port() {
    return this.get('PORT');
  }

  /** Empty means "allow any origin" — only reachable outside production. */
  get corsOrigins(): string[] {
    return this.get('CORS_ORIGINS')
      .split(',')
      .map((o) => o.trim())
      .filter(Boolean);
  }

  get trustProxy() {
    return this.get('TRUST_PROXY');
  }

  get accessSecret() {
    return this.get('JWT_ACCESS_SECRET');
  }
  get refreshSecret() {
    return this.get('JWT_REFRESH_SECRET');
  }
  get accessTtl() {
    return this.get('JWT_ACCESS_TTL');
  }
  get refreshTtl() {
    return this.get('JWT_REFRESH_TTL');
  }

  get maxDevicesPerUser() {
    return this.get('MAX_DEVICES_PER_USER');
  }

  /** Seconds between handshake sweeps; 0 disables them. See `LastSeenService`. */
  get lastSeenPollSeconds() {
    return this.get('DEVICE_LAST_SEEN_POLL_SECONDS');
  }

  get wgInterface() {
    return this.get('WG_INTERFACE');
  }
  get wgRunner() {
    return this.get('WG_RUNNER');
  }
  get wgBinary() {
    return this.get('WG_BINARY');
  }
  get wgQuickBinary() {
    return this.get('WG_QUICK_BINARY');
  }
  get wgReconcileOnBoot() {
    return this.get('WG_RECONCILE_ON_BOOT');
  }
  /** Undefined until the fleet has more than one node; see `WgRunnerRegistry`. */
  get wgNodeId() {
    return this.get('WG_NODE_ID');
  }

  get seedNode() {
    return {
      name: this.get('SEED_NODE_NAME'),
      region: this.get('SEED_NODE_REGION'),
      publicKey: this.get('SEED_NODE_PUBLIC_KEY'),
      endpoint: this.get('SEED_NODE_ENDPOINT'),
      subnetV4: this.get('SEED_NODE_SUBNET_V4'),
      dns: this.get('SEED_NODE_DNS'),
      mtu: this.get('SEED_NODE_MTU'),
    };
  }
}
