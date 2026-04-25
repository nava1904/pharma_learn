-- ===========================================
-- EMPLOYEE TRAINING STATUS MATERIALIZED VIEW
-- Single-query surface for plant-wise compliance dashboards
-- Alfa URS §4.3.3 — Plant Wise User List
-- ===========================================

-- Materialized view for employee training status (refreshed nightly by lifecycle_monitor)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_employee_training_status AS
SELECT
    e.id AS employee_id,
    e.employee_id AS employee_code,
    e.first_name || ' ' || e.last_name AS full_name,
    e.designation,
    e.email,
    e.organization_id,
    e.plant_id,
    e.department_id,
    e.status AS employee_status,
    e.induction_completed,
    e.induction_completed_at,
    e.hire_date,

    -- Compliance metrics
    COALESCE(obl.total_obligations, 0) AS total_obligations,
    COALESCE(obl.completed_obligations, 0) AS completed_obligations,
    COALESCE(obl.pending_obligations, 0) AS pending_obligations,
    COALESCE(obl.overdue_obligations, 0) AS overdue_obligations,
    COALESCE(obl.in_progress_obligations, 0) AS in_progress_obligations,
    COALESCE(obl.waived_obligations, 0) AS waived_obligations,

    -- Compliance percentage
    CASE
        WHEN COALESCE(obl.total_obligations, 0) = 0 THEN 100.00
        ELSE ROUND((COALESCE(obl.completed_obligations, 0)::NUMERIC / obl.total_obligations) * 100, 2)
    END AS compliance_percentage,

    -- RAG status
    CASE
        WHEN COALESCE(obl.overdue_obligations, 0) > 0 THEN 'RED'
        WHEN COALESCE(obl.pending_obligations, 0) > 0 THEN 'AMBER'
        ELSE 'GREEN'
    END AS compliance_rag,

    -- Most urgent due date
    obl.earliest_due_date,
    obl.days_until_next_due,

    -- Assessment metrics
    COALESCE(asmt.total_assessments, 0) AS total_assessments,
    COALESCE(asmt.passed_assessments, 0) AS passed_assessments,
    COALESCE(asmt.failed_assessments, 0) AS failed_assessments,
    COALESCE(asmt.average_score, 0) AS average_assessment_score,

    -- Certificate count
    COALESCE(cert.active_certificates, 0) AS active_certificates,
    COALESCE(cert.expiring_soon, 0) AS certificates_expiring_soon,

    -- Last activity
    obl.last_completion_date,
    asmt.last_assessment_date,

    -- Refresh timestamp
    NOW() AS refreshed_at

FROM employees e

-- Obligation aggregates
LEFT JOIN LATERAL (
    SELECT
        COUNT(*) AS total_obligations,
        COUNT(*) FILTER (WHERE status = 'completed') AS completed_obligations,
        COUNT(*) FILTER (WHERE status = 'pending') AS pending_obligations,
        COUNT(*) FILTER (WHERE status = 'overdue' OR (status = 'pending' AND due_date < CURRENT_DATE)) AS overdue_obligations,
        COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress_obligations,
        COUNT(*) FILTER (WHERE status = 'waived') AS waived_obligations,
        MIN(due_date) FILTER (WHERE status IN ('pending', 'in_progress') AND due_date >= CURRENT_DATE) AS earliest_due_date,
        EXTRACT(DAY FROM MIN(due_date) FILTER (WHERE status IN ('pending', 'in_progress') AND due_date >= CURRENT_DATE) - CURRENT_DATE)::INTEGER AS days_until_next_due,
        MAX(completed_at) AS last_completion_date
    FROM employee_training_obligations
    WHERE employee_id = e.id AND status NOT IN ('cancelled')
) obl ON TRUE

-- Assessment aggregates
LEFT JOIN LATERAL (
    SELECT
        COUNT(*) AS total_assessments,
        COUNT(*) FILTER (WHERE is_passed = TRUE) AS passed_assessments,
        COUNT(*) FILTER (WHERE is_passed = FALSE) AS failed_assessments,
        AVG(percentage) AS average_score,
        MAX(submitted_at) AS last_assessment_date
    FROM assessment_attempts
    WHERE employee_id = e.id AND status = 'completed'
) asmt ON TRUE

-- Certificate aggregates
LEFT JOIN LATERAL (
    SELECT
        COUNT(*) FILTER (WHERE status = 'active') AS active_certificates,
        COUNT(*) FILTER (WHERE status = 'active' AND expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days') AS expiring_soon
    FROM certificates
    WHERE employee_id = e.id
) cert ON TRUE

WHERE e.status = 'active';

-- Indexes on materialized view for dashboard queries
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_training_status_employee ON mv_employee_training_status(employee_id);
CREATE INDEX IF NOT EXISTS idx_mv_training_status_org ON mv_employee_training_status(organization_id);
CREATE INDEX IF NOT EXISTS idx_mv_training_status_plant ON mv_employee_training_status(plant_id);
CREATE INDEX IF NOT EXISTS idx_mv_training_status_dept ON mv_employee_training_status(department_id);
CREATE INDEX IF NOT EXISTS idx_mv_training_status_rag ON mv_employee_training_status(compliance_rag);
CREATE INDEX IF NOT EXISTS idx_mv_training_status_overdue ON mv_employee_training_status(overdue_obligations DESC);

-- Function to refresh the materialized view (called by lifecycle_monitor cron job)
CREATE OR REPLACE FUNCTION refresh_employee_training_status()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_employee_training_status;
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------------
-- PLANT-WISE COMPLIANCE SUMMARY VIEW
-- Aggregates mv_employee_training_status by plant
-- -------------------------------------------------------
CREATE OR REPLACE VIEW v_plant_compliance_summary AS
SELECT
    plant_id,
    COUNT(*) AS total_employees,
    COUNT(*) FILTER (WHERE compliance_rag = 'GREEN') AS green_count,
    COUNT(*) FILTER (WHERE compliance_rag = 'AMBER') AS amber_count,
    COUNT(*) FILTER (WHERE compliance_rag = 'RED') AS red_count,
    ROUND(AVG(compliance_percentage), 2) AS avg_compliance_percentage,
    SUM(overdue_obligations) AS total_overdue_obligations,
    SUM(pending_obligations) AS total_pending_obligations,
    SUM(completed_obligations) AS total_completed_obligations,
    COUNT(*) FILTER (WHERE induction_completed = FALSE) AS pending_inductions,
    NOW() AS calculated_at
FROM mv_employee_training_status
GROUP BY plant_id;

-- -------------------------------------------------------
-- DEPARTMENT-WISE COMPLIANCE SUMMARY VIEW
-- -------------------------------------------------------
CREATE OR REPLACE VIEW v_department_compliance_summary AS
SELECT
    department_id,
    plant_id,
    organization_id,
    COUNT(*) AS total_employees,
    COUNT(*) FILTER (WHERE compliance_rag = 'GREEN') AS green_count,
    COUNT(*) FILTER (WHERE compliance_rag = 'AMBER') AS amber_count,
    COUNT(*) FILTER (WHERE compliance_rag = 'RED') AS red_count,
    ROUND(AVG(compliance_percentage), 2) AS avg_compliance_percentage,
    SUM(overdue_obligations) AS total_overdue_obligations,
    SUM(pending_obligations) AS total_pending_obligations,
    NOW() AS calculated_at
FROM mv_employee_training_status
GROUP BY department_id, plant_id, organization_id;

COMMENT ON MATERIALIZED VIEW mv_employee_training_status IS 'Single-query surface for employee training compliance — refreshed nightly (Alfa §4.3.3)';
COMMENT ON VIEW v_plant_compliance_summary IS 'Plant-level compliance aggregates for dashboard display';
COMMENT ON VIEW v_department_compliance_summary IS 'Department-level compliance aggregates for drill-down';
