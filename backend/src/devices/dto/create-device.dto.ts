import { IsIn, IsOptional, IsString, IsUUID, Matches, MaxLength, MinLength } from 'class-validator';
import { WG_PUBLIC_KEY } from '../../wireguard/wg-validation';

export const PLATFORMS = ['android', 'ios', 'macos', 'windows', 'linux'] as const;
export type Platform = (typeof PLATFORMS)[number];

export class CreateDeviceDto {
  /**
   * The device's WireGuard PUBLIC key, generated on the device.
   *
   * The matching private key must never be sent here. Validated with the same
   * anchored regex the runner uses, so a malformed key is rejected at the edge.
   */
  @Matches(WG_PUBLIC_KEY, {
    message: 'publicKey must be a WireGuard public key: 44 base64 characters ending in "="',
  })
  publicKey!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(64)
  name!: string;

  @IsIn(PLATFORMS, { message: `platform must be one of: ${PLATFORMS.join(', ')}` })
  platform!: Platform;

  /** Optional. When omitted, the least-loaded node with capacity is chosen. */
  @IsOptional()
  @IsUUID()
  nodeId?: string;
}
