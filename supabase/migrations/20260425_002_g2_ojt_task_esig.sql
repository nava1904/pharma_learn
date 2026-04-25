-- Migration: Add e-signature to OJT task completion (optional per-task e-sig)
-- Gap G2: Per-task e-signature for OJT task sign-off
-- Reference: Design Decision Q3

ALTER TABLE ojt_task_completion
ADD COLUMN IF NOT EXISTS esignature_id UUID REFERENCES electronic_signatures(id);

COMMENT ON COLUMN ojt_task_completion.esignature_id IS 
  'Optional per-task e-signature from evaluator. Required if org SOP mandates per-task 21 CFR Part 11 compliance.';

-- Index for audit trail lookups
CREATE INDEX IF NOT EXISTS idx_ojt_task_completion_esig 
  ON ojt_task_completion(esignature_id) 
  WHERE esignature_id IS NOT NULL;
