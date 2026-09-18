-- Paid access, with a 24-hour trial derived from users.createdAt.
--
-- Nullable: null means the account has never subscribed, and entitlement falls
-- back to the trial window. No "trial started" column on purpose — it would be a
-- second source of truth for something createdAt already answers.
ALTER TABLE "users" ADD COLUMN "subscribedUntil" TIMESTAMP(3);
