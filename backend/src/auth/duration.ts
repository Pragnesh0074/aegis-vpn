const UNITS: Record<string, number> = { s: 1, m: 60, h: 3600, d: 86400 };

/**
 * Parses a JWT-style duration ("15m", "30d", "3600") into seconds.
 *
 * @nestjs/jwt accepts these strings directly, but `refresh_tokens.expiresAt` needs a
 * real Date — so the same config value has to be parsed here to keep the token's
 * signed expiry and its database row in agreement.
 */
export function durationToSeconds(value: string): number {
  const match = /^(\d+)\s*([smhd])?$/.exec(value.trim());
  if (!match) {
    throw new Error(`Invalid duration "${value}". Expected e.g. "900", "15m", "30d".`);
  }
  const amount = Number(match[1]);
  const unit = match[2] ?? 's';
  return amount * UNITS[unit];
}

export function durationFromNow(value: string): Date {
  return new Date(Date.now() + durationToSeconds(value) * 1000);
}
