-- ===========================================
-- G7: ASSIGNMENT & GRADING FIXES
-- Fixes constraint gaps identified in schema review
-- ===========================================

-- ---------------------------------------------------------------------------
-- 1. UNIQUE CONSTRAINT: employee_assignments(assignment_id, employee_id)
-- Without this, ON CONFLICT DO NOTHING silently ignores all errors
-- ---------------------------------------------------------------------------
ALTER TABLE employee_assignments 
ADD CONSTRAINT uq_employee_assignment 
UNIQUE (assignment_id, employee_id);

-- ---------------------------------------------------------------------------
-- 2. ENUM VALUE: assignment_status 'blocked'
-- For prerequisite-blocked assignments per business rules
-- ---------------------------------------------------------------------------
ALTER TYPE assignment_status ADD VALUE IF NOT EXISTS 'blocked';

-- Also add 'pending' if missing (some handlers reference it)
ALTER TYPE assignment_status ADD VALUE IF NOT EXISTS 'pending';

-- ---------------------------------------------------------------------------
-- 3. ALTER grading_queue: Add moderation columns
-- Two-person grading with moderation for discrepancies
-- ---------------------------------------------------------------------------

-- First grader's score
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS grade_1_score NUMERIC(5,2);

-- First grader identity
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS grade_1_by UUID REFERENCES employees(id);

-- When first grade was given
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS grade_1_at TIMESTAMPTZ;

-- Second grader's score (for two-person grading)
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS grade_2_score NUMERIC(5,2);

-- Second grader identity
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS grade_2_by UUID REFERENCES employees(id);

-- When second grade was given
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS grade_2_at TIMESTAMPTZ;

-- Flag indicating discrepancy between graders exceeds threshold
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS moderation_required BOOLEAN DEFAULT FALSE;

-- Moderator who resolved the discrepancy
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS moderator_id UUID REFERENCES employees(id);

-- When moderation occurred
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMPTZ;

-- Moderator's comments on the decision
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS moderation_comments TEXT;

-- Final agreed score after moderation or averaging
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS final_score NUMERIC(5,2);

-- Grading rubric used (JSON structure for feedback)
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS rubric_scores JSONB;

-- Feedback to student
ALTER TABLE grading_queue 
ADD COLUMN IF NOT EXISTS feedback TEXT;

-- ---------------------------------------------------------------------------
-- 4. INDEX for grading queue: pending moderation items
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_grading_queue_moderation 
ON grading_queue(moderation_required, status) 
WHERE moderation_required = TRUE AND status != 'completed';

-- ---------------------------------------------------------------------------
-- 5. COMMENTS
-- ---------------------------------------------------------------------------
COMMENT ON CONSTRAINT uq_employee_assignment ON employee_assignments 
IS 'Prevents duplicate assignment of same training to same employee';

COMMENT ON COLUMN grading_queue.grade_1_score IS 'First grader''s score (0-100)';
COMMENT ON COLUMN grading_queue.grade_2_score IS 'Second grader''s score for two-person grading';
COMMENT ON COLUMN grading_queue.moderation_required IS 'TRUE if grade_1 and grade_2 differ by more than threshold';
COMMENT ON COLUMN grading_queue.final_score IS 'Final score after moderation or averaging';
COMMENT ON COLUMN grading_queue.rubric_scores IS 'Per-criterion scores from grading rubric';
