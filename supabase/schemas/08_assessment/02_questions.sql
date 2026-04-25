-- ===========================================
-- QUESTIONS
-- ===========================================

-- Questions
CREATE TABLE IF NOT EXISTS questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_bank_id UUID NOT NULL REFERENCES question_banks(id) ON DELETE CASCADE,
    question_number INTEGER NOT NULL,
    question_type question_type NOT NULL,
    question_text TEXT NOT NULL,
    question_text_formatted TEXT,
    question_media JSONB DEFAULT '[]',
    options JSONB,
    correct_answer JSONB NOT NULL,
    explanation TEXT,
    marks NUMERIC(5,2) NOT NULL DEFAULT 1,
    negative_marks NUMERIC(5,2) DEFAULT 0,
    difficulty_level difficulty_level DEFAULT 'medium',
    time_limit_seconds INTEGER,
    tags JSONB DEFAULT '[]',
    is_mandatory BOOLEAN DEFAULT false,
    randomize_options BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(question_bank_id, question_number)
);

CREATE INDEX IF NOT EXISTS idx_questions_bank ON questions(question_bank_id);
CREATE INDEX IF NOT EXISTS idx_questions_type ON questions(question_type);
CREATE INDEX IF NOT EXISTS idx_questions_difficulty ON questions(difficulty_level);

DROP TRIGGER IF EXISTS trg_questions_audit ON questions;
CREATE TRIGGER trg_questions_audit AFTER INSERT OR UPDATE OR DELETE ON questions FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Question Options (for MCQ, Multi-select)
CREATE TABLE IF NOT EXISTS question_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    option_number INTEGER NOT NULL,
    option_text TEXT NOT NULL,
    option_media JSONB,
    is_correct BOOLEAN DEFAULT false,
    points NUMERIC(5,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(question_id, option_number)
);

CREATE INDEX IF NOT EXISTS idx_options_question ON question_options(question_id);

-- Fill in the blanks
CREATE TABLE IF NOT EXISTS question_blanks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    blank_number INTEGER NOT NULL,
    correct_answers JSONB NOT NULL,
    case_sensitive BOOLEAN DEFAULT false,
    partial_marks BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(question_id, blank_number)
);

-- Matching pairs (for match the following)
CREATE TABLE IF NOT EXISTS question_matching_pairs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    pair_number INTEGER NOT NULL,
    left_item TEXT NOT NULL,
    right_item TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(question_id, pair_number)
);
