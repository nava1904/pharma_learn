-- Migration: Compliance calculation functions for lifecycle monitor
-- Gap G5: SQL functions for compliance metrics
-- Reference: Design Decision Q8 (compliance = completed / (completed + overdue), waivers excluded)

-- Function: Calculate individual employee compliance rate
CREATE OR REPLACE FUNCTION calculate_employee_compliance(
  p_employee_id UUID,
  p_as_of_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  total_obligations BIGINT,
  completed BIGINT,
  overdue BIGINT,
  pending BIGINT,
  waived BIGINT,
  compliance_rate NUMERIC(5,2)
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH obligation_stats AS (
    SELECT
      COUNT(*) AS total,
      COUNT(*) FILTER (WHERE ea.status = 'completed') AS completed_count,
      COUNT(*) FILTER (WHERE ea.status IN ('assigned', 'in_progress') AND ea.due_date < p_as_of_date) AS overdue_count,
      COUNT(*) FILTER (WHERE ea.status IN ('assigned', 'in_progress') AND ea.due_date >= p_as_of_date) AS pending_count,
      COUNT(*) FILTER (WHERE ea.status = 'waived') AS waived_count
    FROM employee_assignments ea
    WHERE ea.employee_id = p_employee_id
  )
  SELECT 
    os.total AS total_obligations,
    os.completed_count AS completed,
    os.overdue_count AS overdue,
    os.pending_count AS pending,
    os.waived_count AS waived,
    CASE 
      WHEN (os.completed_count + os.overdue_count) = 0 THEN 100.00
      ELSE ROUND((os.completed_count::NUMERIC / (os.completed_count + os.overdue_count)::NUMERIC) * 100, 2)
    END AS compliance_rate
  FROM obligation_stats os;
END;
$$;

-- Function: Calculate department/org-wide compliance
CREATE OR REPLACE FUNCTION calculate_org_compliance(
  p_org_id UUID,
  p_department_id UUID DEFAULT NULL,
  p_as_of_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  total_employees BIGINT,
  total_obligations BIGINT,
  completed BIGINT,
  overdue BIGINT,
  pending BIGINT,
  waived BIGINT,
  compliance_rate NUMERIC(5,2)
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH filtered_employees AS (
    SELECT e.id
    FROM employees e
    WHERE e.org_id = p_org_id
      AND e.status = 'active'
      AND (p_department_id IS NULL OR e.department_id = p_department_id)
  ),
  obligation_stats AS (
    SELECT
      COUNT(DISTINCT ea.employee_id) AS emp_count,
      COUNT(*) AS total,
      COUNT(*) FILTER (WHERE ea.status = 'completed') AS completed_count,
      COUNT(*) FILTER (WHERE ea.status IN ('assigned', 'in_progress') AND ea.due_date < p_as_of_date) AS overdue_count,
      COUNT(*) FILTER (WHERE ea.status IN ('assigned', 'in_progress') AND ea.due_date >= p_as_of_date) AS pending_count,
      COUNT(*) FILTER (WHERE ea.status = 'waived') AS waived_count
    FROM employee_assignments ea
    JOIN filtered_employees fe ON ea.employee_id = fe.id
  )
  SELECT 
    os.emp_count AS total_employees,
    os.total AS total_obligations,
    os.completed_count AS completed,
    os.overdue_count AS overdue,
    os.pending_count AS pending,
    os.waived_count AS waived,
    CASE 
      WHEN (os.completed_count + os.overdue_count) = 0 THEN 100.00
      ELSE ROUND((os.completed_count::NUMERIC / (os.completed_count + os.overdue_count)::NUMERIC) * 100, 2)
    END AS compliance_rate
  FROM obligation_stats os;
END;
$$;

-- Function: Get compliance breakdown by course for an org
CREATE OR REPLACE FUNCTION get_course_compliance_breakdown(
  p_org_id UUID,
  p_as_of_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  course_id UUID,
  course_title TEXT,
  total_assignments BIGINT,
  completed BIGINT,
  overdue BIGINT,
  compliance_rate NUMERIC(5,2)
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id AS course_id,
    c.title AS course_title,
    COUNT(*) AS total_assignments,
    COUNT(*) FILTER (WHERE ea.status = 'completed') AS completed,
    COUNT(*) FILTER (WHERE ea.status IN ('assigned', 'in_progress') AND ea.due_date < p_as_of_date) AS overdue,
    CASE 
      WHEN (COUNT(*) FILTER (WHERE ea.status = 'completed') + 
            COUNT(*) FILTER (WHERE ea.status IN ('assigned', 'in_progress') AND ea.due_date < p_as_of_date)) = 0 
      THEN 100.00
      ELSE ROUND(
        (COUNT(*) FILTER (WHERE ea.status = 'completed')::NUMERIC / 
         (COUNT(*) FILTER (WHERE ea.status = 'completed') + 
          COUNT(*) FILTER (WHERE ea.status IN ('assigned', 'in_progress') AND ea.due_date < p_as_of_date))::NUMERIC) * 100, 
        2)
    END AS compliance_rate
  FROM courses c
  JOIN training_assignments ta ON ta.course_id = c.id
  JOIN employee_assignments ea ON ea.training_assignment_id = ta.id
  JOIN employees e ON ea.employee_id = e.id
  WHERE e.org_id = p_org_id
    AND ea.status != 'waived'  -- Exclude waived from compliance calculation
  GROUP BY c.id, c.title
  ORDER BY compliance_rate ASC;  -- Worst compliance first
END;
$$;

-- Function: Get employees at risk (overdue or due soon)
CREATE OR REPLACE FUNCTION get_at_risk_employees(
  p_org_id UUID,
  p_due_within_days INTEGER DEFAULT 7
)
RETURNS TABLE (
  employee_id UUID,
  employee_name TEXT,
  overdue_count BIGINT,
  due_soon_count BIGINT,
  compliance_rate NUMERIC(5,2)
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH emp_stats AS (
    SELECT 
      e.id,
      e.first_name || ' ' || e.last_name AS name,
      COUNT(*) FILTER (WHERE ea.status IN ('assigned', 'in_progress') AND ea.due_date < CURRENT_DATE) AS overdue,
      COUNT(*) FILTER (WHERE ea.status IN ('assigned', 'in_progress') AND ea.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + p_due_within_days) AS due_soon,
      COUNT(*) FILTER (WHERE ea.status = 'completed') AS completed
    FROM employees e
    JOIN employee_assignments ea ON ea.employee_id = e.id
    WHERE e.org_id = p_org_id
      AND e.status = 'active'
      AND ea.status != 'waived'
    GROUP BY e.id, e.first_name, e.last_name
  )
  SELECT 
    es.id AS employee_id,
    es.name AS employee_name,
    es.overdue AS overdue_count,
    es.due_soon AS due_soon_count,
    CASE 
      WHEN (es.completed + es.overdue) = 0 THEN 100.00
      ELSE ROUND((es.completed::NUMERIC / (es.completed + es.overdue)::NUMERIC) * 100, 2)
    END AS compliance_rate
  FROM emp_stats es
  WHERE es.overdue > 0 OR es.due_soon > 0
  ORDER BY es.overdue DESC, es.due_soon DESC;
END;
$$;

COMMENT ON FUNCTION calculate_employee_compliance IS 
  'Calculate compliance rate for a single employee. Formula: completed / (completed + overdue). Waivers excluded.';
COMMENT ON FUNCTION calculate_org_compliance IS 
  'Calculate org-wide or department-wide compliance rate.';
COMMENT ON FUNCTION get_course_compliance_breakdown IS 
  'Get compliance breakdown by course, sorted by worst compliance first.';
COMMENT ON FUNCTION get_at_risk_employees IS 
  'Get employees with overdue or upcoming-due training assignments.';
