-- ===========================================
-- G9: MISSING TABLES REFERENCED BY API HANDLERS
-- These tables are queried by handlers but don't exist in schema
-- ===========================================

-- ---------------------------------------------------------------------------
-- 0. SCORM Packages - standalone creation (17_extensions skipped by deploy_schemas.sh)
-- Mirrors 17_extensions/07_content_library.sql without the content_assets FK
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS scorm_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    scorm_version TEXT DEFAULT '1.2' CHECK (scorm_version IN ('1.2', '2004_3', '2004_4')),
    launch_url TEXT NOT NULL,
    manifest_json JSONB,
    storage_path TEXT,               -- Path in Supabase Storage
    file_size_bytes BIGINT,
    passing_score NUMERIC(5,2) DEFAULT 80,
    mastery_threshold NUMERIC(5,2),
    is_active BOOLEAN DEFAULT TRUE,
    uploaded_by UUID REFERENCES employees(id),
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scorm_packages_org ON scorm_packages(organization_id);
CREATE INDEX IF NOT EXISTS idx_scorm_packages_course ON scorm_packages(course_id);

ALTER TABLE scorm_packages ENABLE ROW LEVEL SECURITY;
CREATE POLICY scorm_packages_select ON scorm_packages FOR SELECT
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);
CREATE POLICY scorm_packages_modify ON scorm_packages FOR ALL
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);

COMMENT ON TABLE scorm_packages IS 'SCORM 1.2 content packages; mirrors 17_extensions definition without content_assets FK';

-- ---------------------------------------------------------------------------
-- 1. SCORM Sessions - tracks SCORM package playback state
-- Used by: scorm_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS scorm_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    package_id UUID NOT NULL REFERENCES scorm_packages(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    training_record_id UUID REFERENCES training_records(id),
    
    -- SCORM runtime state
    status TEXT NOT NULL DEFAULT 'not_attempted' 
        CHECK (status IN ('not_attempted', 'incomplete', 'completed', 'passed', 'failed')),
    cmi_data JSONB DEFAULT '{}'::JSONB,  -- Full CMI data model
    score_raw NUMERIC(5,2),
    score_min NUMERIC(5,2) DEFAULT 0,
    score_max NUMERIC(5,2) DEFAULT 100,
    score_scaled NUMERIC(5,4),  -- -1 to 1 for SCORM 2004
    total_time TEXT,  -- ISO 8601 duration
    session_time TEXT,
    
    -- Tracking
    attempt_number INTEGER DEFAULT 1,
    launched_at TIMESTAMPTZ,
    last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    -- Bookmarking
    suspend_data TEXT,
    location TEXT,  -- Bookmark location
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scorm_sessions_package ON scorm_sessions(package_id);
CREATE INDEX IF NOT EXISTS idx_scorm_sessions_employee ON scorm_sessions(employee_id);
CREATE INDEX IF NOT EXISTS idx_scorm_sessions_status ON scorm_sessions(status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_scorm_sessions_unique_attempt 
    ON scorm_sessions(package_id, employee_id, attempt_number);

-- ---------------------------------------------------------------------------
-- 2. SSO Auth States - temporary state for OAuth flows
-- Used by: sso_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sso_auth_states (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES sso_configurations(id) ON DELETE CASCADE,
    
    -- OAuth state parameters
    state TEXT NOT NULL UNIQUE,  -- Random state for CSRF protection
    nonce TEXT,                   -- For OpenID Connect
    code_verifier TEXT,           -- For PKCE
    redirect_uri TEXT,
    
    -- Post-auth handling
    target_url TEXT,              -- Where to redirect after auth
    employee_id UUID REFERENCES employees(id),  -- Set after auth
    
    -- Lifecycle
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '10 minutes'),
    used_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sso_auth_states_state ON sso_auth_states(state);
CREATE INDEX IF NOT EXISTS idx_sso_auth_states_expires ON sso_auth_states(expires_at);

-- ---------------------------------------------------------------------------
-- 3. Approval Steps - tracks multi-step approval workflows
-- Used by: advance_step_handler.dart, document_export_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS approval_steps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- What's being approved
    entity_type TEXT NOT NULL,  -- 'document', 'course', 'waiver', etc.
    entity_id UUID NOT NULL,
    
    -- Step configuration
    step_order INTEGER NOT NULL,
    step_name TEXT,
    required_role TEXT,
    required_approver_id UUID REFERENCES employees(id),
    
    -- Step state
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected', 'skipped')),
    approved_by UUID REFERENCES employees(id),
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    
    -- E-signature for 21 CFR Part 11
    esignature_id UUID REFERENCES electronic_signatures(id),
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_approval_steps_entity 
    ON approval_steps(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_approval_steps_status 
    ON approval_steps(status) WHERE status = 'pending';
CREATE UNIQUE INDEX IF NOT EXISTS idx_approval_steps_unique 
    ON approval_steps(entity_type, entity_id, step_order);

-- ---------------------------------------------------------------------------
-- 4. Curriculum Courses - links courses to curricula
-- Used by: curricula_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS curriculum_courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    curriculum_id UUID NOT NULL REFERENCES curricula(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_mandatory BOOLEAN DEFAULT TRUE,
    estimated_duration_hours NUMERIC(5,2),
    
    -- Prerequisites within curriculum
    prerequisite_course_ids UUID[] DEFAULT '{}',
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(curriculum_id, course_id)
);

CREATE INDEX IF NOT EXISTS idx_curriculum_courses_curriculum 
    ON curriculum_courses(curriculum_id);
CREATE INDEX IF NOT EXISTS idx_curriculum_courses_course 
    ON curriculum_courses(course_id);

-- ---------------------------------------------------------------------------
-- 5. Question Paper Items - links questions to papers
-- Used by: question_papers_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS question_paper_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_paper_id UUID NOT NULL REFERENCES question_papers(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    
    sort_order INTEGER NOT NULL DEFAULT 0,
    marks NUMERIC(5,2) NOT NULL DEFAULT 1,
    is_mandatory BOOLEAN DEFAULT TRUE,
    
    -- Section grouping
    section_name TEXT,
    section_order INTEGER,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(question_paper_id, question_id)
);

CREATE INDEX IF NOT EXISTS idx_question_paper_items_paper 
    ON question_paper_items(question_paper_id);
CREATE INDEX IF NOT EXISTS idx_question_paper_items_question 
    ON question_paper_items(question_id);

-- ---------------------------------------------------------------------------
-- 6. Employee Groups - for bulk operations and filtering
-- Used by: groups_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS employee_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    name TEXT NOT NULL,
    description TEXT,
    group_type TEXT DEFAULT 'manual'
        CHECK (group_type IN ('manual', 'dynamic', 'department', 'role')),
    
    -- For dynamic groups
    filter_criteria JSONB,
    
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES employees(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(organization_id, name)
);

CREATE INDEX IF NOT EXISTS idx_employee_groups_org 
    ON employee_groups(organization_id);
CREATE INDEX IF NOT EXISTS idx_employee_groups_type 
    ON employee_groups(group_type);

-- ---------------------------------------------------------------------------
-- 7. Employee Group Members - membership in groups
-- Used by: groups_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS employee_group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES employee_groups(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    
    added_by UUID REFERENCES employees(id),
    added_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(group_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_employee_group_members_group 
    ON employee_group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_employee_group_members_employee 
    ON employee_group_members(employee_id);

-- ---------------------------------------------------------------------------
-- 8. Role Permissions - granular permissions per role
-- Used by: role_handler.dart, roles_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission TEXT NOT NULL,  -- e.g., 'documents.create', 'courses.approve'
    
    granted_by UUID REFERENCES employees(id),
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(role_id, permission)
);

CREATE INDEX IF NOT EXISTS idx_role_permissions_role 
    ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission 
    ON role_permissions(permission);

-- ---------------------------------------------------------------------------
-- 9. Trainer Competencies - what trainers can teach
-- Used by: trainers_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS trainer_competencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trainer_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    competency_id UUID NOT NULL REFERENCES competencies(id) ON DELETE CASCADE,
    
    -- Qualification level
    qualification_level TEXT DEFAULT 'basic'
        CHECK (qualification_level IN ('basic', 'intermediate', 'advanced', 'expert')),
    
    -- Certification
    certified_at TIMESTAMPTZ,
    certification_expires_at TIMESTAMPTZ,
    certification_document_id UUID REFERENCES documents(id),
    
    assigned_by UUID REFERENCES employees(id),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(trainer_id, competency_id)
);

CREATE INDEX IF NOT EXISTS idx_trainer_competencies_trainer 
    ON trainer_competencies(trainer_id);
CREATE INDEX IF NOT EXISTS idx_trainer_competencies_competency 
    ON trainer_competencies(competency_id);

-- ---------------------------------------------------------------------------
-- 10. Periodic Review History - tracks review outcomes
-- Used by: periodic_reviews_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS periodic_review_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    periodic_review_id UUID NOT NULL REFERENCES periodic_review_schedules(id) ON DELETE CASCADE,
    
    review_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_by UUID NOT NULL REFERENCES employees(id),
    
    outcome TEXT NOT NULL
        CHECK (outcome IN ('no_change', 'revision_needed', 'superseded', 'withdrawn')),
    comments TEXT,
    
    -- If revision needed, link to new version
    new_version_id UUID,  -- References same entity type
    
    -- E-signature
    esignature_id UUID REFERENCES electronic_signatures(id),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_periodic_review_history_review 
    ON periodic_review_history(periodic_review_id);
CREATE INDEX IF NOT EXISTS idx_periodic_review_history_outcome 
    ON periodic_review_history(outcome);

-- ---------------------------------------------------------------------------
-- 11. Training Completions - denormalized completion tracking
-- Used by: induction_handler.dart, scorm_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS training_completions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    
    -- Completion details
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completion_type TEXT DEFAULT 'normal'
        CHECK (completion_type IN ('normal', 'waived', 'equivalent', 'prior_learning')),
    
    -- Links to source records
    training_record_id UUID REFERENCES training_records(id),
    certificate_id UUID REFERENCES certificates(id),
    waiver_id UUID REFERENCES training_waivers(id),
    
    -- Score if applicable
    final_score NUMERIC(5,2),
    passed BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(employee_id, course_id)
);

CREATE INDEX IF NOT EXISTS idx_training_completions_employee 
    ON training_completions(employee_id);
CREATE INDEX IF NOT EXISTS idx_training_completions_course 
    ON training_completions(course_id);
CREATE INDEX IF NOT EXISTS idx_training_completions_org 
    ON training_completions(organization_id);

-- ---------------------------------------------------------------------------
-- 12. Biometric Credentials - stored biometric templates
-- Used by: biometric_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS biometric_credentials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    
    credential_type TEXT NOT NULL
        CHECK (credential_type IN ('fingerprint', 'face', 'voice', 'iris')),
    credential_data TEXT NOT NULL,  -- Encrypted biometric template
    device_id TEXT,                  -- Which enrollment device
    
    -- Lifecycle
    is_active BOOLEAN DEFAULT TRUE,
    enrolled_at TIMESTAMPTZ DEFAULT NOW(),
    enrolled_by UUID REFERENCES employees(id),
    last_used_at TIMESTAMPTZ,
    deactivated_at TIMESTAMPTZ,
    deactivated_by UUID REFERENCES employees(id),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(employee_id, credential_type)
);

CREATE INDEX IF NOT EXISTS idx_biometric_credentials_employee 
    ON biometric_credentials(employee_id);
CREATE INDEX IF NOT EXISTS idx_biometric_credentials_type 
    ON biometric_credentials(credential_type);

-- ---------------------------------------------------------------------------
-- 13. Document Attachments - files attached to documents
-- Used by: document_delete_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS document_attachments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    
    file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size BIGINT,
    mime_type TEXT,
    
    -- Storage
    storage_bucket TEXT DEFAULT 'pharmalearn-files',
    checksum TEXT,  -- SHA-256 for integrity
    
    uploaded_by UUID REFERENCES employees(id),
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_document_attachments_document 
    ON document_attachments(document_id);

-- ---------------------------------------------------------------------------
-- 14. Self Learning Progress - tracks self-paced course progress
-- Used by: me_training_history_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS self_learning_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    
    -- Progress tracking
    progress_percent NUMERIC(5,2) DEFAULT 0
        CHECK (progress_percent >= 0 AND progress_percent <= 100),
    status TEXT DEFAULT 'not_started'
        CHECK (status IN ('not_started', 'in_progress', 'completed', 'abandoned')),
    
    -- Time tracking
    started_at TIMESTAMPTZ,
    last_accessed_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    total_time_seconds INTEGER DEFAULT 0,
    
    -- Module progress
    completed_modules JSONB DEFAULT '[]'::JSONB,
    current_module_id UUID,
    
    -- Bookmarking
    bookmark_data JSONB,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(employee_id, course_id)
);

CREATE INDEX IF NOT EXISTS idx_self_learning_progress_employee 
    ON self_learning_progress(employee_id);
CREATE INDEX IF NOT EXISTS idx_self_learning_progress_course 
    ON self_learning_progress(course_id);
CREATE INDEX IF NOT EXISTS idx_self_learning_progress_status 
    ON self_learning_progress(status);

-- ---------------------------------------------------------------------------
-- 15. OJT Assignments View - alias for me_training_history_handler.dart
-- Creates a view over employee_ojt for cleaner querying
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW ojt_assignments AS
SELECT
    eo.id,
    om.organization_id,
    eo.employee_id,
    eo.ojt_id,
    om.name AS ojt_name,
    om.unique_code AS ojt_code,
    eo.assigned_at,
    eo.assigned_by,
    eo.expected_completion_date AS due_date,
    eo.status,
    eo.start_date AS started_at,
    eo.actual_completion_date AS completed_at,
    eo.completion_percentage,
    eo.supervisor_id,
    e.first_name || ' ' || e.last_name AS supervisor_name
FROM employee_ojt eo
JOIN ojt_masters om ON eo.ojt_id = om.id
LEFT JOIN employees e ON eo.supervisor_id = e.id;

-- ---------------------------------------------------------------------------
-- 16. RLS Policies
-- ---------------------------------------------------------------------------

-- SCORM Sessions
ALTER TABLE scorm_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY scorm_sessions_select ON scorm_sessions FOR SELECT
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);
CREATE POLICY scorm_sessions_insert ON scorm_sessions FOR INSERT
    WITH CHECK (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);
CREATE POLICY scorm_sessions_update ON scorm_sessions FOR UPDATE
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);

-- SSO Auth States
ALTER TABLE sso_auth_states ENABLE ROW LEVEL SECURITY;
CREATE POLICY sso_auth_states_all ON sso_auth_states FOR ALL
    USING (TRUE);  -- States are short-lived and verified by state token

-- Approval Steps
ALTER TABLE approval_steps ENABLE ROW LEVEL SECURITY;
CREATE POLICY approval_steps_select ON approval_steps FOR SELECT
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);
CREATE POLICY approval_steps_insert ON approval_steps FOR INSERT
    WITH CHECK (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);
CREATE POLICY approval_steps_update ON approval_steps FOR UPDATE
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);

-- Employee Groups
ALTER TABLE employee_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_groups_select ON employee_groups FOR SELECT
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);
CREATE POLICY employee_groups_modify ON employee_groups FOR ALL
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);

-- Employee Group Members
ALTER TABLE employee_group_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_group_members_all ON employee_group_members FOR ALL
    USING (EXISTS (
        SELECT 1 FROM employee_groups eg 
        WHERE eg.id = group_id 
        AND eg.organization_id = (current_setting('app.current_organization_id', TRUE))::UUID
    ));

-- Training Completions
ALTER TABLE training_completions ENABLE ROW LEVEL SECURITY;
CREATE POLICY training_completions_select ON training_completions FOR SELECT
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);
CREATE POLICY training_completions_insert ON training_completions FOR INSERT
    WITH CHECK (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);

-- Biometric Credentials
ALTER TABLE biometric_credentials ENABLE ROW LEVEL SECURITY;
CREATE POLICY biometric_credentials_select ON biometric_credentials FOR SELECT
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);
CREATE POLICY biometric_credentials_modify ON biometric_credentials FOR ALL
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);

-- Self Learning Progress
ALTER TABLE self_learning_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY self_learning_progress_select ON self_learning_progress FOR SELECT
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);
CREATE POLICY self_learning_progress_modify ON self_learning_progress FOR ALL
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);

-- ---------------------------------------------------------------------------
-- 17. Audit Triggers
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_scorm_sessions_audit 
    AFTER INSERT OR UPDATE OR DELETE ON scorm_sessions 
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

CREATE TRIGGER trg_approval_steps_audit 
    AFTER INSERT OR UPDATE OR DELETE ON approval_steps 
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

CREATE TRIGGER trg_employee_groups_audit 
    AFTER INSERT OR UPDATE OR DELETE ON employee_groups 
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

CREATE TRIGGER trg_training_completions_audit 
    AFTER INSERT OR UPDATE OR DELETE ON training_completions 
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

CREATE TRIGGER trg_biometric_credentials_audit 
    AFTER INSERT OR UPDATE OR DELETE ON biometric_credentials 
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- ---------------------------------------------------------------------------
-- 18. Comments
-- ---------------------------------------------------------------------------
COMMENT ON TABLE scorm_sessions IS 'Tracks SCORM package playback state and CMI data';
COMMENT ON TABLE sso_auth_states IS 'Temporary OAuth state for SSO flows (expires in 10 min)';
COMMENT ON TABLE approval_steps IS 'Multi-step approval workflow tracking';
COMMENT ON TABLE curriculum_courses IS 'Links courses to curricula with ordering';
COMMENT ON TABLE question_paper_items IS 'Links questions to question papers with ordering and marks';
COMMENT ON TABLE employee_groups IS 'Manual or dynamic groupings of employees';
COMMENT ON TABLE employee_group_members IS 'Membership in employee groups';
COMMENT ON TABLE role_permissions IS 'Granular permissions assigned to roles';
COMMENT ON TABLE trainer_competencies IS 'What competencies a trainer is qualified to teach';
COMMENT ON TABLE periodic_review_history IS 'Audit trail of periodic review outcomes';
COMMENT ON TABLE training_completions IS 'Denormalized view of course completions per employee';
COMMENT ON TABLE biometric_credentials IS 'Encrypted biometric templates for authentication';
COMMENT ON TABLE document_attachments IS 'Files attached to documents';
COMMENT ON TABLE self_learning_progress IS 'Progress tracking for self-paced courses';
COMMENT ON VIEW ojt_assignments IS 'Convenience view over employee_ojt with joined data';
