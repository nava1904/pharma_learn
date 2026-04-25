-- ===========================================
-- TRAINING COORDINATOR ASSIGNMENTS
-- Site Training Coordinator is first-class in EE URS §5.1.27-45
-- Manages plant/department-level training programs
-- ===========================================

CREATE TABLE IF NOT EXISTS training_coordinator_assignments (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- The training coordinator employee
    coordinator_id          UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,

    -- Scope of the coordinator's responsibility
    scope                   TEXT NOT NULL DEFAULT 'PLANT'
                                CHECK (scope IN (
                                    'ORGANIZATION',  -- Cross-plant / global coordinator
                                    'PLANT',         -- Site-level training coordinator (EE §5.1.27)
                                    'DEPARTMENT'     -- Department-level training officer
                                )),

    -- Applicability (set according to scope)
    organization_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id                UUID REFERENCES plants(id) ON DELETE CASCADE,       -- set when scope = PLANT or DEPARTMENT
    department_id           UUID REFERENCES departments(id) ON DELETE CASCADE,  -- set when scope = DEPARTMENT

    -- Temporal bounds
    starts_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at                 TIMESTAMPTZ,            -- NULL = indefinite

    -- Backup coordinator (covers absences per §5.1.44)
    backup_coordinator_id   UUID REFERENCES employees(id) ON DELETE SET NULL,

    -- Authorization
    assigned_by             UUID REFERENCES employees(id) ON DELETE SET NULL,
    assignment_esig_id      UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,

    -- Status
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    deactivation_reason     TEXT,

    -- Timestamps
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,

    CONSTRAINT chk_plant_scope     CHECK (scope != 'PLANT'       OR plant_id IS NOT NULL),
    CONSTRAINT chk_dept_scope      CHECK (scope != 'DEPARTMENT'  OR department_id IS NOT NULL),
    CONSTRAINT chk_coordinator_dates CHECK (ends_at IS NULL OR ends_at > starts_at),
    CONSTRAINT chk_no_self_backup  CHECK (coordinator_id != backup_coordinator_id OR backup_coordinator_id IS NULL)
);

CREATE INDEX IF NOT EXISTS idx_tc_assignments_coordinator ON training_coordinator_assignments(coordinator_id);
CREATE INDEX IF NOT EXISTS idx_tc_assignments_plant       ON training_coordinator_assignments(plant_id);
CREATE INDEX IF NOT EXISTS idx_tc_assignments_department  ON training_coordinator_assignments(department_id);
CREATE INDEX IF NOT EXISTS idx_tc_assignments_active      ON training_coordinator_assignments(is_active, starts_at, ends_at)
    WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_tc_assignments_org         ON training_coordinator_assignments(organization_id);

DROP TRIGGER IF EXISTS trg_tc_assignments_updated ON training_coordinator_assignments;
CREATE TRIGGER trg_tc_assignments_updated
    BEFORE UPDATE ON training_coordinator_assignments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_tc_assignments_audit ON training_coordinator_assignments;
CREATE TRIGGER trg_tc_assignments_audit
    AFTER INSERT OR UPDATE OR DELETE ON training_coordinator_assignments
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- FUNCTION: get active training coordinator for a plant/dept
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_training_coordinator(
    p_plant_id       UUID DEFAULT NULL,
    p_department_id  UUID DEFAULT NULL,
    p_at_time        TIMESTAMPTZ DEFAULT NOW()
) RETURNS TABLE (
    coordinator_id      UUID,
    backup_coordinator  UUID,
    scope               TEXT
) AS $$
BEGIN
    -- Department-specific first, then plant-level, then org-level
    RETURN QUERY
    SELECT
        tca.coordinator_id,
        tca.backup_coordinator_id,
        tca.scope
    FROM training_coordinator_assignments tca
    WHERE tca.is_active = TRUE
      AND tca.starts_at <= p_at_time
      AND (tca.ends_at IS NULL OR tca.ends_at > p_at_time)
      AND (
          (p_department_id IS NOT NULL AND tca.department_id = p_department_id AND tca.scope = 'DEPARTMENT')
          OR
          (p_plant_id IS NOT NULL AND tca.plant_id = p_plant_id AND tca.scope = 'PLANT' AND p_department_id IS NULL)
          OR
          (tca.scope = 'ORGANIZATION' AND p_plant_id IS NULL)
      )
    ORDER BY
        CASE tca.scope WHEN 'DEPARTMENT' THEN 1 WHEN 'PLANT' THEN 2 ELSE 3 END
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON TABLE  training_coordinator_assignments IS 'Site Training Coordinator assignments per EE URS §5.1.27-45';
COMMENT ON COLUMN training_coordinator_assignments.scope IS 'ORGANIZATION=cross-plant; PLANT=site coordinator; DEPARTMENT=dept officer';
COMMENT ON COLUMN training_coordinator_assignments.backup_coordinator_id IS 'Covers coordinator absences (EE §5.1.44)';
COMMENT ON FUNCTION get_training_coordinator IS 'Returns the active training coordinator for a plant/department; department-specific takes priority';
