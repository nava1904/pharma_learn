-- ===========================================
-- PART 11 / CSV VERIFICATION QUERIES (SMOKE)
-- Run these after applying schema to demonstrate evidence
-- ===========================================

-- 1) Prove audit trail immutability (should ERROR on UPDATE/DELETE)
-- UPDATE audit_trails SET action = action WHERE id = '<some-id>';
-- DELETE FROM audit_trails WHERE id = '<some-id>';

-- 2) Show 3Ws for a given entity
-- Who / When / What for an entity
-- SELECT performed_by_name, created_at, action, action_category, reason, standard_reason_id
-- FROM audit_trails
-- WHERE entity_type = 'employee_training_obligations' AND entity_id = '<obligation-id>'
-- ORDER BY created_at;

-- 3) Show e-sign manifestation + deterministic record hash
-- SELECT employee_name, timestamp, meaning_display, record_hash, hash_schema_version
-- FROM electronic_signatures
-- WHERE entity_type = 'session_attendance' AND entity_id = '<attendance-id>';

-- 4) Induction gating (DB enforced): non-induction obligations should not be visible for induction-incomplete user
-- SELECT id, item_type, is_induction, status, due_date
-- FROM employee_training_obligations
-- WHERE employee_id = get_user_employee_id()
-- ORDER BY due_date NULLS LAST;

-- 5) Curriculum publish creates obligations (canonical)
-- SELECT publish_curriculum_create_obligations('<curriculum-id>'::uuid);

-- 6) Failed assessment → remedial created (pending disposition)
-- SELECT * FROM remedial_trainings WHERE employee_id = '<employee-id>' ORDER BY created_at DESC;

-- 7) Course revision → certificates obsolete
-- SELECT course_id, status, obsolete_at, obsolescence_reason FROM certificates WHERE course_id = '<course-id>' ORDER BY issue_date DESC;

