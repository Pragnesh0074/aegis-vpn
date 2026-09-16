import { Body, Controller, Get, HttpCode, HttpStatus, Patch, Post } from '@nestjs/common';
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
   * Credits one watched rewarded ad and returns the refreshed profile, whose
   * `adBlockRemainingMs` is what the client counts down from.
   *
   * Unverified: the client asserts the ad was watched. AdMob's server-side
   * verification callback should replace this before anyone is charged for
   * anything — see `grantAdBlockReward`.
   */
  @Post('me/ad-block/grant')
  @HttpCode(HttpStatus.OK)
  grantAdBlock(@CurrentUser() user: AuthenticatedUser): Promise<UserProfile> {
    return this.users.grantAdBlockReward(user.userId);
  }
}
