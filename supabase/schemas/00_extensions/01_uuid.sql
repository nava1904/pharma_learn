-- ===========================================
-- UUID Extension
-- Primary key generation
-- ===========================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

COMMENT ON EXTENSION "uuid-ossp" IS 'UUID generation functions for primary keys';
