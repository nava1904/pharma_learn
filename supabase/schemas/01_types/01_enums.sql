-- ===========================================
-- ENUM TYPES
-- Core enumeration types for Pharma LMS
-- ===========================================

-- ===========================================
-- WORKFLOW & STATUS ENUMS
-- ===========================================

-- Object workflow states (Learn-IQ lifecycle)
-- Registration → Initiation → Approval Set → Decision → Active/Inactive
DO $$ BEGIN
    CREATE TYPE workflow_state AS ENUM (
        'draft',
        'initiated',
        'pending_approval',
        'approved',
        'returned',
        'dropped',
        'active',
        'inactive'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMENT ON TYPE workflow_state IS 'Learn-IQ object lifecycle states: initiated → pending_approval → approved/returned/dropped → active/inactive';

-- Approval decision types
DO $$ BEGIN
    CREATE TYPE approval_decision AS ENUM (
        'approve',
        'return',
        'drop'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMENT ON TYPE approval_decision IS 'Learn-IQ approval decisions: approve (latest version), return (reinitiate), drop (revert to earlier version)';

-- Approval requirement modes
DO $$ BEGIN
    CREATE TYPE approval_requirement AS ENUM (
        'by_approval_group',
        'by_immediate_supervisor',
        'not_required'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ===========================================
-- IDENTITY ENUMS
-- ===========================================

-- Role categories (login vs non-login users)
DO $$ BEGIN
    CREATE TYPE role_category AS ENUM (
        'login',
        'non_login'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMENT ON TYPE role_category IS 'Learn-IQ: login users have accounts, non_login users use biometrics';

-- Employee status
DO $$ BEGIN
    CREATE TYPE employee_status AS ENUM (
        'active',
        'inactive',
        'locked',
        'terminated'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ===========================================
-- DOCUMENT ENUMS
-- ===========================================

-- Document types
DO $$ BEGIN
    CREATE TYPE document_type AS ENUM (
        'sop',
        'policy',
        'guideline',
        'form',
        'procedure',
        'work_instruction',
        'specification',
        'manual'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Document status
DO $$ BEGIN
    CREATE TYPE document_status AS ENUM (
        'draft',
        'initiated',
        'under_review',
        'approved',
        'active',
        'superseded',
        'obsolete',
        'inactive'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ===========================================
-- COURSE & TRAINING ENUMS
-- ===========================================

-- Course types
DO $$ BEGIN
    CREATE TYPE course_type AS ENUM (
        'one_time',
        'refresher',
        'recurring'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Training types (can be multiple per course)
DO $$ BEGIN
    CREATE TYPE training_type AS ENUM (
        'safety',
        'gmp',
        'technical',
        'induction',
        'on_job',
        'self_study',
        'external',
        'regulatory',
        'quality',
        'soft_skills'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Session types
DO $$ BEGIN
    CREATE TYPE session_type AS ENUM (
        'online',
        'offline',
        'hybrid',
        'self_paced'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Session status (Learn-IQ workflow)
DO $$ BEGIN
    CREATE TYPE session_status AS ENUM (
        'scheduled',
        'invitation_sent',
        'nominations_open',
        'batch_formed',
        'in_progress',
        'completed',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Invitation response
DO $$ BEGIN
    CREATE TYPE invitation_response AS ENUM (
        'pending',
        'accepted',
        'rejected',
        'tentative'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Nomination status
DO $$ BEGIN
    CREATE TYPE nomination_status AS ENUM (
        'pending',
        'approved',
        'rejected',
        'waitlisted'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Batch status
DO $$ BEGIN
    CREATE TYPE batch_status AS ENUM (
        'formed',
        'in_progress',
        'completed',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Participant status
DO $$ BEGIN
    CREATE TYPE participant_status AS ENUM (
        'enrolled',
        'confirmed',
        'attended',
        'absent',
        'late',
        'excused',
        'skipped',
        'disqualified',
        'completed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Enrollment source
DO $$ BEGIN
    CREATE TYPE enrollment_source AS ENUM (
        'invitation',
        'self_nomination',
        'manual',
        'induction',
        'retraining',
        'refresher',
        'training_matrix'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Attendance method
DO $$ BEGIN
    CREATE TYPE attendance_method AS ENUM (
        'online',
        'offline',
        'biometric',
        'qr_code',
        'manual'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Attendance status
DO $$ BEGIN
    CREATE TYPE attendance_status AS ENUM (
        'present',
        'absent',
        'late',
        'excused',
        'partial'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ===========================================
-- ASSESSMENT ENUMS
-- ===========================================

-- Question types
DO $$ BEGIN
    CREATE TYPE question_type AS ENUM (
        'multiple_choice',
        'multiple_select',
        'true_false',
        'descriptive',
        'fill_in_blanks',
        'matching',
        'sequence'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Difficulty levels
DO $$ BEGIN
    CREATE TYPE difficulty_level AS ENUM (
        'easy',
        'medium',
        'hard'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Question paper status
DO $$ BEGIN
    CREATE TYPE question_paper_status AS ENUM (
        'draft',
        'prepared',
        'released',
        'in_progress',
        'completed',
        'extended',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Assessment result
DO $$ BEGIN
    CREATE TYPE assessment_result AS ENUM (
        'pass',
        'fail',
        'pending_evaluation',
        'waived',
        'incomplete'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ===========================================
-- COMPLIANCE ENUMS
-- ===========================================

-- Assignment types
DO $$ BEGIN
    CREATE TYPE assignment_type AS ENUM (
        'role',
        'department',
        'individual',
        'capa',
        'onboarding',
        'retraining',
        'refresher',
        'sop_update'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Assignment source
DO $$ BEGIN
    CREATE TYPE assignment_source AS ENUM (
        'manual',
        'sop_update',
        'capa',
        'employee_created',
        'transfer',
        'training_matrix',
        'expiration',
        'system'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Assignment status
DO $$ BEGIN
    CREATE TYPE assignment_status AS ENUM (
        'assigned',
        'acknowledged',
        'in_progress',
        'completed',
        'overdue',
        'waived',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Assignment priority
DO $$ BEGIN
    CREATE TYPE assignment_priority AS ENUM (
        'low',
        'medium',
        'high',
        'critical'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Certificate status
DO $$ BEGIN
    CREATE TYPE certificate_status AS ENUM (
        'active',
        'expired',
        'revoked',
        'superseded'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Extend certificate_status for regulated lifecycle
DO $$ BEGIN
    ALTER TYPE certificate_status ADD VALUE IF NOT EXISTS 'obsolete';
    ALTER TYPE certificate_status ADD VALUE IF NOT EXISTS 'suspended';
EXCEPTION
    WHEN undefined_object THEN null;
END $$;

-- ===========================================
-- OBLIGATIONS / TNI / REMEDIAL ENUMS
-- ===========================================

-- Canonical training obligation status (single source of truth)
DO $$ BEGIN
    CREATE TYPE obligation_status AS ENUM (
        'pending',
        'in_progress',
        'completed',
        'overdue',
        'failed',
        'waived',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- What kind of obligation is it (course, document read, OJT, assessment, etc.)
DO $$ BEGIN
    CREATE TYPE obligation_item_type AS ENUM (
        'course',
        'document_read',
        'ojt',
        'assessment',
        'external_training'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Remedial failure disposition (pharma-realistic)
DO $$ BEGIN
    CREATE TYPE failure_disposition AS ENUM (
        'retraining_required',
        'investigation_required',
        'both',
        'waived'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Training result
DO $$ BEGIN
    CREATE TYPE training_result AS ENUM (
        'pass',
        'fail',
        'waived',
        'incomplete',
        'in_progress'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Retraining reason
DO $$ BEGIN
    CREATE TYPE retraining_reason AS ENUM (
        'failed',
        'absent',
        'skipped',
        'sop_updated',
        'disqualified',
        'expired',
        'capa'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Document reading status
DO $$ BEGIN
    CREATE TYPE reading_status AS ENUM (
        'pending',
        'in_progress',
        'read',
        'acknowledged',
        'overdue',
        'terminated'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ===========================================
-- QUALITY ENUMS
-- ===========================================

-- Quality event types
DO $$ BEGIN
    CREATE TYPE quality_event_type AS ENUM (
        'deviation',
        'capa',
        'change_control',
        'audit_finding',
        'complaint',
        'oos',
        'incident'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Quality event status
DO $$ BEGIN
    CREATE TYPE quality_event_status AS ENUM (
        'open',
        'investigation',
        'in_progress',
        'pending_approval',
        'closed',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- CAPA status
DO $$ BEGIN
    CREATE TYPE capa_status AS ENUM (
        'open',
        'rca_in_progress',
        'action_planning',
        'implementation',
        'training_assigned',
        'effectiveness_check_pending',
        'closed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ===========================================
-- AUDIT & E-SIGNATURE ENUMS
-- ===========================================

-- Signature meanings (21 CFR Part 11)
DO $$ BEGIN
    CREATE TYPE signature_meaning AS ENUM (
        'authored',
        'reviewed',
        'approved',
        'acknowledged',
        'witnessed',
        'verified',
        'rejected'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMENT ON TYPE signature_meaning IS '21 CFR Part 11 compliant signature meanings';

-- Audit action categories
DO $$ BEGIN
    CREATE TYPE audit_action AS ENUM (
        'created',
        'read',
        'updated',
        'deleted',
        'status_changed',
        'approved',
        'rejected',
        'submitted',
        'completed',
        'cancelled',
        'signed',
        'verified',
        'exported',
        'printed',
        'emailed',
        'login',
        'logout',
        'password_changed',
        'role_assigned',
        'role_removed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Access log actions
DO $$ BEGIN
    CREATE TYPE access_action AS ENUM (
        'login',
        'logout',
        'session_timeout',
        'failed_login',
        'account_locked',
        'password_reset',
        'password_changed',
        'mfa_enabled',
        'mfa_disabled',
        'mfa_verified',
        'mfa_failed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Session end reason
DO $$ BEGIN
    CREATE TYPE session_end_reason AS ENUM (
        'logout',
        'session_timeout',
        'forced',
        'system',
        'concurrent_login'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ===========================================
-- NOTIFICATION ENUMS
-- ===========================================

-- Notification channels
DO $$ BEGIN
    CREATE TYPE notification_channel AS ENUM (
        'email',
        'in_app',
        'sms',
        'push'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Notification status
DO $$ BEGIN
    CREATE TYPE notification_status AS ENUM (
        'pending',
        'queued',
        'sent',
        'delivered',
        'read',
        'failed',
        'bounced'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Notification priority
DO $$ BEGIN
    CREATE TYPE notification_priority AS ENUM (
        'low',
        'normal',
        'high',
        'urgent'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Mail template types
DO $$ BEGIN
    CREATE TYPE mail_template_type AS ENUM (
        'course_invitation',
        'batch_formation_acceptance',
        'attendance_status_trainee',
        'attendance_status_supervisor',
        'question_paper_released',
        'result_to_trainee',
        'result_to_supervisor',
        'short_term_evaluation',
        'long_term_evaluation',
        'feedback_request',
        'document_reading',
        'training_reminder',
        'certificate_expiry_reminder',
        'training_completion',
        'assignment_notification',
        'password_reset',
        'account_locked',
        'welcome_email'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ===========================================
-- TRAINER & VENUE ENUMS
-- ===========================================

-- Trainer status
DO $$ BEGIN
    CREATE TYPE trainer_status AS ENUM (
        'initiated',
        'pending_approval',
        'active',
        'inactive',
        'suspended'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Venue type
DO $$ BEGIN
    CREATE TYPE venue_type AS ENUM (
        'classroom',
        'lab',
        'conference_room',
        'virtual',
        'field',
        'workshop'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ===========================================
-- FEEDBACK & EVALUATION ENUMS
-- ===========================================

-- Feedback template types
DO $$ BEGIN
    CREATE TYPE feedback_template_type AS ENUM (
        'long_term_evaluation',
        'short_term_evaluation',
        'feedback',
        'trainer_evaluation'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- GTP (Group Training Plan) status
DO $$ BEGIN
    CREATE TYPE gtp_status AS ENUM (
        'draft',
        'active',
        'closed',
        'archived'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- GTP type
DO $$ BEGIN
    CREATE TYPE gtp_type AS ENUM (
        'group',
        'subgroup',
        'department',
        'plant'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Schedule status
DO $$ BEGIN
    CREATE TYPE schedule_status AS ENUM (
        'planned',
        'confirmed',
        'completed',
        'cancelled',
        'postponed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
