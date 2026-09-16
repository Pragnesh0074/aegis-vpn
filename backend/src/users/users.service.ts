import { Injectable, NotFoundException } from '@nestjs/common';
import { AppConfig } from '../config/configuration';
import { PrismaService } from '../prisma/prisma.service';
import {
  adBlockRemainingMs,
  entitledToAdBlocking,
  extendAdBlockGrant,
  type AdBlockSubject,
} from '../devices/dns-policy';

export interface UserProfile {
  id: string;
  email: string;
  createdAt: Date;
  deviceCount: number;
  maxDevices: number;
  /** What the user asked for. */
  adBlockEnabled: boolean;
  /**
   * Whether the account may have filtering right now — currently, whether a
   * rewarded-ad grant is still running. Sent alongside [adBlockEnabled] so the
   * client can say *why* filtering is off rather than just that it is.
   */
  adBlockEntitled: boolean;
  /** Milliseconds of grant left, for the countdown. Zero when not entitled. */
  adBlockRemainingMs: number;
}

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: AppConfig,
  ) {}

  /**
   * Devices that currently hold a WireGuard peer.
   *
   * Revoked devices are soft-deleted (`revokedAt`) and must not count against the
   * cap — otherwise a user who removes and re-adds a phone would be locked out.
   * C7's device-cap check reuses this exact predicate, so the count the user sees
   * on /users/me is the same one that gates POST /devices.
   */
  activeDeviceCount(userId: string): Promise<number> {
    return this.prisma.device.count({ where: { userId, revokedAt: null } });
  }

  async getProfile(userId: string): Promise<UserProfile> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        createdAt: true,
        adBlockEnabled: true,
        adBlockUntil: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');

    // One instant for both, so a profile cannot report "entitled" alongside zero
    // milliseconds remaining because the clock moved between the two calls.
    const now = new Date();
    const { adBlockUntil: _omitted, ...rest } = user;

    return {
      ...rest,
      deviceCount: await this.activeDeviceCount(userId),
      maxDevices: this.config.maxDevicesPerUser,
      adBlockEntitled: entitledToAdBlocking(user, now),
      adBlockRemainingMs: adBlockRemainingMs(user, now),
    };
  }

  /** Just the flag the resolver decision needs, without loading the whole row. */
  async adBlockSubject(userId: string): Promise<AdBlockSubject> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { adBlockEnabled: true, adBlockUntil: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  /**
   * Records the user's ad-blocking preference.
   *
   * Stored even when the plan does not allow it, so a lapsed subscriber gets their
   * setting back on renewal instead of silently losing it. `resolverFor` is what
   * actually enforces entitlement.
   *
   * Takes effect on the next config the device fetches — existing tunnels keep the
   * resolver they were built with until the client re-reads `GET /devices/:id/config`
   * and rebuilds.
   */
  async setAdBlockEnabled(userId: string, enabled: boolean): Promise<UserProfile> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { adBlockEnabled: enabled },
    });
    return this.getProfile(userId);
  }

  /**
   * Credits one watched rewarded ad.
   *
   * NOTE: nothing here proves an ad was actually watched — the client simply says
   * so. AdMob's server-side verification callback is the fix, and until it is
   * wired up this endpoint is worth exactly as much as the client's word.
   * `AD_BLOCK_MAX_BANKED_MS` caps the damage: a caller in a loop can bank an hour
   * and no more.
   *
   * Switching the preference on is deliberate. Someone who just sat through an ad
   * to earn filtering meant to have it, and making them find the toggle
   * afterwards would be a bad joke.
   */
  async grantAdBlockReward(userId: string): Promise<UserProfile> {
    const subject = await this.adBlockSubject(userId);
    await this.prisma.user.update({
      where: { id: userId },
      data: { adBlockUntil: extendAdBlockGrant(subject), adBlockEnabled: true },
    });
    return this.getProfile(userId);
  }

  /** True when the user has room for another peer. Used by C7 before issuing one. */
  async hasDeviceCapacity(userId: string): Promise<boolean> {
    const count = await this.activeDeviceCount(userId);
    return count < this.config.maxDevicesPerUser;
  }
}
