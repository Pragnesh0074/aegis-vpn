-- The rewarded-ad experiment is removed.
--
-- AdMob would not serve reliably through the tunnel and the workarounds all cost
-- more than the feature was worth, so entitlement goes back to "everyone" and the
-- grant expiry has nothing left to record. The column is nullable and unread, so
-- dropping it loses nothing a user would notice.
ALTER TABLE "users" DROP COLUMN IF EXISTS "adBlockUntil";
