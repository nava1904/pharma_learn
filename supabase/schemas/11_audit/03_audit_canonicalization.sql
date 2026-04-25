-- ===========================================
-- AUDIT CANONICALIZATION
-- Stream module-specific audit tables into canonical audit_trails
-- ===========================================

-- Login audit → canonical audit_trails
CREATE OR REPLACE FUNCTION stream_login_audit_to_canonical()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trails (
        entity_type,
        entity_id,
        action,
        action_category,
        action_description,
        new_value,
        performed_by,
        performed_by_name,
        ip_address,
        user_agent,
        created_at,
        organization_id
    ) VALUES (
        'login_session',
        COALESCE(NEW.employee_id, uuid_generate_v4()),
        NEW.action,
        'login',
        NEW.failure_reason,
        to_jsonb(NEW),
        NEW.employee_id,
        COALESCE(NEW.username, 'System'),
        NEW.ip_address,
        NEW.user_agent,
        NEW.timestamp,
        get_user_organization_id()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_login_audit_stream ON login_audit_trail;
CREATE TRIGGER trg_login_audit_stream
    AFTER INSERT ON login_audit_trail
    FOR EACH ROW EXECUTE FUNCTION stream_login_audit_to_canonical();

-- Security audit → canonical audit_trails
CREATE OR REPLACE FUNCTION stream_security_audit_to_canonical()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trails (
        entity_type,
        entity_id,
        action,
        action_category,
        action_description,
        old_value,
        new_value,
        performed_by,
        performed_by_name,
        ip_address,
        user_agent,
        created_at,
        organization_id
    ) VALUES (
        COALESCE(NEW.target_type, 'security_event'),
        COALESCE(NEW.target_id, uuid_generate_v4()),
        NEW.action_type,
        'security',
        NEW.action_description,
        NEW.old_value,
        NEW.new_value,
        NEW.user_id,
        'System',
        NEW.ip_address,
        NEW.user_agent,
        NEW.timestamp,
        get_user_organization_id()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_security_audit_stream ON security_audit_trail;
CREATE TRIGGER trg_security_audit_stream
    AFTER INSERT ON security_audit_trail
    FOR EACH ROW EXECUTE FUNCTION stream_security_audit_to_canonical();

