import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomUUID } from 'node:crypto';
import { AppConfig } from '../config/configuration';
import { PrismaService } from '../prisma/prisma.service';
import type { AccessTokenPayload, RefreshTokenPayload, TokenPair } from './auth.types';
import { durationFromNow, durationToSeconds } from './duration';

/**
 * Issues and rotates tokens.
 *
 * Access tokens are stateless JWTs (short TTL, never checked against the database on
 * the hot path beyond confirming the user still exists).
 *
 * Refresh tokens are JWTs *and* have a database row. The JWT gives us a signature and
 * an expiry; the row gives us revocation, rotation and reuse detection — none of which
 * a stateless token can do. Only `sha256(token)` is stored, so a database leak yields
 * no usable sessions.
 */
@Injectable()
export class TokenService {
  private readonly logger = new Logger(TokenService.name);

  constructor(
    private readonly jwt: JwtService,
    private readonly config: AppConfig,
    private readonly prisma: PrismaService,
  ) {}

  private static hash(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  /** Mints a fresh pair and records the refresh token. `replaces` links a rotation. */
  async issuePair(
    userId: string,
    email: string,
    replaces?: { id: string },
  ): Promise<TokenPair> {
    const accessToken = await this.jwt.signAsync(
      { sub: userId, email } satisfies AccessTokenPayload,
      { secret: this.config.accessSecret, expiresIn: this.config.accessTtl },
    );

    // The row id is minted first so it can be embedded as the token's `jti`.
    const jti = randomUUID();
    const refreshToken = await this.jwt.signAsync(
      { sub: userId, jti } satisfies RefreshTokenPayload,
      { secret: this.config.refreshSecret, expiresIn: this.config.refreshTtl },
    );

    await this.prisma.$transaction(async (tx) => {
      await tx.refreshToken.create({
        data: {
          id: jti,
          userId,
          tokenHash: TokenService.hash(refreshToken),
          expiresAt: durationFromNow(this.config.refreshTtl),
        },
      });

      if (replaces) {
        await tx.refreshToken.update({
          where: { id: replaces.id },
          data: { revokedAt: new Date(), replacedByTokenId: jti },
        });
      }
    });

    return {
      accessToken,
      refreshToken,
      expiresIn: durationToSeconds(this.config.accessTtl),
    };
  }

  /**
   * Validates a refresh token and rotates it.
   *
   * If a token that has already been rotated is presented again, the token is assumed
   * stolen — a legitimate client never reuses one — and every refresh token for that
   * user is revoked, forcing a re-login everywhere.
   */
  async rotate(rawToken: string): Promise<TokenPair> {
    let payload: RefreshTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<RefreshTokenPayload>(rawToken, {
        secret: this.config.refreshSecret,
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const record = await this.prisma.refreshToken.findUnique({
      where: { id: payload.jti },
      include: { user: { select: { id: true, email: true } } },
    });

    // A validly signed token with no row means the row was deleted (user removed, or
    // pruned). Nothing to rotate.
    if (!record || record.userId !== payload.sub) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    // Signature alone is not enough: confirm this is the exact token we issued, so a
    // token whose row was reassigned cannot be replayed.
    if (record.tokenHash !== TokenService.hash(rawToken)) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (record.revokedAt) {
      this.logger.warn(
        `Refresh token reuse detected for user ${record.userId} (token ${record.id}); ` +
          `revoking all sessions`,
      );
      await this.revokeAllForUser(record.userId);
      throw new UnauthorizedException('Refresh token already used');
    }

    if (record.expiresAt <= new Date()) {
      throw new UnauthorizedException('Refresh token expired');
    }

    return this.issuePair(record.user.id, record.user.email, { id: record.id });
  }

  /** Revokes a single presented token. Idempotent — an unknown token is a no-op. */
  async revoke(rawToken: string): Promise<void> {
    let payload: RefreshTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<RefreshTokenPayload>(rawToken, {
        secret: this.config.refreshSecret,
      });
    } catch {
      return; // logout should never fail loudly on a junk token
    }

    await this.prisma.refreshToken.updateMany({
      where: { id: payload.jti, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /**
   * Deletes this user's expired refresh tokens.
   *
   * Every login and every rotation inserts a row, so the table grows without bound.
   * Doing this opportunistically on login avoids adding a scheduler for one query;
   * it is a bounded, indexed delete scoped to a single user.
   *
   * Revoked-but-unexpired rows are kept on purpose: they are what makes reuse
   * detection work. Deleting them would turn a replayed stolen token into a plain
   * "not found" instead of triggering a family-wide revocation.
   */
  async pruneExpired(userId: string): Promise<number> {
    const { count } = await this.prisma.refreshToken.deleteMany({
      where: { userId, expiresAt: { lt: new Date() } },
    });
    return count;
  }

  async revokeAllForUser(userId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
}
