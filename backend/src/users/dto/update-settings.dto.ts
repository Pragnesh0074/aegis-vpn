import { IsBoolean, IsOptional } from 'class-validator';

/**
 * Partial update of the account's own settings.
 *
 * Every field optional so the client can send just the one it changed, and a future
 * setting does not force it to round-trip the others.
 */
export class UpdateSettingsDto {
  /**
   * Whether this account's devices should be handed the filtering resolver.
   *
   * A request, not a grant: the server records it either way and `resolverFor`
   * decides whether the plan allows it.
   */
  @IsOptional()
  @IsBoolean()
  adBlockEnabled?: boolean;
}
