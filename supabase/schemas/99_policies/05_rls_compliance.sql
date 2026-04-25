-- ===========================================
-- RLS POLICIES FOR COMPLIANCE & IDENTITY
-- Phase 3: Identity, sessions, and compliance security
-- ===========================================

-- -------------------------------------------------------
-- USER CREDENTIALS (highly restricted)
-- -------------------------------------------------------
ALTER TABLE user_credentials ENABLE ROW LEVEL SECURITY;

-- Users can only see their own credentials (for password change)
CREATE POLICY user_credentials_select ON user_credentials
    FOR SELECT USING (
        employee_id = get_user_employee_id()
        OR is_admin()
    );

-- Only system/admin can insert credentials
CREATE POLICY user_credentials_insert ON user_credentials
    FOR INSERT WITH CHECK (is_admin());

-- Users can update only their own credentials (password change)
CREATE POLICY user_credentials_update ON user_credentials
    FOR UPDATE USING (
        employee_id = get_user_employee_id()
        OR is_admin()
    );

-- No deletion allowed
CREATE POLICY user_credentials_delete ON user_credentials
    FOR DELETE USING (FALSE);

-- -------------------------------------------------------
-- USER SESSIONS
-- -------------------------------------------------------
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- Users can see their own sessions; admins can see all
CREATE POLICY user_sessions_select ON user_sessions
    FOR SELECT USING (
        employee_id = get_user_employee_id()
        OR is_admin()
    );

CREATE POLICY user_sessions_insert ON user_sessions
    FOR INSERT WITH CHECK (
        employee_id = get_user_employee_id()
        OR is_admin()
    );

CREATE POLICY user_sessions_update ON user_sessions
    FOR UPDATE USING (
        employee_id = get_user_employee_id()
        OR is_admin()
    );

-- -------------------------------------------------------
-- SSO CONFIGURATIONS
-- -------------------------------------------------------
ALTER TABLE sso_configurations ENABLE ROW LEVEL SECURITY;

CREATE POLICY sso_configurations_select ON sso_configurations
    FOR SELECT USING (
        organization_id = get_user_organization_id()
    );

CREATE POLICY sso_configurations_insert ON sso_configurations
    FOR INSERT WITH CHECK (
        organization_id = get_user_organization_id()
        AND can_manage_config()
    );

CREATE POLICY sso_configurations_update ON sso_configurations
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND can_manage_config()
    );

-- -------------------------------------------------------
-- OPERATIONAL DELEGATIONS
-- -------------------------------------------------------
ALTER TABLE operational_delegations ENABLE ROW LEVEL SECURITY;

CREATE POLICY operational_delegations_select ON operational_delegations
    FOR SELECT USING (
        organization_id = get_user_organization_id()
    );

CREATE POLICY operational_delegations_insert ON operational_delegations
    FOR INSERT WITH CHECK (
        organization_id = get_user_organization_id()
    );

CREATE POLICY operational_delegations_update ON operational_delegations
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
    );

-- -------------------------------------------------------
-- TRAINING COORDINATOR ASSIGNMENTS
-- -------------------------------------------------------
ALTER TABLE training_coordinator_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY tca_select ON training_coordinator_assignments
    FOR SELECT USING (
        organization_id = get_user_organization_id()
    );

CREATE POLICY tca_insert ON training_coordinator_assignments
    FOR INSERT WITH CHECK (
        organization_id = get_user_organization_id()
        AND is_admin()
    );

CREATE POLICY tca_update ON training_coordinator_assignments
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND is_admin()
    );

-- -------------------------------------------------------
-- CONSENT RECORDS
-- -------------------------------------------------------
ALTER TABLE consent_records ENABLE ROW LEVEL SECURITY;

-- Users can see their own consent records
CREATE POLICY consent_records_select ON consent_records
    FOR SELECT USING (
        employee_id = get_user_employee_id()
        OR is_admin()
    );

CREATE POLICY consent_records_insert ON consent_records
    FOR INSERT WITH CHECK (
        employee_id = get_user_employee_id()
        OR is_admin()
    );

-- Consent can only be updated to withdraw
CREATE POLICY consent_records_update ON consent_records
    FOR UPDATE USING (
        employee_id = get_user_employee_id()
    );

-- -------------------------------------------------------
-- CERTIFICATES
-- -------------------------------------------------------
ALTER TABLE certificates ENABLE ROW LEVEL SECURITY;

-- Users can see their own certificates; supervisors can see their reports
CREATE POLICY certificates_select ON certificates
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND (
            employee_id = get_user_employee_id()
            OR is_admin()
            OR EXISTS (
                SELECT 1 FROM employees e
                WHERE e.id = certificates.employee_id
                  AND e.reporting_to = get_user_employee_id()
            )
        )
    );

CREATE POLICY certificates_insert ON certificates
    FOR INSERT WITH CHECK (
        organization_id = get_user_organization_id()
    );

-- Certificate updates (e.g., revocation) require two-person authorization
-- This is enforced by the CHECK constraint on the table, not RLS
CREATE POLICY certificates_update ON certificates
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND is_admin()
    );

-- -------------------------------------------------------
-- DATA ARCHIVES
-- -------------------------------------------------------
ALTER TABLE data_archives ENABLE ROW LEVEL SECURITY;

CREATE POLICY data_archives_select ON data_archives
    FOR SELECT USING (
        organization_id IS NULL
        OR organization_id = get_user_organization_id()
    );

CREATE POLICY data_archives_insert ON data_archives
    FOR INSERT WITH CHECK (is_admin());

-- Archives are immutable
CREATE POLICY data_archives_update ON data_archives
    FOR UPDATE USING (FALSE);

CREATE POLICY data_archives_delete ON data_archives
    FOR DELETE USING (FALSE);

-- -------------------------------------------------------
-- ARCHIVE JOBS
-- -------------------------------------------------------
ALTER TABLE archive_jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY archive_jobs_select ON archive_jobs
    FOR SELECT USING (
        organization_id IS NULL
        OR organization_id = get_user_organization_id()
    );

CREATE POLICY archive_jobs_insert ON archive_jobs
    FOR INSERT WITH CHECK (is_admin());

CREATE POLICY archive_jobs_update ON archive_jobs
    FOR UPDATE USING (is_admin());

-- -------------------------------------------------------
-- LEGAL HOLDS
-- -------------------------------------------------------
ALTER TABLE legal_holds ENABLE ROW LEVEL SECURITY;

CREATE POLICY legal_holds_select ON legal_holds
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND is_admin()
    );

CREATE POLICY legal_holds_insert ON legal_holds
    FOR INSERT WITH CHECK (
        organization_id = get_user_organization_id()
        AND is_admin()
    );

CREATE POLICY legal_holds_update ON legal_holds
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND is_admin()
    );

-- -------------------------------------------------------
-- DOCUMENT READINGS
-- -------------------------------------------------------
ALTER TABLE document_readings ENABLE ROW LEVEL SECURITY;

CREATE POLICY document_readings_select ON document_readings
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND (
            employee_id = get_user_employee_id()
            OR is_admin()
            OR EXISTS (
                SELECT 1 FROM employees e
                WHERE e.id = document_readings.employee_id
                  AND e.reporting_to = get_user_employee_id()
            )
        )
    );

CREATE POLICY document_readings_insert ON document_readings
    FOR INSERT WITH CHECK (
        organization_id = get_user_organization_id()
    );

CREATE POLICY document_readings_update ON document_readings
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND (
            employee_id = get_user_employee_id()
            OR is_admin()
        )
    );

-- -------------------------------------------------------
-- INDUCTION GATE POLICY FOR TRAINING SESSIONS
-- Users with incomplete induction see only induction sessions
-- -------------------------------------------------------
DO $$
BEGIN
    -- Drop existing policy if it exists
    DROP POLICY IF EXISTS training_sessions_induction_gate ON training_sessions;
END
$$;

CREATE POLICY training_sessions_induction_gate ON training_sessions
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND (
            -- Admin bypass
            is_admin()
            -- User has completed induction - see all
            OR induction_completed()
            -- User hasn't completed induction - see only induction sessions
            OR EXISTS (
                SELECT 1 FROM induction_modules im
                JOIN induction_programs ip ON im.program_id = ip.id
                JOIN courses c ON c.id = im.course_id
                WHERE c.id = training_sessions.course_id
            )
        )
    );

COMMENT ON POLICY training_sessions_induction_gate ON training_sessions
    IS 'Induction gate: users with incomplete induction see only induction-related sessions';
