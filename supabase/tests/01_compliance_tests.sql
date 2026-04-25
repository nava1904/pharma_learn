-- =====================================================
-- tests/01_compliance_tests.sql
-- pgTAP Tests for 21 CFR Part 11 Compliance
-- Run with: pg_prove -d database_name tests/
-- =====================================================

BEGIN;
SELECT plan(25);

-- =====================================================
-- TEST 1: Audit Trail Immutability
-- =====================================================
SELECT has_rule(
    'public',
    'audit_trails',
    'audit_trails_no_update',
    'Audit trails should have NO UPDATE rule'
);

SELECT has_rule(
    'public',
    'audit_trails',
    'audit_trails_no_delete',
    'Audit trails should have NO DELETE rule'
);

-- =====================================================
-- TEST 2: E-Signature Immutability
-- =====================================================
SELECT has_rule(
    'public',
    'electronic_signatures',
    'electronic_signatures_no_update',
    'E-signatures should have NO UPDATE rule'
);

SELECT has_rule(
    'public',
    'electronic_signatures',
    'electronic_signatures_no_delete',
    'E-signatures should have NO DELETE rule'
);

-- =====================================================
-- TEST 3: Audit Trail Has Hash Chain Columns
-- =====================================================
SELECT has_column(
    'public',
    'audit_trails',
    'record_hash',
    'Audit trails should have record_hash column'
);

SELECT has_column(
    'public',
    'audit_trails',
    'prev_hash',
    'Audit trails should have prev_hash column'
);

SELECT has_column(
    'public',
    'audit_trails',
    'event_category',
    'Audit trails should have event_category column'
);

-- =====================================================
-- TEST 4: E-Signature Has Session Chain
-- =====================================================
SELECT has_column(
    'public',
    'electronic_signatures',
    'prev_signature_id',
    'E-signatures should have prev_signature_id column'
);

SELECT has_column(
    'public',
    'electronic_signatures',
    'is_first_in_session',
    'E-signatures should have is_first_in_session column'
);

SELECT has_column(
    'public',
    'electronic_signatures',
    'session_token_hash',
    'E-signatures should have session_token_hash column'
);

SELECT has_column(
    'public',
    'electronic_signatures',
    'record_hash',
    'E-signatures should have record_hash column'
);

-- =====================================================
-- TEST 5: Certificate Has Two-Person Revocation
-- =====================================================
SELECT has_column(
    'public',
    'certificates',
    'revoked_by',
    'Certificates should have revoked_by column'
);

SELECT has_column(
    'public',
    'certificates',
    'revocation_approved_by',
    'Certificates should have revocation_approved_by column'
);

-- =====================================================
-- TEST 6: Training Sessions Has Required Columns
-- =====================================================
SELECT has_column(
    'public',
    'training_sessions',
    'session_code',
    'Training sessions should have session_code column'
);

SELECT has_column(
    'public',
    'training_sessions',
    'min_attendance_percent',
    'Training sessions should have min_attendance_percent column'
);

-- =====================================================
-- TEST 7: Session Attendance Has E-Signature FK
-- =====================================================
SELECT has_column(
    'public',
    'session_attendance',
    'esignature_id',
    'Session attendance should have esignature_id column'
);

-- =====================================================
-- TEST 8: Employees Has Username Immutability
-- =====================================================
SELECT has_trigger(
    'public',
    'employees',
    'trg_username_immutable',
    'Employees should have username immutability trigger'
);

SELECT has_column(
    'public',
    'employees',
    'induction_completed',
    'Employees should have induction_completed column'
);

-- =====================================================
-- TEST 9: Roles Has Approval Columns
-- =====================================================
SELECT has_column(
    'public',
    'roles',
    'approval_tier',
    'Roles should have approval_tier column'
);

SELECT has_column(
    'public',
    'roles',
    'can_approve',
    'Roles should have can_approve column'
);

-- =====================================================
-- TEST 10: User Credentials Table Exists
-- =====================================================
SELECT has_table(
    'public',
    'user_credentials',
    'User credentials table should exist for password history'
);

-- =====================================================
-- TEST 11: Password Policies Table Exists
-- =====================================================
SELECT has_table(
    'public',
    'password_policies',
    'Password policies table should exist'
);

-- =====================================================
-- TEST 12: Standard Reasons Table Exists
-- =====================================================
SELECT has_table(
    'public',
    'standard_reasons',
    'Standard reasons table should exist for controlled vocabulary'
);

-- =====================================================
-- TEST 13: RLS Enabled on Sensitive Tables
-- =====================================================
SELECT row_security_active(
    'employees',
    'RLS should be enabled on employees table'
);

SELECT row_security_active(
    'audit_trails',
    'RLS should be enabled on audit_trails table'
);

-- =====================================================
-- Finish Tests
-- =====================================================
SELECT * FROM finish();
ROLLBACK;
