-- ===========================================
-- TRAINING AND ASSESSMENT POLICIES
-- ===========================================

-- Training Schedules
CREATE POLICY schedules_select ON training_schedules
    FOR SELECT USING (organization_id = get_user_organization_id());

CREATE POLICY schedules_insert ON training_schedules
    FOR INSERT WITH CHECK (organization_id = get_user_organization_id() AND is_admin());

CREATE POLICY schedules_update ON training_schedules
    FOR UPDATE USING (organization_id = get_user_organization_id() AND is_admin());

-- GTP Masters
CREATE POLICY gtp_select ON gtp_masters
    FOR SELECT USING (organization_id = get_user_organization_id());

CREATE POLICY gtp_insert ON gtp_masters
    FOR INSERT WITH CHECK (organization_id = get_user_organization_id() AND is_admin());

CREATE POLICY gtp_update ON gtp_masters
    FOR UPDATE USING (organization_id = get_user_organization_id() AND is_admin());

-- Question Banks
CREATE POLICY qbanks_select ON question_banks
    FOR SELECT USING (organization_id = get_user_organization_id());

CREATE POLICY qbanks_insert ON question_banks
    FOR INSERT WITH CHECK (organization_id = get_user_organization_id() AND is_admin());

CREATE POLICY qbanks_update ON question_banks
    FOR UPDATE USING (organization_id = get_user_organization_id() AND is_admin());

-- Question Papers
CREATE POLICY qpapers_select ON question_papers
    FOR SELECT USING (organization_id = get_user_organization_id());

CREATE POLICY qpapers_insert ON question_papers
    FOR INSERT WITH CHECK (organization_id = get_user_organization_id() AND is_admin());

CREATE POLICY qpapers_update ON question_papers
    FOR UPDATE USING (organization_id = get_user_organization_id() AND is_admin());

-- Assessment Attempts: Users can see their own, admins can see all
CREATE POLICY attempts_select ON assessment_attempts
    FOR SELECT USING (
        employee_id = get_user_employee_id() OR is_admin()
    );

CREATE POLICY attempts_insert ON assessment_attempts
    FOR INSERT WITH CHECK (employee_id = get_user_employee_id());

CREATE POLICY attempts_update ON assessment_attempts
    FOR UPDATE USING (employee_id = get_user_employee_id() OR is_admin());

-- Assessment Results
CREATE POLICY results_select ON assessment_results
    FOR SELECT USING (
        employee_id = get_user_employee_id() OR is_admin()
    );

-- Canonical obligations (DB enforced induction gating)
CREATE POLICY obligations_select ON employee_training_obligations
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND (employee_id = get_user_employee_id() OR is_admin())
        AND (induction_completed() OR is_induction OR is_admin())
    );

CREATE POLICY obligations_insert ON employee_training_obligations
    FOR INSERT WITH CHECK (
        organization_id = get_user_organization_id()
        AND is_admin()
    );

CREATE POLICY obligations_update ON employee_training_obligations
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND is_admin()
    );

-- Remedial trainings: employee + admin, gated by induction as well
CREATE POLICY remedial_select ON remedial_trainings
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND (employee_id = get_user_employee_id() OR is_admin())
        AND (induction_completed() OR is_admin())
    );

-- Certificates
CREATE POLICY certificates_select ON certificates
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND (employee_id = get_user_employee_id() OR is_admin())
    );

-- Self Learning Assignments
CREATE POLICY self_learning_select ON self_learning_assignments
    FOR SELECT USING (
        organization_id = get_user_organization_id()
        AND (employee_id = get_user_employee_id() OR is_admin())
    );

CREATE POLICY self_learning_insert ON self_learning_assignments
    FOR INSERT WITH CHECK (organization_id = get_user_organization_id());

CREATE POLICY self_learning_update ON self_learning_assignments
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND (employee_id = get_user_employee_id() OR is_admin())
    );
