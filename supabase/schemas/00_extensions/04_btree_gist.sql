-- ===========================================
-- BTree GIST Extension
-- Range type indexing for scheduling
-- ===========================================

CREATE EXTENSION IF NOT EXISTS "btree_gist" WITH SCHEMA extensions;

COMMENT ON EXTENSION "btree_gist" IS 'GiST index support for btree data types';
