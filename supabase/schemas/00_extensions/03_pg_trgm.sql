-- ===========================================
-- PG Trigram Extension
-- Full-text search support
-- ===========================================

CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA extensions;

COMMENT ON EXTENSION "pg_trgm" IS 'Trigram-based text similarity for search functionality';
