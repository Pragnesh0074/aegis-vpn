import { Injectable, OnModuleInit } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import * as argon2 from 'argon2';

/**
 * argon2id with OWASP's recommended minimum parameters. Set explicitly rather than
 * relying on library defaults so an upstream default change cannot silently weaken
 * every password hashed after an upgrade.
 */
const OPTIONS: argon2.Options = {
  type: argon2.argon2id,
  memoryCost: 19456, // 19 MiB
  timeCost: 2,
  parallelism: 1,
};

@Injectable()
export class PasswordService implements OnModuleInit {
  /**
   * Hash of an unguessable random value, verified against when an account does not
   * exist so that login costs the same either way.
   *
   * Generated at boot rather than hardcoded: a literal hash that is subtly malformed
   * makes argon2 throw immediately, which returns "false" fast and reinstates exactly
   * the timing oracle it was meant to close. Deriving it here makes that impossible.
   */
  private dummyHash!: string;

  async onModuleInit(): Promise<void> {
    this.dummyHash = await argon2.hash(randomBytes(32).toString('hex'), OPTIONS);
  }

  hash(plain: string): Promise<string> {
    return argon2.hash(plain, OPTIONS);
  }

  async verify(hash: string, plain: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, plain);
    } catch {
      // A malformed stored hash must read as "wrong password", never as a 500.
      return false;
    }
  }

  /**
   * Verifies against a possibly-absent hash in constant work.
   *
   * Callers must not short-circuit on a missing user before verifying — response
   * timing would then reveal which email addresses have accounts.
   */
  async verifyMaybe(hash: string | null | undefined, plain: string): Promise<boolean> {
    const result = await this.verify(hash ?? this.dummyHash, plain);
    return hash ? result : false;
  }
}
