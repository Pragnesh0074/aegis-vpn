import { Injectable, NotFoundException } from '@nestjs/common';
import { AppConfig } from '../config/configuration';
import { PrismaService } from '../prisma/prisma.service';
import { entitledToAdBlocking, type AdBlockSubject } from '../devices/dns-policy';
import {
  accessRemainingMs,
  extendSubscription,
  isInTrial,
  isSubscribed,
  trialEndsAt,
} from './entitlement';

export interface UserProfile {
  id: string;
  email: string;
  createdAt: Date;
  deviceCount: number;
  maxDevices: number;
  /** What the user asked for. */
  adBlockEnabled: boolean;
  /**
   * Whether the account's plan allows filtering. Sent alongside [adBlockEnabled]
   * so the client can say *why* it is off rather than just that it is.
   */
  adBlockEntitled: boolean;

  /// Paid access, in one place so the client never has to do date arithmetic to
  /// decide what to show.
  access: AccessState;
}

/** What the account may use, and on what basis. */
export interface AccessState {
  /** True when the paid features are available right now, trial or subscription. */
  entitled: boolean;
  /** True when that is the free trial rather than a subscription. */
  onTrial: boolean;
  subscribed: boolean;
  /** When the 24h trial ends. Always set; often in the past. */
  trialEndsAt: Date;
  subscribedUntil: Date | null;
  /** Milliseconds until access lapses, for a countdown. Zero when it already has. */
  remainingMs: number;
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
        subscribedUntil: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');

    // One instant for every derived field, so a profile cannot report "entitled"
    // next to zero milliseconds remaining because the clock moved between them.
    const now = new Date();
    const { subscribedUntil: _omitted, ...rest } = user;

    return {
      ...rest,
      deviceCount: await this.activeDeviceCount(userId),
      maxDevices: this.config.maxDevicesPerUser,
      adBlockEntitled: entitledToAdBlocking(user, now),
      access: {
        entitled: entitledToAdBlocking(user, now),
        onTrial: isInTrial(user, now),
        subscribed: isSubscribed(user, now),
        trialEndsAt: trialEndsAt(user),
        subscribedUntil: user.subscribedUntil,
        remainingMs: accessRemainingMs(user, now),
      },
    };
  }

  /**
   * A DUMMY checkout. Takes no money and verifies nothing.
   *
   * It exists so the paywall can be built and walked through end to end before a
   * payment provider is chosen. When one lands, this must be driven by a signed
   * webhook from the provider and NOT by the client saying it paid — as written,
   * any authenticated caller can grant themselves a month.
   */
  async startDummySubscription(userId: string): Promise<UserProfile> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { createdAt: true, subscribedUntil: true },
    });
    if (!user) throw new NotFoundException('User not found');

    await this.prisma.user.update({
      where: { id: userId },
      data: { subscribedUntil: extendSubscription(user) },
    });
    return this.getProfile(userId);
  }

  /** Clears the dummy subscription, so the paywall can be tested more than once. */
  async cancelDummySubscription(userId: string): Promise<UserProfile> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { subscribedUntil: null },
    });
    return this.getProfile(userId);
  }

  /** Just the flag the resolver decision needs, without loading the whole row. */
  async adBlockSubject(userId: string): Promise<AdBlockSubject> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { adBlockEnabled: true, createdAt: true, subscribedUntil: true },
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

  /** True when the user has room for another peer. Used by C7 before issuing one. */
  async hasDeviceCapacity(userId: string): Promise<boolean> {
    const count = await this.activeDeviceCount(userId);
    return count < this.config.maxDevicesPerUser;
  }
}
