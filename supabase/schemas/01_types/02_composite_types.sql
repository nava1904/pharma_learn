-- ===========================================
-- COMPOSITE TYPES
-- Complex data structures for Pharma LMS
-- ===========================================

-- Address composite type
DO $$ BEGIN
    CREATE TYPE address_info AS (
        address_line_1 TEXT,
        address_line_2 TEXT,
        city TEXT,
        state TEXT,
        country TEXT,
        postal_code TEXT
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Contact composite type
DO $$ BEGIN
    CREATE TYPE contact_info AS (
        phone TEXT,
        mobile TEXT,
        email TEXT,
        fax TEXT
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Audit metadata composite type
DO $$ BEGIN
    CREATE TYPE audit_metadata AS (
        created_at TIMESTAMPTZ,
        created_by UUID,
        updated_at TIMESTAMPTZ,
        updated_by UUID,
        revision_no INTEGER
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Training completion summary
DO $$ BEGIN
    CREATE TYPE completion_summary AS (
        total_assigned INTEGER,
        completed INTEGER,
        in_progress INTEGER,
        overdue INTEGER,
        compliance_rate NUMERIC(5,2)
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Assessment score summary
DO $$ BEGIN
    CREATE TYPE score_summary AS (
        total_marks NUMERIC(7,2),
        obtained_marks NUMERIC(7,2),
        percentage NUMERIC(5,2),
        result TEXT,
        attempt_number INTEGER
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
