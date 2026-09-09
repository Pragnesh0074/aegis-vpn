/** Payload carried by a short-lived access token. */
export interface AccessTokenPayload {
  sub: string; // user id
  email: string;
}

/**
 * Payload carried by a refresh token. `jti` is the primary key of the matching
 * `refresh_tokens` row, so a presented token can be located without a table scan.
 */
export interface RefreshTokenPayload {
  sub: string; // user id
  jti: string; // refresh_tokens.id
}

/** What `@CurrentUser()` resolves to on an authenticated request. */
export interface AuthenticatedUser {
  userId: string;
  email: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  /** Access token lifetime in seconds — lets the client refresh proactively. */
  expiresIn: number;
}
