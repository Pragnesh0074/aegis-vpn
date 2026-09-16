import { Injectable, NotFoundException } from '@nestjs/common';
import { AppConfig } from '../config/configuration';
import { PrismaService } from '../prisma/prisma.service';
import { entitledToAdBlocking, type AdBlockSubject } from '../devices/dns-policy';

export interface UserProfile {
  id: string;
  email: string;
  createdAt: Date;
  deviceCount: number;
  maxDevices: number;
  /** What the user asked for. */
  adBlockEnabled: boolean;
  /** Whether their plan allows it. Both are sent so the client can say *why*. */
  adBlockEntitled: boolean;
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
      select: { id: true, email: true, createdAt: true, adBlockEnabled: true },
    });
    if (!user) throw new NotFoundException('User not found');

    return {
      ...user,
      deviceCount: await this.activeDeviceCount(userId),
      maxDevices: this.config.maxDevicesPerUser,
      adBlockEntitled: entitledToAdBlocking(user),
    };
  }

  /** Just the flag the resolver decision needs, without loading the whole row. */
  async adBlockSubject(userId: string): Promise<AdBlockSubject> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { adBlockEnabled: true },
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
