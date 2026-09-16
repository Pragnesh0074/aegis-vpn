-- Time-limited ad-blocking, earned by watching a rewarded ad.
--
-- Nullable, and null means "not entitled". Existing accounts therefore lose
-- filtering until they earn a grant, which is the point of gating it.
ALTER TABLE "users" ADD COLUMN "adBlockUntil" TIMESTAMP(3);
