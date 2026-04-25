-- =====================================================
-- 17_extensions/00_extensions_schema.sql
-- Extensions Schema Isolation
-- Separates optional/non-regulated tables from core
-- =====================================================
-- This file provides the schema structure for extension tables
-- that are NOT required for 21 CFR Part 11 compliance.
-- These can be deployed separately or excluded entirely.
-- =====================================================

-- Create extensions schema if not exists
CREATE SCHEMA IF NOT EXISTS extensions;

-- Grant usage to authenticated users
GRANT USAGE ON SCHEMA extensions TO authenticated;
GRANT ALL ON SCHEMA extensions TO service_role;

-- Set search path to include extensions
-- Note: Application should explicitly reference extensions.table_name

COMMENT ON SCHEMA extensions IS 
'Optional extension tables not required for 21 CFR Part 11 compliance. 
Includes: gamification, knowledge base, surveys, discussions, social learning, cost tracking.
These tables can be deployed/excluded independently of core compliance schema.';

-- =====================================================
-- Extension Categories Documented
-- =====================================================
-- The following extension modules exist:
--
-- 01_gamification.sql - Points, badges, leaderboards (OPTIONAL)
-- 02_kb_articles.sql - Knowledge base articles (OPTIONAL)
-- 03_surveys.sql - Surveys and feedback (OPTIONAL)
-- 04_discussions.sql - Discussion forums (OPTIONAL)
-- 05_social_learning.sql - Social features (OPTIONAL)
-- 06_cost_tracking.sql - Training cost tracking (OPTIONAL)
-- 07_content_library.sql - Content management (CORE for training)
-- 08_xapi_constraints.sql - xAPI validation (CORE for interop)
--
-- Tables that SHOULD remain in public schema (regulated):
-- - content_assets (linked to training materials)
-- - lessons (course content structure)
-- - scorm_packages (e-learning compliance)
-- - xapi_statements (learning records)
-- - lesson_progress (completion tracking)
--
-- Tables that CAN move to extensions schema (optional):
-- - gamification_* tables
-- - kb_* tables
-- - survey_* tables
-- - discussion_* tables
-- - social_* tables
-- - cost_* tables
-- =====================================================

-- =====================================================
-- View to List All Extension Tables
-- =====================================================
CREATE OR REPLACE VIEW extensions.extension_catalog AS
SELECT 
    'gamification' AS category,
    'point_events' AS table_name,
    'Points earned by employees' AS description,
    FALSE AS is_regulated,
    TRUE AS can_disable
UNION ALL SELECT 'gamification', 'badges', 'Achievement badges', FALSE, TRUE
UNION ALL SELECT 'gamification', 'badge_awards', 'Badge assignments', FALSE, TRUE
UNION ALL SELECT 'gamification', 'leaderboard_snapshots', 'Periodic leaderboard captures', FALSE, TRUE
UNION ALL SELECT 'gamification', 'streaks', 'Learning streaks', FALSE, TRUE
UNION ALL SELECT 'gamification', 'challenges', 'Learning challenges', FALSE, TRUE
UNION ALL SELECT 'gamification', 'challenge_participants', 'Challenge participants', FALSE, TRUE
UNION ALL SELECT 'knowledge_base', 'kb_categories', 'Article categories', FALSE, TRUE
UNION ALL SELECT 'knowledge_base', 'kb_articles', 'Knowledge base articles', FALSE, TRUE
UNION ALL SELECT 'knowledge_base', 'kb_article_versions', 'Article version history', FALSE, TRUE
UNION ALL SELECT 'knowledge_base', 'kb_article_feedback', 'Article ratings/feedback', FALSE, TRUE
UNION ALL SELECT 'surveys', 'surveys', 'Survey definitions', FALSE, TRUE
UNION ALL SELECT 'surveys', 'survey_questions', 'Survey questions', FALSE, TRUE
UNION ALL SELECT 'surveys', 'survey_responses', 'Survey response submissions', FALSE, TRUE
UNION ALL SELECT 'surveys', 'survey_answers', 'Individual answers', FALSE, TRUE
UNION ALL SELECT 'discussions', 'discussion_forums', 'Forum categories', FALSE, TRUE
UNION ALL SELECT 'discussions', 'discussion_threads', 'Discussion threads', FALSE, TRUE
UNION ALL SELECT 'discussions', 'discussion_posts', 'Forum posts', FALSE, TRUE
UNION ALL SELECT 'discussions', 'discussion_reactions', 'Post reactions', FALSE, TRUE
UNION ALL SELECT 'social', 'mentorship_relationships', 'Mentor assignments', FALSE, TRUE
UNION ALL SELECT 'social', 'learning_groups', 'Cohort groups', FALSE, TRUE
UNION ALL SELECT 'social', 'group_memberships', 'Group members', FALSE, TRUE
UNION ALL SELECT 'social', 'peer_feedback', 'Peer assessments', FALSE, TRUE
UNION ALL SELECT 'cost_tracking', 'training_costs', 'Cost records', FALSE, TRUE
UNION ALL SELECT 'cost_tracking', 'cost_allocations', 'Cost distribution', FALSE, TRUE
UNION ALL SELECT 'cost_tracking', 'vendor_contracts', 'Vendor agreements', FALSE, TRUE
UNION ALL SELECT 'content', 'content_assets', 'Learning content files', TRUE, FALSE
UNION ALL SELECT 'content', 'lessons', 'Course lessons', TRUE, FALSE
UNION ALL SELECT 'content', 'scorm_packages', 'SCORM packages', TRUE, FALSE
UNION ALL SELECT 'content', 'xapi_statements', 'Learning records', TRUE, FALSE
UNION ALL SELECT 'content', 'lesson_progress', 'Progress tracking', TRUE, FALSE;

COMMENT ON VIEW extensions.extension_catalog IS 
'Catalog of extension tables with regulated/optional classification';

-- =====================================================
-- Extension Toggle Function
-- Allows runtime enable/disable of extension categories
-- =====================================================
CREATE TABLE IF NOT EXISTS extensions.extension_status (
    category TEXT PRIMARY KEY,
    is_enabled BOOLEAN DEFAULT TRUE,
    disabled_at TIMESTAMPTZ,
    disabled_by UUID REFERENCES employees(id),
    reason TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO extensions.extension_status (category, is_enabled) VALUES
    ('gamification', TRUE),
    ('knowledge_base', TRUE),
    ('surveys', TRUE),
    ('discussions', TRUE),
    ('social', TRUE),
    ('cost_tracking', TRUE)
ON CONFLICT (category) DO NOTHING;

-- Function to check if extension is enabled
CREATE OR REPLACE FUNCTION extensions.is_enabled(p_category TEXT)
RETURNS BOOLEAN AS $$
    SELECT COALESCE(
        (SELECT is_enabled FROM extensions.extension_status WHERE category = p_category),
        FALSE
    );
$$ LANGUAGE sql STABLE;

-- Function to toggle extension
CREATE OR REPLACE FUNCTION extensions.set_extension_status(
    p_category TEXT,
    p_enabled BOOLEAN,
    p_user_id UUID DEFAULT NULL,
    p_reason TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO extensions.extension_status (category, is_enabled, disabled_at, disabled_by, reason, updated_at)
    VALUES (
        p_category, 
        p_enabled, 
        CASE WHEN NOT p_enabled THEN NOW() ELSE NULL END,
        CASE WHEN NOT p_enabled THEN p_user_id ELSE NULL END,
        CASE WHEN NOT p_enabled THEN p_reason ELSE NULL END,
        NOW()
    )
    ON CONFLICT (category) DO UPDATE SET
        is_enabled = p_enabled,
        disabled_at = CASE WHEN NOT p_enabled THEN NOW() ELSE NULL END,
        disabled_by = CASE WHEN NOT p_enabled THEN p_user_id ELSE NULL END,
        reason = CASE WHEN NOT p_enabled THEN p_reason ELSE NULL END,
        updated_at = NOW();
        
    -- Log the change
    INSERT INTO audit_trails (
        action,
        table_name,
        record_id,
        new_values,
        performed_by,
        event_category
    ) VALUES (
        CASE WHEN p_enabled THEN 'EXTENSION_ENABLED' ELSE 'EXTENSION_DISABLED' END,
        'extension_status',
        NULL,
        jsonb_build_object('category', p_category, 'enabled', p_enabled, 'reason', p_reason),
        COALESCE(p_user_id, auth.uid()),
        'system_config'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION extensions.set_extension_status IS 
'Toggle extension category on/off with audit trail';

-- =====================================================
-- RLS Policies for Extension Status
-- =====================================================
ALTER TABLE extensions.extension_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Extension status readable by all authenticated"
    ON extensions.extension_status FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "Extension status modifiable by admins"
    ON extensions.extension_status FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM employees e
            JOIN user_roles ur ON e.id = ur.employee_id
            JOIN roles r ON ur.role_id = r.id
            WHERE e.user_id = auth.uid()
            AND r.name IN ('System Administrator', 'Super Admin')
        )
    );
