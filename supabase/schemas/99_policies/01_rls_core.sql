-- ===========================================
-- ROW LEVEL SECURITY POLICIES
-- ===========================================

-- Enable RLS on all tables
DO $$
DECLARE
    tbl RECORD;
BEGIN
    FOR tbl IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename NOT LIKE 'pg_%'
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl.tablename);
    END LOOP;
END $$;

-- Helper function to get user's organization
CREATE OR REPLACE FUNCTION get_user_organization_id()
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT organization_id 
        FROM employees 
        WHERE auth_user_id = auth.uid()
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Helper function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM employee_roles er
        JOIN roles r ON er.role_id = r.id
        JOIN employees e ON er.employee_id = e.id
        WHERE e.auth_user_id = auth.uid()
        AND r.level <= 10
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Helper function to get user's employee ID
CREATE OR REPLACE FUNCTION get_user_employee_id()
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT id 
        FROM employees 
        WHERE auth_user_id = auth.uid()
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Helper: induction completion status for current user
CREATE OR REPLACE FUNCTION induction_completed()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN COALESCE(
        (SELECT induction_completed FROM employees WHERE id = get_user_employee_id()),
        false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ===========================================
-- ORGANIZATION POLICIES
-- ===========================================

-- Organizations: Users can only see their own organization
CREATE POLICY organizations_select ON organizations
    FOR SELECT USING (id = get_user_organization_id());

CREATE POLICY organizations_insert ON organizations
    FOR INSERT WITH CHECK (is_admin());

CREATE POLICY organizations_update ON organizations
    FOR UPDATE USING (id = get_user_organization_id() AND is_admin());

-- ===========================================
-- EMPLOYEE POLICIES
-- ===========================================

-- Employees: Users can see employees in their organization
CREATE POLICY employees_select ON employees
    FOR SELECT USING (organization_id = get_user_organization_id());

CREATE POLICY employees_insert ON employees
    FOR INSERT WITH CHECK (organization_id = get_user_organization_id() AND is_admin());

CREATE POLICY employees_update ON employees
    FOR UPDATE USING (organization_id = get_user_organization_id() AND is_admin());

-- ===========================================
-- COURSE POLICIES
-- ===========================================

-- Courses: Users can see active courses in their organization
CREATE POLICY courses_select ON courses
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND (status = 'active' OR is_admin())
    );

CREATE POLICY courses_insert ON courses
    FOR INSERT WITH CHECK (organization_id = get_user_organization_id() AND is_admin());

CREATE POLICY courses_update ON courses
    FOR UPDATE USING (organization_id = get_user_organization_id() AND is_admin());

-- ===========================================
-- TRAINING RECORD POLICIES
-- ===========================================

-- Training Records: Users can see their own records, admins can see all
CREATE POLICY training_records_select ON training_records
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND (employee_id = get_user_employee_id() OR is_admin())
    );

CREATE POLICY training_records_insert ON training_records
    FOR INSERT WITH CHECK (organization_id = get_user_organization_id() AND is_admin());

CREATE POLICY training_records_update ON training_records
    FOR UPDATE USING (organization_id = get_user_organization_id() AND is_admin());

-- ===========================================
-- DOCUMENT POLICIES
-- ===========================================

CREATE POLICY documents_select ON documents
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND (status = 'active' OR is_admin())
    );

CREATE POLICY documents_insert ON documents
    FOR INSERT WITH CHECK (organization_id = get_user_organization_id() AND is_admin());

CREATE POLICY documents_update ON documents
    FOR UPDATE USING (organization_id = get_user_organization_id() AND is_admin());
