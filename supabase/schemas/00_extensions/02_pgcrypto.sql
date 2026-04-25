-- ===========================================
-- PGCrypto Extension
-- Cryptographic functions for e-signatures and integrity hashes
-- 21 CFR Part 11 Compliance
-- ===========================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;

COMMENT ON EXTENSION "pgcrypto" IS 'Cryptographic functions for password hashing and integrity verification (21 CFR Part 11)';
