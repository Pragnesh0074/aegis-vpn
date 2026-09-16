-- Per-user ad blocking.
--
-- Defaults to true so no existing account loses filtering it already had. The column
-- records what the user ASKED for; entitlement (a paid plan, later) is applied when
-- the resolver is chosen, so a lapsed subscriber keeps the preference for renewal.
ALTER TABLE "users" ADD COLUMN "adBlockEnabled" BOOLEAN NOT NULL DEFAULT true;

-- The node's second resolver: Unbound reached directly, with no blocklist in front.
--
-- Nullable because a node provisioned before this existed has only the filtering
-- resolver. There the switch cannot be honoured and `dns` is used either way — see
-- `resolverFor`. Both addresses are excluded from peer allocation.
ALTER TABLE "nodes" ADD COLUMN "dnsUnfiltered" TEXT;
