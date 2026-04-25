-- ===========================================
-- AUDIT CONSOLIDATION MIGRATION
-- Migrates data from 5 legacy audit tables → unified audit_trails
-- then drops the legacy tables.
-- 21 CFR Part 11 §11.10(e) — single inspector query surface
-- ===========================================
--
-- This file is idempotent: each INSERT uses an existence check so re-running
-- is safe on a DB where consolidation already ran. The DROP TABLE statements
-- use IF EXISTS for the same reason.
--
-- Run order: must execute AFTER 02_core/01_audit_log.sql (which adds
--            event_category + field_name columns to audit_trails).
-- ===========================================

DO $$
BEGIN
    -- -------------------------------------------------------
    -- 1. login_audit_trail  →  event_category = LOGIN / FAILED_LOGIN / LOGOUT
    -- -------------------------------------------------------
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = 'login_audit_trail') THEN

        INSERT INTO audit_trails (
            entity_type, entity_id, action, event_category,
            performed_by, performed_by_name,
            ip_address, user_agent, session_id,
            failure_reason, mfa_verified, device_info,
            organization_id, created_at, row_hash, previous_hash
        )
        SELECT
            'authentication'                                AS entity_type,
            COALESCE(employee_id, '00000000-0000-0000-0000-000000000000'::UUID) AS entity_id,
            action                                          AS action,
            CASE action
                WHEN 'login'         THEN 'LOGIN'
                WHEN 'logout'        THEN 'LOGOUT'
                WHEN 'login_failed'  THEN 'FAILED_LOGIN'
                ELSE 'LOGIN'
            END                                             AS event_category,
            employee_id                                     AS performed_by,
            COALESCE(username, 'Unknown')                   AS performed_by_name,
            ip_address,
            user_agent,
            session_id::UUID                                AS session_id,
            failure_reason,
            mfa_verified,
            device_info,
            NULL                                            AS organization_id,
            timestamp                                       AS created_at,
            -- Generate a deterministic placeholder hash for migrated rows
            encode(digest(
                COALESCE(employee_id::TEXT,'') ||
                COALESCE(action,'') ||
                COALESCE(timestamp::TEXT,''),
                'sha256'), 'hex')                           AS row_hash,
            NULL                                            AS previous_hash
        FROM login_audit_trail;

    END IF;

    -- -------------------------------------------------------
    -- 2. security_audit_trail  →  event_category = PERMISSION_CHANGE / DATA_CHANGE
    -- -------------------------------------------------------
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = 'security_audit_trail') THEN

        INSERT INTO audit_trails (
            entity_type, entity_id, action, event_category,
            performed_by, performed_by_name,
            old_value, new_value,
            ip_address, user_agent,
            created_at, row_hash, previous_hash
        )
        SELECT
            COALESCE(target_type, 'security')               AS entity_type,
            COALESCE(target_id, '00000000-0000-0000-0000-000000000000'::UUID) AS entity_id,
            action_type                                      AS action,
            'PERMISSION_CHANGE'                              AS event_category,
            user_id                                          AS performed_by,
            'Migrated'                                       AS performed_by_name,
            old_value,
            new_value,
            ip_address,
            user_agent,
            timestamp                                        AS created_at,
            encode(digest(
                COALESCE(user_id::TEXT,'') ||
                COALESCE(action_type,'') ||
                COALESCE(timestamp::TEXT,''),
                'sha256'), 'hex')                            AS row_hash,
            NULL                                             AS previous_hash
        FROM security_audit_trail;

    END IF;

    -- -------------------------------------------------------
    -- 3. data_access_audit  →  event_category = DATA_ACCESS
    -- -------------------------------------------------------
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = 'data_access_audit') THEN

        INSERT INTO audit_trails (
            entity_type, entity_id, action, event_category,
            performed_by, performed_by_name,
            field_name,
            created_at, row_hash, previous_hash
        )
        SELECT
            COALESCE(table_name, 'unknown')                  AS entity_type,
            COALESCE(record_id, '00000000-0000-0000-0000-000000000000'::UUID) AS entity_id,
            COALESCE(access_type, 'read')                    AS action,
            'DATA_ACCESS'                                    AS event_category,
            user_id                                          AS performed_by,
            'Migrated'                                       AS performed_by_name,
            COALESCE(query_type, 'SELECT')                   AS field_name,
            timestamp                                        AS created_at,
            encode(digest(
                COALESCE(user_id::TEXT,'') ||
                COALESCE(table_name,'') ||
                COALESCE(timestamp::TEXT,''),
                'sha256'), 'hex')                            AS row_hash,
            NULL                                             AS previous_hash
        FROM data_access_audit;

    END IF;

    -- -------------------------------------------------------
    -- 4. permission_change_audit  →  event_category = PERMISSION_CHANGE
    -- -------------------------------------------------------
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = 'permission_change_audit') THEN

        INSERT INTO audit_trails (
            entity_type, entity_id, action, event_category,
            performed_by, performed_by_name,
            old_value, new_value,
            reason,
            created_at, row_hash, previous_hash
        )
        SELECT
            'employee_role'                                  AS entity_type,
            COALESCE(target_user_id, '00000000-0000-0000-0000-000000000000'::UUID) AS entity_id,
            change_type                                      AS action,
            'PERMISSION_CHANGE'                              AS event_category,
            changed_by                                       AS performed_by,
            'Migrated'                                       AS performed_by_name,
            old_permissions                                  AS old_value,
            new_permissions                                  AS new_value,
            reason,
            timestamp                                        AS created_at,
            encode(digest(
                COALESCE(changed_by::TEXT,'') ||
                COALESCE(change_type,'') ||
                COALESCE(timestamp::TEXT,''),
                'sha256'), 'hex')                            AS row_hash,
            NULL                                             AS previous_hash
        FROM permission_change_audit;

    END IF;

    -- -------------------------------------------------------
    -- 5. system_config_audit  →  event_category = CONFIG_CHANGE
    -- -------------------------------------------------------
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = 'system_config_audit') THEN

        INSERT INTO audit_trails (
            entity_type, entity_id, action, event_category,
            performed_by, performed_by_name,
            field_name, old_value, new_value, reason,
            created_at, row_hash, previous_hash
        )
        SELECT
            COALESCE(config_category, 'system_config')       AS entity_type,
            '00000000-0000-0000-0000-000000000000'::UUID      AS entity_id,
            'config_changed'                                  AS action,
            'CONFIG_CHANGE'                                   AS event_category,
            changed_by                                        AS performed_by,
            'Migrated'                                        AS performed_by_name,
            config_key                                        AS field_name,
            old_value,
            new_value,
            change_reason                                     AS reason,
            timestamp                                         AS created_at,
            encode(digest(
                COALESCE(changed_by::TEXT,'') ||
                COALESCE(config_key,'') ||
                COALESCE(timestamp::TEXT,''),
                'sha256'), 'hex')                             AS row_hash,
            NULL                                              AS previous_hash
        FROM system_config_audit;

    END IF;

END
$$;

-- -------------------------------------------------------
-- DROP legacy tables (data is now in audit_trails)
-- Using IF EXISTS so this is safe to re-run.
-- -------------------------------------------------------
DROP TABLE IF EXISTS login_audit_trail      CASCADE;
DROP TABLE IF EXISTS security_audit_trail   CASCADE;
DROP TABLE IF EXISTS data_access_audit      CASCADE;
DROP TABLE IF EXISTS permission_change_audit CASCADE;
DROP TABLE IF EXISTS system_config_audit    CASCADE;

-- -------------------------------------------------------
-- Helper view: backward-compatible surface for LOGIN events
-- (allows any existing queries against login_audit_trail
--  to be redirected here during the transition window)
-- -------------------------------------------------------
CREATE OR REPLACE VIEW v_login_events AS
SELECT
    id,
    performed_by                         AS employee_id,
    performed_by_name                    AS username,
    action,
    event_category                       AS status,
    failure_reason,
    ip_address,
    user_agent,
    session_id,
    mfa_verified,
    device_info,
    created_at                           AS timestamp
FROM audit_trails
WHERE event_category IN ('LOGIN', 'LOGOUT', 'FAILED_LOGIN', 'SESSION_TIMEOUT');

COMMENT ON VIEW v_login_events IS
    'Backward-compatible view over audit_trails for LOGIN/LOGOUT/FAILED events. '
    'Replaces the dropped login_audit_trail table.';
