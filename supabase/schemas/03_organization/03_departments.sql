-- ===========================================
-- DEPARTMENTS TABLE
-- Organizational departments
-- Created in Master plant, shared across org
-- ===========================================

CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id) ON DELETE SET NULL, -- NULL = global (from master)
    
    -- Basic info
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    short_name TEXT,
    description TEXT,
    
    -- Hierarchy
    parent_department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    hierarchy_level INTEGER DEFAULT 1,
    hierarchy_path TEXT[], -- Array of parent IDs for easy querying
    
    -- Head/Manager
    head_employee_id UUID, -- FK added after employees table created
    
    -- Contact
    email TEXT,
    phone TEXT,
    location TEXT,
    
    -- Cost center
    cost_center_code TEXT,
    
    -- Workflow (Learn-IQ)
    status workflow_state DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    
    -- Constraints
    UNIQUE(organization_id, unique_code)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_departments_org ON departments(organization_id);
CREATE INDEX IF NOT EXISTS idx_departments_plant ON departments(plant_id);
CREATE INDEX IF NOT EXISTS idx_departments_parent ON departments(parent_department_id);
CREATE INDEX IF NOT EXISTS idx_departments_status ON departments(status);
CREATE INDEX IF NOT EXISTS idx_departments_active ON departments(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_departments_hierarchy ON departments USING GIN(hierarchy_path);

-- Triggers
DROP TRIGGER IF EXISTS trg_departments_revision ON departments;
CREATE TRIGGER trg_departments_revision
    BEFORE UPDATE ON departments
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_departments_audit ON departments;
CREATE TRIGGER trg_departments_audit
    AFTER INSERT OR UPDATE OR DELETE ON departments
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

DROP TRIGGER IF EXISTS trg_departments_created ON departments;
CREATE TRIGGER trg_departments_created
    BEFORE INSERT ON departments
    FOR EACH ROW EXECUTE FUNCTION set_created_by();

-- Function to update hierarchy path
CREATE OR REPLACE FUNCTION update_department_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
    v_parent_path TEXT[];
BEGIN
    IF NEW.parent_department_id IS NULL THEN
        NEW.hierarchy_path := ARRAY[NEW.id::TEXT];
        NEW.hierarchy_level := 1;
    ELSE
        SELECT hierarchy_path INTO v_parent_path
        FROM departments
        WHERE id = NEW.parent_department_id;
        
        NEW.hierarchy_path := array_append(v_parent_path, NEW.id::TEXT);
        NEW.hierarchy_level := array_length(NEW.hierarchy_path, 1);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_departments_hierarchy ON departments;
CREATE TRIGGER trg_departments_hierarchy
    BEFORE INSERT OR UPDATE OF parent_department_id ON departments
    FOR EACH ROW EXECUTE FUNCTION update_department_hierarchy();

-- Function to get department tree
CREATE OR REPLACE FUNCTION get_department_tree(p_org_id UUID, p_parent_id UUID DEFAULT NULL)
RETURNS TABLE (
    id UUID,
    name TEXT,
    unique_code TEXT,
    parent_department_id UUID,
    hierarchy_level INTEGER,
    children_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE dept_tree AS (
        SELECT 
            d.id,
            d.name,
            d.unique_code,
            d.parent_department_id,
            d.hierarchy_level
        FROM departments d
        WHERE d.organization_id = p_org_id
          AND (
              (p_parent_id IS NULL AND d.parent_department_id IS NULL) OR
              (d.parent_department_id = p_parent_id)
          )
          AND d.is_active = true
        
        UNION ALL
        
        SELECT 
            d.id,
            d.name,
            d.unique_code,
            d.parent_department_id,
            d.hierarchy_level
        FROM departments d
        INNER JOIN dept_tree dt ON d.parent_department_id = dt.id
        WHERE d.is_active = true
    )
    SELECT 
        dt.id,
        dt.name,
        dt.unique_code,
        dt.parent_department_id,
        dt.hierarchy_level,
        (SELECT COUNT(*) FROM departments c WHERE c.parent_department_id = dt.id AND c.is_active = true)
    FROM dept_tree dt
    ORDER BY dt.hierarchy_level, dt.name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE departments IS 'Organizational departments, can be global or plant-specific';
COMMENT ON COLUMN departments.plant_id IS 'NULL means global department (created in master plant, shared across org)';
