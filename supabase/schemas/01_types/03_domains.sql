-- ===========================================
-- DOMAIN TYPES
-- Constrained data types for validation
-- ===========================================

-- Role level domain (Learn-IQ: 1 = highest seniority, 99.99 = lowest)
DO $$ BEGIN
    CREATE DOMAIN role_level AS NUMERIC(5,2)
        CHECK (VALUE >= 1 AND VALUE <= 99.99);
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMENT ON DOMAIN role_level IS 'Learn-IQ seniority level: 1=Top Authority, 99.99=Lowest. Approvers must have LOWER number than initiators.';

-- Percentage domain (0-100)
DO $$ BEGIN
    CREATE DOMAIN percentage AS NUMERIC(5,2)
        CHECK (VALUE >= 0 AND VALUE <= 100);
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Positive integer
DO $$ BEGIN
    CREATE DOMAIN positive_int AS INTEGER
        CHECK (VALUE > 0);
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Non-negative integer
DO $$ BEGIN
    CREATE DOMAIN non_negative_int AS INTEGER
        CHECK (VALUE >= 0);
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- SHA-256 hash format
DO $$ BEGIN
    CREATE DOMAIN integrity_hash AS TEXT
        CHECK (VALUE ~ '^[a-f0-9]{64}$');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMENT ON DOMAIN integrity_hash IS '21 CFR Part 11: SHA-256 integrity verification hash';

-- Email format
DO $$ BEGIN
    CREATE DOMAIN email_address AS TEXT
        CHECK (VALUE ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Unique code format (alphanumeric with allowed special chars)
DO $$ BEGIN
    CREATE DOMAIN unique_code AS TEXT
        CHECK (VALUE ~ '^[A-Za-z0-9_-]{2,50}$');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
