import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Patch, Post } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../auth/auth.types';
import { UsersService, type UserProfile } from './users.service';
import { UpdateSettingsDto } from './dto/update-settings.dto';

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  me(@CurrentUser() user: AuthenticatedUser): Promise<UserProfile> {
    return this.users.getProfile(user.userId);
  }

  /**
   * Updates the caller's own settings and returns the whole profile back, so the
   * client re-renders from what the server actually stored rather than from what it
   * optimistically assumed.
   *
   * Changing `adBlockEnabled` does not move a live tunnel. The resolver is part of
   * the WireGuard `[Interface]`, so the client has to re-read
   * `GET /devices/:id/config` and rebuild for it to take effect.
   */
  @Patch('me/settings')
  async updateSettings(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdateSettingsDto,
  ): Promise<UserProfile> {
    if (dto.adBlockEnabled !== undefined) {
      return this.users.setAdBlockEnabled(user.userId, dto.adBlockEnabled);
    }
    return this.users.getProfile(user.userId);
  }

  /**
   * DUMMY checkout. Grants a month and takes no money.
   *
   * Deliberately unverified, because there is nothing yet to verify against: it
   * exists so the paywall can be walked end to end before a provider is chosen.
   * Any authenticated caller can grant themselves access, which is precisely why
   * this must be replaced by a provider webhook before launch.
   */
  @Post('me/subscription')
  @HttpCode(HttpStatus.OK)
  subscribe(@CurrentUser() user: AuthenticatedUser): Promise<UserProfile> {
    return this.users.startDummySubscription(user.userId);
  }

  /** Clears the dummy subscription, so the paywall can be tested more than once. */
  @Delete('me/subscription')
  @HttpCode(HttpStatus.OK)
  unsubscribe(@CurrentUser() user: AuthenticatedUser): Promise<UserProfile> {
    return this.users.cancelDummySubscription(user.userId);
  }
}
