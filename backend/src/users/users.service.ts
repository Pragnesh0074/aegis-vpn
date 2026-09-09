import { Injectable, NotFoundException } from '@nestjs/common';
import { AppConfig } from '../config/configuration';
import { PrismaService } from '../prisma/prisma.service';

export interface UserProfile {
  id: string;
  email: string;
  createdAt: Date;
  deviceCount: number;
  maxDevices: number;
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
      select: { id: true, email: true, createdAt: true },
    });
    if (!user) throw new NotFoundException('User not found');

    return {
      ...user,
      deviceCount: await this.activeDeviceCount(userId),
      maxDevices: this.config.maxDevicesPerUser,
    };
  }

  /** True when the user has room for another peer. Used by C7 before issuing one. */
  async hasDeviceCapacity(userId: string): Promise<boolean> {
    const count = await this.activeDeviceCount(userId);
    return count < this.config.maxDevicesPerUser;
  }
}
