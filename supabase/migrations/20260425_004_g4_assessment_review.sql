-- Migration: Add requires_review flag for manual grading scenarios
-- Gap G4: assessment_attempts.requires_review for open-ended questions
-- Reference: Design Decision Q5 (mix of MCQ + fill-in + open-ended)

ALTER TABLE assessment_attempts
ADD COLUMN IF NOT EXISTS requires_review BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN assessment_attempts.requires_review IS 
  'TRUE if attempt contains open-ended questions requiring manual grader review before certification.';

-- Index for finding attempts pending review
CREATE INDEX IF NOT EXISTS idx_assessment_attempts_review 
  ON assessment_attempts(requires_review, status) 
  WHERE requires_review = TRUE AND status = 'submitted';
