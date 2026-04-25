-- ===========================================
-- AUDIT AND COMPLIANCE POLICIES
-- ===========================================

-- Audit trails are immutable - no updates or deletes
CREATE POLICY audit_trails_select ON audit_trails
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND is_admin()
    );

CREATE POLICY audit_trails_insert ON audit_trails
    FOR INSERT WITH CHECK (organization_id = get_user_organization_id());

-- Revisions are immutable
CREATE POLICY revisions_select ON revisions
    FOR SELECT USING (is_admin());

CREATE POLICY revisions_insert ON revisions
    FOR INSERT WITH CHECK (true);

-- Electronic Signatures
CREATE POLICY esignatures_select ON electronic_signatures
    FOR SELECT USING (
        (employee_id = get_user_employee_id())
        OR is_admin()
    );

CREATE POLICY esignatures_insert ON electronic_signatures
    FOR INSERT WITH CHECK (
        employee_id = get_user_employee_id()
    );

-- Login Audit Trail - admins only
CREATE POLICY login_audit_select ON login_audit_trail
    FOR SELECT USING (is_admin());

-- Security Audit Trail - admins only
CREATE POLICY security_audit_select ON security_audit_trail
    FOR SELECT USING (is_admin());

-- Compliance Reports
CREATE POLICY compliance_reports_select ON compliance_reports
    FOR SELECT USING (organization_id = get_user_organization_id() AND is_admin());

-- Training Waivers
CREATE POLICY waivers_select ON training_waivers
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND (employee_id = get_user_employee_id() OR is_admin())
    );

CREATE POLICY waivers_insert ON training_waivers
    FOR INSERT WITH CHECK (organization_id = get_user_organization_id());

CREATE POLICY waivers_update ON training_waivers
    FOR UPDATE USING (organization_id = get_user_organization_id() AND is_admin());

-- ===========================================
-- NOTIFICATION POLICIES
-- ===========================================

-- User Notifications
CREATE POLICY user_notifications_select ON user_notifications
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY user_notifications_update ON user_notifications
    FOR UPDATE USING (user_id = auth.uid());

-- Notification Preferences
CREATE POLICY notification_prefs_select ON notification_preferences
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY notification_prefs_insert ON notification_preferences
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY notification_prefs_update ON notification_preferences
    FOR UPDATE USING (user_id = auth.uid());

-- ===========================================
-- WORKFLOW POLICIES
-- ===========================================

-- Workflow Tasks - assigned user or admin
CREATE POLICY workflow_tasks_select ON workflow_tasks
    FOR SELECT USING (
        assigned_to = get_user_employee_id() 
        OR delegated_to = get_user_employee_id()
        OR is_admin()
    );

CREATE POLICY workflow_tasks_update ON workflow_tasks
    FOR UPDATE USING (
        assigned_to = get_user_employee_id() 
        OR delegated_to = get_user_employee_id()
        OR is_admin()
    );

-- Pending Approvals
CREATE POLICY pending_approvals_select ON pending_approvals
    FOR SELECT USING (
        approver_id = get_user_employee_id() OR is_admin()
    );

CREATE POLICY pending_approvals_update ON pending_approvals
    FOR UPDATE USING (
        approver_id = get_user_employee_id() OR is_admin()
    );
