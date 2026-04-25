-- ===========================================
-- EMPLOYEE ROLES TABLE
-- Links employees to their roles
-- ===========================================

CREATE TABLE IF NOT EXISTS employee_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    
    -- Assignment details
    is_primary BOOLEAN DEFAULT false, -- Primary role for the employee
    
    -- Validity period
    valid_from DATE DEFAULT CURRENT_DATE,
    valid_until DATE, -- NULL means indefinite
    
    -- Assignment tracking
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    assigned_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    assigned_reason TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(employee_id, role_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_employee_roles_employee ON employee_roles(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_roles_role ON employee_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_employee_roles_active ON employee_roles(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_employee_roles_primary ON employee_roles(employee_id, is_primary) WHERE is_primary = true;
CREATE INDEX IF NOT EXISTS idx_employee_roles_validity ON employee_roles(valid_from, valid_until);

-- Ensure only one primary role per employee
CREATE UNIQUE INDEX IF NOT EXISTS idx_employee_roles_unique_primary 
    ON employee_roles(employee_id) 
    WHERE is_primary = true AND is_active = true;

-- Triggers
DROP TRIGGER IF EXISTS trg_employee_roles_audit ON employee_roles;
CREATE TRIGGER trg_employee_roles_audit
    AFTER INSERT OR UPDATE OR DELETE ON employee_roles
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Function to get employee's lowest (highest authority) role level
CREATE OR REPLACE FUNCTION get_employee_role_level(p_employee_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_level NUMERIC(5,2);
BEGIN
    SELECT MIN(r.level) INTO v_level
    FROM employee_roles er
    JOIN roles r ON r.id = er.role_id
    WHERE er.employee_id = p_employee_id
      AND er.is_active = true
      AND r.is_active = true
      AND (er.valid_from IS NULL OR er.valid_from <= CURRENT_DATE)
      AND (er.valid_until IS NULL OR er.valid_until >= CURRENT_DATE);
    
    -- Default to lowest level if no active role
    RETURN COALESCE(v_level, 99.99);
END;
$$ LANGUAGE plpgsql;

-- Function to get employee's roles
CREATE OR REPLACE FUNCTION get_employee_roles(p_employee_id UUID)
RETURNS TABLE (
    role_id UUID,
    role_name TEXT,
    role_level NUMERIC,
    is_primary BOOLEAN,
    category role_category
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.name,
        r.level,
        er.is_primary,
        r.category
    FROM employee_roles er
    JOIN roles r ON r.id = er.role_id
    WHERE er.employee_id = p_employee_id
      AND er.is_active = true
      AND r.is_active = true
      AND (er.valid_from IS NULL OR er.valid_from <= CURRENT_DATE)
      AND (er.valid_until IS NULL OR er.valid_until >= CURRENT_DATE)
    ORDER BY r.level, r.name;
END;
$$ LANGUAGE plpgsql;

-- Function to assign role to employee
CREATE OR REPLACE FUNCTION assign_role_to_employee(
    p_employee_id UUID,
    p_role_id UUID,
    p_is_primary BOOLEAN DEFAULT false,
    p_valid_from DATE DEFAULT CURRENT_DATE,
    p_valid_until DATE DEFAULT NULL,
    p_reason TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
    v_current_user UUID;
BEGIN
    v_current_user := get_current_user_id();
    
    -- If setting as primary, unset other primary roles
    IF p_is_primary THEN
        UPDATE employee_roles
        SET is_primary = false, updated_at = NOW()
        WHERE employee_id = p_employee_id
          AND is_primary = true
          AND is_active = true;
    END IF;
    
    -- Insert or update role assignment
    INSERT INTO employee_roles (
        employee_id, role_id, is_primary,
        valid_from, valid_until,
        assigned_by, assigned_reason
    ) VALUES (
        p_employee_id, p_role_id, p_is_primary,
        p_valid_from, p_valid_until,
        v_current_user, p_reason
    )
    ON CONFLICT (employee_id, role_id) DO UPDATE SET
        is_primary = EXCLUDED.is_primary,
        valid_from = EXCLUDED.valid_from,
        valid_until = EXCLUDED.valid_until,
        is_active = true,
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE employee_roles IS 'Employee to role assignments with validity periods';
COMMENT ON COLUMN employee_roles.is_primary IS 'Primary role used for approval level determination';
