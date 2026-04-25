-- =====================================================
-- 17_extensions/08_xapi_constraints.sql
-- xAPI Statement Validation & Integrity Constraints
-- Ensures xAPI/Tin Can compliance per spec
-- =====================================================

-- =====================================================
-- xAPI Statement Validation Function
-- Validates statement_json conforms to xAPI 1.0.3 spec
-- =====================================================
CREATE OR REPLACE FUNCTION validate_xapi_statement(statement JSONB)
RETURNS BOOLEAN AS $$
DECLARE
    actor JSONB;
    verb JSONB;
    obj JSONB;
BEGIN
    -- Actor is required
    actor := statement->'actor';
    IF actor IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Actor must have mbox, mbox_sha1sum, openid, or account
    IF actor->>'mbox' IS NULL 
       AND actor->>'mbox_sha1sum' IS NULL 
       AND actor->>'openid' IS NULL 
       AND actor->'account' IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Verb is required with id
    verb := statement->'verb';
    IF verb IS NULL OR verb->>'id' IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Object is required with id or objectType
    obj := statement->'object';
    IF obj IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Object must have id (for Activity) or objectType for Agent/Group/Statement
    IF obj->>'id' IS NULL AND obj->>'objectType' IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- If result exists, validate score
    IF statement->'result'->'score' IS NOT NULL THEN
        -- If scaled present, must be -1 to 1
        IF (statement->'result'->'score'->>'scaled')::NUMERIC IS NOT NULL THEN
            IF (statement->'result'->'score'->>'scaled')::NUMERIC < -1 
               OR (statement->'result'->'score'->>'scaled')::NUMERIC > 1 THEN
                RETURN FALSE;
            END IF;
        END IF;
        
        -- If raw/min/max present, raw must be between min and max
        IF (statement->'result'->'score'->>'raw')::NUMERIC IS NOT NULL THEN
            IF (statement->'result'->'score'->>'min')::NUMERIC IS NOT NULL 
               AND (statement->'result'->'score'->>'raw')::NUMERIC < (statement->'result'->'score'->>'min')::NUMERIC THEN
                RETURN FALSE;
            END IF;
            IF (statement->'result'->'score'->>'max')::NUMERIC IS NOT NULL 
               AND (statement->'result'->'score'->>'raw')::NUMERIC > (statement->'result'->'score'->>'max')::NUMERIC THEN
                RETURN FALSE;
            END IF;
        END IF;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION validate_xapi_statement IS 'Validates xAPI statement JSON structure per xAPI 1.0.3 specification';

-- =====================================================
-- Add Constraint to xapi_statements Table
-- =====================================================
ALTER TABLE xapi_statements
    ADD CONSTRAINT chk_valid_xapi_statement 
    CHECK (validate_xapi_statement(statement_json));

-- =====================================================
-- xAPI Statement Normalization Trigger
-- Auto-extracts indexed fields from statement_json
-- =====================================================
CREATE OR REPLACE FUNCTION normalize_xapi_statement()
RETURNS TRIGGER AS $$
BEGIN
    -- Extract verb from statement
    NEW.verb := NEW.statement_json->'verb'->>'id';
    
    -- Extract object type (defaults to Activity per spec)
    NEW.object_type := COALESCE(NEW.statement_json->'object'->>'objectType', 'Activity');
    
    -- Extract object id
    NEW.object_id := NEW.statement_json->'object'->>'id';
    
    -- Extract result fields if present
    NEW.result_completion := (NEW.statement_json->'result'->>'completion')::BOOLEAN;
    NEW.result_success := (NEW.statement_json->'result'->>'success')::BOOLEAN;
    NEW.result_score := (NEW.statement_json->'result'->'score'->>'scaled')::NUMERIC;
    
    -- Set stored timestamp
    NEW.stored_at := COALESCE(NEW.stored_at, NOW());
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_xapi_statement ON xapi_statements;
CREATE TRIGGER trg_normalize_xapi_statement
    BEFORE INSERT ON xapi_statements
    FOR EACH ROW EXECUTE FUNCTION normalize_xapi_statement();

COMMENT ON FUNCTION normalize_xapi_statement IS 'Extracts indexed fields from xAPI statement JSON for efficient querying';

-- =====================================================
-- xAPI Statement Audit Trail
-- Immutability for stored statements (per xAPI spec)
-- =====================================================
CREATE RULE xapi_statements_no_update AS 
    ON UPDATE TO xapi_statements 
    DO INSTEAD NOTHING;

CREATE RULE xapi_statements_no_delete AS 
    ON DELETE TO xapi_statements 
    WHERE OLD.stored_at < NOW() - INTERVAL '1 second'
    DO INSTEAD NOTHING;

-- =====================================================
-- xAPI Verb Registry (Common Verbs)
-- =====================================================
CREATE TABLE IF NOT EXISTS xapi_verb_registry (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    verb_id TEXT NOT NULL UNIQUE,
    display_name JSONB NOT NULL DEFAULT '{"en-US": "Unknown"}',
    description TEXT,
    is_standard BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO xapi_verb_registry (verb_id, display_name, description, is_standard) VALUES
    ('http://adlnet.gov/expapi/verbs/completed', '{"en-US": "completed"}', 'Completed a learning activity', TRUE),
    ('http://adlnet.gov/expapi/verbs/passed', '{"en-US": "passed"}', 'Passed a test or assessment', TRUE),
    ('http://adlnet.gov/expapi/verbs/failed', '{"en-US": "failed"}', 'Failed a test or assessment', TRUE),
    ('http://adlnet.gov/expapi/verbs/attempted', '{"en-US": "attempted"}', 'Attempted a learning activity', TRUE),
    ('http://adlnet.gov/expapi/verbs/experienced', '{"en-US": "experienced"}', 'Experienced content', TRUE),
    ('http://adlnet.gov/expapi/verbs/launched', '{"en-US": "launched"}', 'Launched a learning activity', TRUE),
    ('http://adlnet.gov/expapi/verbs/answered', '{"en-US": "answered"}', 'Answered a question', TRUE),
    ('http://adlnet.gov/expapi/verbs/interacted', '{"en-US": "interacted"}', 'Interacted with content', TRUE),
    ('http://adlnet.gov/expapi/verbs/progressed', '{"en-US": "progressed"}', 'Made progress in activity', TRUE),
    ('http://adlnet.gov/expapi/verbs/mastered', '{"en-US": "mastered"}', 'Demonstrated mastery', TRUE),
    ('http://adlnet.gov/expapi/verbs/scored', '{"en-US": "scored"}', 'Achieved a score', TRUE),
    ('http://adlnet.gov/expapi/verbs/initialized', '{"en-US": "initialized"}', 'Started a learning activity', TRUE),
    ('http://adlnet.gov/expapi/verbs/terminated', '{"en-US": "terminated"}', 'Ended a learning activity', TRUE),
    ('http://adlnet.gov/expapi/verbs/suspended', '{"en-US": "suspended"}', 'Suspended a learning activity', TRUE),
    ('http://adlnet.gov/expapi/verbs/resumed', '{"en-US": "resumed"}', 'Resumed a learning activity', TRUE)
ON CONFLICT (verb_id) DO NOTHING;

COMMENT ON TABLE xapi_verb_registry IS 'Registry of xAPI verbs for statement validation and reporting';

-- =====================================================
-- Learning Activity State Store
-- Per xAPI State Resource
-- =====================================================
CREATE TABLE IF NOT EXISTS xapi_activity_state (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_id TEXT NOT NULL,
    agent_id UUID NOT NULL REFERENCES employees(id),
    state_id TEXT NOT NULL,
    registration UUID,
    content_type TEXT DEFAULT 'application/json',
    state_data JSONB,
    stored_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(activity_id, agent_id, state_id, registration)
);

CREATE INDEX IF NOT EXISTS idx_xapi_state_lookup 
    ON xapi_activity_state(activity_id, agent_id, state_id);

COMMENT ON TABLE xapi_activity_state IS 'xAPI activity state storage per agent/activity';

-- =====================================================
-- Learning Activity Profile Store
-- Per xAPI Activity Profile Resource
-- =====================================================
CREATE TABLE IF NOT EXISTS xapi_activity_profile (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_id TEXT NOT NULL,
    profile_id TEXT NOT NULL,
    content_type TEXT DEFAULT 'application/json',
    profile_data JSONB,
    stored_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(activity_id, profile_id)
);

COMMENT ON TABLE xapi_activity_profile IS 'xAPI activity profile storage';

-- =====================================================
-- Agent Profile Store
-- Per xAPI Agent Profile Resource
-- =====================================================
CREATE TABLE IF NOT EXISTS xapi_agent_profile (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id UUID NOT NULL REFERENCES employees(id),
    profile_id TEXT NOT NULL,
    content_type TEXT DEFAULT 'application/json',
    profile_data JSONB,
    stored_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(agent_id, profile_id)
);

COMMENT ON TABLE xapi_agent_profile IS 'xAPI agent profile storage';

-- =====================================================
-- Pharma-Specific xAPI Extensions
-- Custom verbs for pharmaceutical training
-- =====================================================
INSERT INTO xapi_verb_registry (verb_id, display_name, description, is_standard) VALUES
    ('https://pharmalearn.io/xapi/verbs/acknowledged', '{"en-US": "acknowledged"}', 'Acknowledged reading/policy', FALSE),
    ('https://pharmalearn.io/xapi/verbs/certified', '{"en-US": "certified"}', 'Received certification', FALSE),
    ('https://pharmalearn.io/xapi/verbs/recertified', '{"en-US": "recertified"}', 'Recertified competency', FALSE),
    ('https://pharmalearn.io/xapi/verbs/verified', '{"en-US": "verified"}', 'Identity verified for signature', FALSE),
    ('https://pharmalearn.io/xapi/verbs/signed', '{"en-US": "signed"}', 'Applied electronic signature', FALSE),
    ('https://pharmalearn.io/xapi/verbs/witnessed', '{"en-US": "witnessed"}', 'Witnessed training session', FALSE),
    ('https://pharmalearn.io/xapi/verbs/assessed', '{"en-US": "assessed"}', 'Was assessed for competency', FALSE),
    ('https://pharmalearn.io/xapi/verbs/remediated', '{"en-US": "remediated"}', 'Completed remediation training', FALSE),
    ('https://pharmalearn.io/xapi/verbs/inducted', '{"en-US": "inducted"}', 'Completed induction training', FALSE),
    ('https://pharmalearn.io/xapi/verbs/deviation-trained', '{"en-US": "deviation-trained"}', 'Completed deviation-triggered training', FALSE)
ON CONFLICT (verb_id) DO NOTHING;
