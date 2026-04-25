-- ===========================================
-- EMPLOYEE SUBGROUPS TABLE
-- Links employees to their subgroups
-- ===========================================

CREATE TABLE IF NOT EXISTS employee_subgroups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    subgroup_id UUID NOT NULL REFERENCES subgroups(id) ON DELETE CASCADE,
    
    -- Assignment details
    is_primary BOOLEAN DEFAULT false, -- Primary subgroup for the employee
    
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
    UNIQUE(employee_id, subgroup_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_employee_subgroups_employee ON employee_subgroups(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_subgroups_subgroup ON employee_subgroups(subgroup_id);
CREATE INDEX IF NOT EXISTS idx_employee_subgroups_active ON employee_subgroups(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_employee_subgroups_primary ON employee_subgroups(employee_id, is_primary) WHERE is_primary = true;

-- Ensure only one primary subgroup per employee
CREATE UNIQUE INDEX IF NOT EXISTS idx_employee_subgroups_unique_primary 
    ON employee_subgroups(employee_id) 
    WHERE is_primary = true AND is_active = true;

-- Triggers
DROP TRIGGER IF EXISTS trg_employee_subgroups_audit ON employee_subgroups;
CREATE TRIGGER trg_employee_subgroups_audit
    AFTER INSERT OR UPDATE OR DELETE ON employee_subgroups
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Function to get employee's subgroups
CREATE OR REPLACE FUNCTION get_employee_subgroups(p_employee_id UUID)
RETURNS TABLE (
    subgroup_id UUID,
    subgroup_name TEXT,
    subgroup_code TEXT,
    is_primary BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.name,
        s.unique_code,
        es.is_primary
    FROM employee_subgroups es
    JOIN subgroups s ON s.id = es.subgroup_id
    WHERE es.employee_id = p_employee_id
      AND es.is_active = true
      AND s.is_active = true
      AND (es.valid_from IS NULL OR es.valid_from <= CURRENT_DATE)
      AND (es.valid_until IS NULL OR es.valid_until >= CURRENT_DATE)
    ORDER BY es.is_primary DESC, s.name;
END;
$$ LANGUAGE plpgsql;

-- Function to get employees in a subgroup
CREATE OR REPLACE FUNCTION get_subgroup_employees(p_subgroup_id UUID)
RETURNS TABLE (
    employee_id UUID,
    employee_code TEXT,
    full_name TEXT,
    designation TEXT,
    is_primary BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.employee_id,
        get_employee_full_name(e.id),
        e.designation,
        es.is_primary
    FROM employee_subgroups es
    JOIN employees e ON e.id = es.employee_id
    WHERE es.subgroup_id = p_subgroup_id
      AND es.is_active = true
      AND e.status = 'active'
      AND (es.valid_from IS NULL OR es.valid_from <= CURRENT_DATE)
      AND (es.valid_until IS NULL OR es.valid_until >= CURRENT_DATE)
    ORDER BY e.first_name, e.last_name;
END;
$$ LANGUAGE plpgsql;

-- Function to assign subgroup to employee
CREATE OR REPLACE FUNCTION assign_subgroup_to_employee(
    p_employee_id UUID,
    p_subgroup_id UUID,
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
    
    -- If setting as primary, unset other primary subgroups
    IF p_is_primary THEN
        UPDATE employee_subgroups
        SET is_primary = false, updated_at = NOW()
        WHERE employee_id = p_employee_id
          AND is_primary = true
          AND is_active = true;
    END IF;
    
    -- Insert or update subgroup assignment
    INSERT INTO employee_subgroups (
        employee_id, subgroup_id, is_primary,
        valid_from, valid_until,
        assigned_by, assigned_reason
    ) VALUES (
        p_employee_id, p_subgroup_id, p_is_primary,
        p_valid_from, p_valid_until,
        v_current_user, p_reason
    )
    ON CONFLICT (employee_id, subgroup_id) DO UPDATE SET
        is_primary = EXCLUDED.is_primary,
        valid_from = EXCLUDED.valid_from,
        valid_until = EXCLUDED.valid_until,
        is_active = true,
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE employee_subgroups IS 'Employee to subgroup assignments for training assignment';
COMMENT ON COLUMN employee_subgroups.is_primary IS 'Primary subgroup used for job responsibility and training matrix';
