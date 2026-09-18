import { IsBoolean, IsIn, IsOptional } from 'class-validator';

import { PLANS, type SubscriptionPlan } from '../entitlement';

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

/** Which plan a (dummy) checkout is for. */
export class SubscribeDto {
  /**
   * Defaults to monthly so an older client that sends no body still works, and
   * gets the smaller grant rather than the larger one.
   */
  @IsOptional()
  @IsIn(PLANS)
  plan?: SubscriptionPlan;
}
