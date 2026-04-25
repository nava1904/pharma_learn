-- ===========================================
-- EMPLOYEES TABLE
-- All users in the system (login and non-login)
-- ===========================================

CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_user_id UUID UNIQUE, -- Supabase auth.users reference (NULL for non-login users)
    
    -- Organization context
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id) ON DELETE SET NULL,
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    
    -- Identification
    employee_id TEXT NOT NULL, -- Business employee ID (e.g., EMP001)
    -- 21 CFR §11.100(b): each individual must have a unique, permanent username
    -- Once set, this CANNOT be changed (enforced by trg_employee_username_immutable trigger)
    username TEXT UNIQUE,
    email TEXT,
    
    -- Personal info
    title TEXT, -- Mr., Mrs., Dr., etc.
    first_name TEXT NOT NULL,
    middle_name TEXT,
    last_name TEXT NOT NULL,
    preferred_name TEXT,
    
    -- Employment details
    designation TEXT,
    job_title TEXT,
    hire_date DATE,
    confirmation_date DATE,
    termination_date DATE,
    employee_type TEXT DEFAULT 'permanent' CHECK (employee_type IN ('permanent', 'contract', 'temporary', 'intern', 'consultant')),
    
    -- Hierarchy (Learn-IQ)
    reporting_to UUID REFERENCES employees(id) ON DELETE SET NULL,
    authorized_deputy UUID REFERENCES employees(id) ON DELETE SET NULL,
    
    -- Contact
    phone TEXT,
    mobile TEXT,
    personal_email TEXT,
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    
    -- Address
    address_line1 TEXT,
    address_line2 TEXT,
    city TEXT,
    state TEXT,
    country TEXT,
    postal_code TEXT,
    
    -- Documents
    photo_url TEXT,
    id_proof_type TEXT,
    id_proof_number TEXT,
    
    -- Authentication status (for login users)
    status employee_status DEFAULT 'active',
    mfa_enabled BOOLEAN DEFAULT false,
    mfa_method TEXT, -- 'totp', 'email', 'sms'
    last_login TIMESTAMPTZ,
    last_ip_address INET,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    password_changed_at TIMESTAMPTZ,
    must_change_password BOOLEAN DEFAULT false,

    -- Induction gating (DB-enforced)
    induction_completed BOOLEAN NOT NULL DEFAULT false,
    induction_completed_at TIMESTAMPTZ,
    
    -- Compliance metrics (calculated)
    compliance_percent NUMERIC(5,2) DEFAULT 0,
    training_due_count INTEGER DEFAULT 0,
    overdue_training_count INTEGER DEFAULT 0,
    last_compliance_calculation TIMESTAMPTZ,
    
    -- Qualifications (for trainers)
    qualification TEXT,
    experience_years NUMERIC(4,1),
    specializations TEXT[],
    
    -- Workflow (Learn-IQ)
    workflow_status workflow_state DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    
    -- Constraints
    UNIQUE(organization_id, employee_id),
    UNIQUE(organization_id, email)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_employees_org ON employees(organization_id);
CREATE INDEX IF NOT EXISTS idx_employees_plant ON employees(plant_id);
CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department_id);
CREATE INDEX IF NOT EXISTS idx_employees_auth_user ON employees(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_employees_reporting_to ON employees(reporting_to);
CREATE INDEX IF NOT EXISTS idx_employees_status ON employees(status);
CREATE INDEX IF NOT EXISTS idx_employees_workflow ON employees(workflow_status);
CREATE INDEX IF NOT EXISTS idx_employees_email ON employees(email);
CREATE INDEX IF NOT EXISTS idx_employees_active ON employees(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_employees_compliance ON employees(compliance_percent);

-- Full name search
CREATE INDEX IF NOT EXISTS idx_employees_name_search ON employees 
    USING GIN ((first_name || ' ' || COALESCE(middle_name, '') || ' ' || last_name) gin_trgm_ops);

-- Triggers
DROP TRIGGER IF EXISTS trg_employees_revision ON employees;
CREATE TRIGGER trg_employees_revision
    BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_employees_audit ON employees;
CREATE TRIGGER trg_employees_audit
    AFTER INSERT OR UPDATE OR DELETE ON employees
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

DROP TRIGGER IF EXISTS trg_employees_created ON employees;
CREATE TRIGGER trg_employees_created
    BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION set_created_by();

-- Add FK to departments for head
ALTER TABLE departments 
    ADD CONSTRAINT IF NOT EXISTS fk_departments_head 
    FOREIGN KEY (head_employee_id) REFERENCES employees(id) ON DELETE SET NULL;

-- Function to get employee full name
CREATE OR REPLACE FUNCTION get_employee_full_name(p_employee_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_name TEXT;
BEGIN
    SELECT 
        TRIM(CONCAT(
            COALESCE(first_name, ''), ' ',
            COALESCE(middle_name, ''), ' ',
            COALESCE(last_name, '')
        ))
    INTO v_name
    FROM employees
    WHERE id = p_employee_id;
    
    RETURN v_name;
END;
$$ LANGUAGE plpgsql;

-- Function to get direct reports
CREATE OR REPLACE FUNCTION get_direct_reports(p_manager_id UUID)
RETURNS TABLE (
    employee_id UUID,
    employee_code TEXT,
    full_name TEXT,
    designation TEXT,
    department_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.employee_id,
        get_employee_full_name(e.id),
        e.designation,
        d.name
    FROM employees e
    LEFT JOIN departments d ON d.id = e.department_id
    WHERE e.reporting_to = p_manager_id
      AND e.status = 'active'
    ORDER BY e.first_name, e.last_name;
END;
$$ LANGUAGE plpgsql;

-- Function to get reporting chain (hierarchy upward)
CREATE OR REPLACE FUNCTION get_reporting_chain(p_employee_id UUID)
RETURNS TABLE (
    level INTEGER,
    employee_id UUID,
    employee_code TEXT,
    full_name TEXT,
    designation TEXT,
    role_level NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE chain AS (
        SELECT 
            1 as lvl,
            e.id,
            e.employee_id,
            get_employee_full_name(e.id) as full_name,
            e.designation,
            MIN(r.level) as role_level
        FROM employees e
        LEFT JOIN employee_roles er ON er.employee_id = e.id
        LEFT JOIN roles r ON r.id = er.role_id AND r.is_active = true
        WHERE e.id = p_employee_id
        GROUP BY e.id, e.employee_id, e.designation
        
        UNION ALL
        
        SELECT 
            c.lvl + 1,
            e.id,
            e.employee_id,
            get_employee_full_name(e.id),
            e.designation,
            MIN(r.level)
        FROM employees e
        INNER JOIN chain c ON e.id = (SELECT reporting_to FROM employees WHERE id = c.id)
        LEFT JOIN employee_roles er ON er.employee_id = e.id
        LEFT JOIN roles r ON r.id = er.role_id AND r.is_active = true
        WHERE e.id IS NOT NULL
        GROUP BY c.lvl, e.id, e.employee_id, e.designation
    )
    SELECT * FROM chain ORDER BY lvl;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE  employees IS 'All users in the system, both login and non-login';
COMMENT ON COLUMN employees.auth_user_id IS 'Supabase auth UID - NULL for non-login (biometric-only) users';
COMMENT ON COLUMN employees.compliance_percent IS 'Calculated training compliance percentage';
COMMENT ON COLUMN employees.authorized_deputy IS 'Learn-IQ: Person who can act on behalf of this employee';
COMMENT ON COLUMN employees.username IS '21 CFR §11.100(b): permanent unique identifier — cannot be changed after first assignment';

-- -------------------------------------------------------
-- 21 CFR §11.100(b) — Username immutability
-- Once a username is assigned, it cannot be changed.
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION employee_username_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.username IS NOT NULL AND NEW.username IS DISTINCT FROM OLD.username THEN
        RAISE EXCEPTION
            'Employee username cannot be changed after it is set. '
            '(21 CFR Part 11 §11.100(b) — unique user identity is permanent)';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_employee_username_immutable ON employees;
CREATE TRIGGER trg_employee_username_immutable
    BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION employee_username_immutable();

-- -------------------------------------------------------
-- ALTER: idempotent column addition for existing databases
-- -------------------------------------------------------
ALTER TABLE employees ADD COLUMN IF NOT EXISTS username TEXT UNIQUE;
