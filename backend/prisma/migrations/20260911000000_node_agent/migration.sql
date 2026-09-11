-- Reaching a node the API is not running on.
--
-- Both nullable: a node with neither is assumed to be this host's own, which is
-- what keeps the original single-node deployment valid without a data change.
ALTER TABLE "nodes" ADD COLUMN "agentUrl" TEXT;
ALTER TABLE "nodes" ADD COLUMN "agentToken" TEXT;
