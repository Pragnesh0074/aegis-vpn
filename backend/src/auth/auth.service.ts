import { ConflictException, Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import type { TokenPair } from './auth.types';
import type { LoginDto } from './dto/login.dto';
import type { RegisterDto } from './dto/register.dto';
import { PasswordService } from './password.service';
import { TokenService } from './token.service';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
    private readonly tokens: TokenService,
  ) {}

  /** Emails are stored lowercased so `A@b.com` and `a@b.com` cannot both register. */
  private static normalizeEmail(email: string): string {
    return email.trim().toLowerCase();
  }

  async register(dto: RegisterDto): Promise<TokenPair> {
    const email = AuthService.normalizeEmail(dto.email);
    const passwordHash = await this.passwords.hash(dto.password);

    try {
      const user = await this.prisma.user.create({
        data: { email, passwordHash },
        select: { id: true, email: true },
      });
      return this.tokens.issuePair(user.id, user.email);
    } catch (error) {
      // Rely on the unique constraint rather than a check-then-insert, which races.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('An account with that email already exists');
      }
      throw error;
    }
  }

  async login(dto: LoginDto): Promise<TokenPair> {
    const email = AuthService.normalizeEmail(dto.email);
    const user = await this.prisma.user.findUnique({
      where: { email },
      select: { id: true, email: true, passwordHash: true },
    });

    // Always verify, even when the email is unknown: PasswordService falls back to a
    // dummy hash so response timing is not an account-enumeration oracle.
    const valid = await this.passwords.verifyMaybe(user?.passwordHash, dto.password);

    // Same message and same work for "no such user" and "wrong password".
    if (!user || !valid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    // Opportunistic cleanup so refresh_tokens does not grow forever. Never allowed
    // to fail a login — this is housekeeping, not part of authenticating.
    await this.tokens.pruneExpired(user.id).catch((error: unknown) => {
      this.logger.warn(
        `Pruning expired refresh tokens failed for user ${user.id}: ` +
          `${error instanceof Error ? error.message : String(error)}`,
      );
    });

    return this.tokens.issuePair(user.id, user.email);
  }

  refresh(refreshToken: string): Promise<TokenPair> {
    return this.tokens.rotate(refreshToken);
  }

  logout(refreshToken: string): Promise<void> {
    return this.tokens.revoke(refreshToken);
  }
}
