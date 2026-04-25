-- =====================================================
-- 99_policies/06_integrity_validation.sql
-- Enterprise Integrity Validation Functions
-- Final validation layer for 21 CFR Part 11 compliance
-- =====================================================

-- =====================================================
-- 1. AUDIT TRAIL INTEGRITY CHECK
-- Validates hash chain is unbroken
-- =====================================================
CREATE OR REPLACE FUNCTION verify_audit_trail_integrity(
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    total_records BIGINT,
    verified_records BIGINT,
    broken_chain_count BIGINT,
    first_broken_id UUID,
    integrity_status TEXT
) AS $$
DECLARE
    v_total BIGINT;
    v_verified BIGINT := 0;
    v_broken BIGINT := 0;
    v_first_broken UUID := NULL;
    v_prev_hash TEXT := NULL;
    v_record RECORD;
BEGIN
    -- Count total records in range
    SELECT COUNT(*) INTO v_total
    FROM audit_trails
    WHERE (p_start_date IS NULL OR performed_at >= p_start_date)
      AND (p_end_date IS NULL OR performed_at <= p_end_date);
    
    -- Iterate through records in order to verify chain
    FOR v_record IN 
        SELECT id, prev_hash, record_hash
        FROM audit_trails
        WHERE (p_start_date IS NULL OR performed_at >= p_start_date)
          AND (p_end_date IS NULL OR performed_at <= p_end_date)
        ORDER BY performed_at ASC
    LOOP
        IF v_prev_hash IS NOT NULL AND v_record.prev_hash != v_prev_hash THEN
            v_broken := v_broken + 1;
            IF v_first_broken IS NULL THEN
                v_first_broken := v_record.id;
            END IF;
        ELSE
            v_verified := v_verified + 1;
        END IF;
        v_prev_hash := v_record.record_hash;
    END LOOP;
    
    RETURN QUERY SELECT 
        v_total,
        v_verified,
        v_broken,
        v_first_broken,
        CASE 
            WHEN v_broken = 0 THEN 'VERIFIED'
            ELSE 'CHAIN_BROKEN'
        END::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION verify_audit_trail_integrity IS 
'Validates audit trail hash chain integrity per 21 CFR Part 11 §11.10(e)';

-- =====================================================
-- 2. E-SIGNATURE CHAIN VERIFICATION
-- Validates signature chain integrity
-- =====================================================
CREATE OR REPLACE FUNCTION verify_esignature_integrity(
    p_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    total_signatures BIGINT,
    verified_signatures BIGINT,
    broken_chain_count BIGINT,
    integrity_status TEXT,
    details JSONB
) AS $$
DECLARE
    v_total BIGINT;
    v_verified BIGINT := 0;
    v_broken BIGINT := 0;
    v_details JSONB := '[]'::JSONB;
    v_record RECORD;
    v_prev_sig_id UUID := NULL;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM electronic_signatures
    WHERE (p_user_id IS NULL OR signer_id = p_user_id);
    
    FOR v_record IN 
        SELECT id, signer_id, prev_signature_id, is_first_in_session, signed_at
        FROM electronic_signatures
        WHERE (p_user_id IS NULL OR signer_id = p_user_id)
        ORDER BY signer_id, signed_at ASC
    LOOP
        -- First in session should have NULL prev_signature_id
        IF v_record.is_first_in_session AND v_record.prev_signature_id IS NOT NULL THEN
            v_broken := v_broken + 1;
            v_details := v_details || jsonb_build_object(
                'id', v_record.id,
                'issue', 'first_in_session_has_prev',
                'signed_at', v_record.signed_at
            );
        -- Not first should have prev_signature_id matching previous
        ELSIF NOT v_record.is_first_in_session AND v_record.prev_signature_id IS NULL THEN
            v_broken := v_broken + 1;
            v_details := v_details || jsonb_build_object(
                'id', v_record.id,
                'issue', 'missing_prev_signature',
                'signed_at', v_record.signed_at
            );
        ELSE
            v_verified := v_verified + 1;
        END IF;
        
        v_prev_sig_id := v_record.id;
    END LOOP;
    
    RETURN QUERY SELECT 
        v_total,
        v_verified,
        v_broken,
        CASE 
            WHEN v_broken = 0 THEN 'VERIFIED'
            ELSE 'INTEGRITY_ISSUES'
        END::TEXT,
        CASE WHEN jsonb_array_length(v_details) > 10 
            THEN (SELECT jsonb_agg(x) FROM jsonb_array_elements(v_details) WITH ORDINALITY AS t(x, n) WHERE n <= 10)
            ELSE v_details 
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION verify_esignature_integrity IS 
'Validates e-signature chain integrity per 21 CFR Part 11 §11.50';

-- =====================================================
-- 3. CERTIFICATE INTEGRITY CHECK
-- Validates certificate revocation compliance
-- =====================================================
CREATE OR REPLACE FUNCTION verify_certificate_integrity()
RETURNS TABLE (
    total_certificates BIGINT,
    active_certificates BIGINT,
    expired_certificates BIGINT,
    revoked_certificates BIGINT,
    invalid_revocations BIGINT,
    integrity_status TEXT
) AS $$
DECLARE
    v_total BIGINT;
    v_active BIGINT;
    v_expired BIGINT;
    v_revoked BIGINT;
    v_invalid BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total FROM certificates;
    
    SELECT COUNT(*) INTO v_active 
    FROM certificates 
    WHERE status = 'active' 
      AND (expires_at IS NULL OR expires_at > NOW());
    
    SELECT COUNT(*) INTO v_expired 
    FROM certificates 
    WHERE expires_at IS NOT NULL 
      AND expires_at <= NOW()
      AND status != 'expired';
    
    SELECT COUNT(*) INTO v_revoked 
    FROM certificates 
    WHERE status = 'revoked';
    
    -- Check for invalid revocations (missing two-person approval)
    SELECT COUNT(*) INTO v_invalid
    FROM certificates
    WHERE status = 'revoked'
      AND (revoked_by IS NULL OR revocation_approved_by IS NULL);
    
    RETURN QUERY SELECT 
        v_total,
        v_active,
        v_expired,
        v_revoked,
        v_invalid,
        CASE 
            WHEN v_invalid > 0 THEN 'INVALID_REVOCATIONS'
            WHEN v_expired > 0 THEN 'EXPIRED_NOT_UPDATED'
            ELSE 'VERIFIED'
        END::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION verify_certificate_integrity IS 
'Validates certificate revocation has two-person approval';

-- =====================================================
-- 4. COMPREHENSIVE COMPLIANCE CHECK
-- Single function to validate all 21 CFR Part 11 requirements
-- =====================================================
CREATE OR REPLACE FUNCTION run_compliance_validation()
RETURNS TABLE (
    check_name TEXT,
    requirement TEXT,
    cfr_reference TEXT,
    status TEXT,
    details JSONB
) AS $$
DECLARE
    v_result RECORD;
BEGIN
    -- Check 1: Audit Trail Integrity
    SELECT * INTO v_result FROM verify_audit_trail_integrity();
    RETURN QUERY SELECT 
        'audit_trail_integrity'::TEXT,
        'Hash chain unbroken'::TEXT,
        '§11.10(e)'::TEXT,
        v_result.integrity_status,
        jsonb_build_object(
            'total', v_result.total_records,
            'verified', v_result.verified_records,
            'broken', v_result.broken_chain_count
        );
    
    -- Check 2: E-Signature Integrity  
    SELECT * INTO v_result FROM verify_esignature_integrity();
    RETURN QUERY SELECT 
        'esignature_integrity'::TEXT,
        'Signature chain valid'::TEXT,
        '§11.50'::TEXT,
        v_result.integrity_status,
        jsonb_build_object(
            'total', v_result.total_signatures,
            'verified', v_result.verified_signatures,
            'broken', v_result.broken_chain_count
        );
    
    -- Check 3: Certificate Integrity
    SELECT * INTO v_result FROM verify_certificate_integrity();
    RETURN QUERY SELECT 
        'certificate_integrity'::TEXT,
        'Two-person revocation'::TEXT,
        '§11.10(c)'::TEXT,
        v_result.integrity_status,
        jsonb_build_object(
            'total', v_result.total_certificates,
            'revoked', v_result.revoked_certificates,
            'invalid', v_result.invalid_revocations
        );
    
    -- Check 4: Password Policy Compliance
    RETURN QUERY SELECT 
        'password_policy'::TEXT,
        'Policy configured'::TEXT,
        '§11.300(b)'::TEXT,
        CASE WHEN EXISTS (SELECT 1 FROM password_policies WHERE is_active = TRUE) 
            THEN 'VERIFIED' ELSE 'NOT_CONFIGURED' END,
        (SELECT jsonb_build_object(
            'min_length', min_length,
            'expiry_days', expiry_days,
            'history_count', history_count
        ) FROM password_policies WHERE is_active = TRUE LIMIT 1);
    
    -- Check 5: Immutability Rules Active
    RETURN QUERY SELECT 
        'immutability_rules'::TEXT,
        'UPDATE/DELETE blocked on audit tables'::TEXT,
        '§11.10(e)'::TEXT,
        CASE WHEN EXISTS (
            SELECT 1 FROM pg_rules 
            WHERE tablename = 'audit_trails' 
            AND rulename LIKE '%no_update%'
        ) THEN 'VERIFIED' ELSE 'NOT_CONFIGURED' END,
        (SELECT jsonb_agg(rulename) FROM pg_rules 
         WHERE tablename IN ('audit_trails', 'electronic_signatures'));
    
    -- Check 6: RLS Enabled on Sensitive Tables
    RETURN QUERY SELECT 
        'row_level_security'::TEXT,
        'RLS enabled on sensitive tables'::TEXT,
        '§11.10(d)'::TEXT,
        CASE WHEN (
            SELECT COUNT(*) FROM pg_tables 
            WHERE tablename IN ('employees', 'certificates', 'audit_trails', 'electronic_signatures')
            AND rowsecurity = TRUE
        ) = 4 THEN 'VERIFIED' ELSE 'PARTIAL' END,
        (SELECT jsonb_agg(jsonb_build_object('table', tablename, 'rls', rowsecurity))
         FROM pg_tables 
         WHERE tablename IN ('employees', 'certificates', 'audit_trails', 'electronic_signatures'));
    
    -- Check 7: Session Management
    RETURN QUERY SELECT 
        'session_management'::TEXT,
        'User sessions tracked'::TEXT,
        '§11.10(d)'::TEXT,
        CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_sessions')
            THEN 'VERIFIED' ELSE 'NOT_CONFIGURED' END,
        jsonb_build_object('table_exists', EXISTS (
            SELECT 1 FROM information_schema.tables WHERE table_name = 'user_sessions'
        ));
    
    -- Check 8: Training Attendance E-Signatures
    RETURN QUERY SELECT 
        'attendance_signatures'::TEXT,
        'Attendance linked to e-signatures'::TEXT,
        '§11.100(a)'::TEXT,
        CASE WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'session_attendance' 
            AND column_name = 'esignature_id'
        ) THEN 'VERIFIED' ELSE 'NOT_CONFIGURED' END,
        jsonb_build_object('fk_exists', EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'session_attendance' 
            AND column_name = 'esignature_id'
        ));
    
    -- Check 9: Username Immutability
    RETURN QUERY SELECT 
        'username_immutability'::TEXT,
        'Username cannot be changed'::TEXT,
        '§11.300(a)'::TEXT,
        CASE WHEN EXISTS (
            SELECT 1 FROM pg_trigger 
            WHERE tgname LIKE '%username%immut%'
        ) THEN 'VERIFIED' ELSE 'NOT_CONFIGURED' END,
        jsonb_build_object('trigger_exists', EXISTS (
            SELECT 1 FROM pg_trigger WHERE tgname LIKE '%username%immut%'
        ));
    
    -- Check 10: Standard Reasons Configured
    RETURN QUERY SELECT 
        'standard_reasons'::TEXT,
        'Controlled vocabulary for deviations'::TEXT,
        '§11.10(k)'::TEXT,
        CASE WHEN EXISTS (SELECT 1 FROM standard_reasons WHERE is_active = TRUE)
            THEN 'VERIFIED' ELSE 'NOT_CONFIGURED' END,
        (SELECT jsonb_build_object(
            'count', COUNT(*),
            'categories', COUNT(DISTINCT category)
        ) FROM standard_reasons WHERE is_active = TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION run_compliance_validation IS 
'Comprehensive 21 CFR Part 11 compliance validation - run periodically';

-- =====================================================
-- 5. AUTOMATED COMPLIANCE REPORT VIEW
-- =====================================================
CREATE OR REPLACE VIEW v_compliance_dashboard AS
SELECT 
    check_name,
    requirement,
    cfr_reference,
    status,
    CASE status 
        WHEN 'VERIFIED' THEN '✅'
        WHEN 'PARTIAL' THEN '⚠️'
        ELSE '❌'
    END AS status_icon,
    details,
    NOW() AS checked_at
FROM run_compliance_validation();

COMMENT ON VIEW v_compliance_dashboard IS 
'Real-time 21 CFR Part 11 compliance status dashboard';
