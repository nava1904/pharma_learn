-- ===========================================
-- GAMIFICATION
-- Badges, points, levels, leaderboards
-- ===========================================

CREATE TYPE badge_tier AS ENUM ('bronze','silver','gold','platinum','diamond');
CREATE TYPE point_event_type AS ENUM (
    'course_completed','assessment_passed','first_attempt_pass','perfect_score',
    'streak_maintained','prerequisite_cleared','ojt_signed_off','certificate_earned',
    'feedback_submitted','knowledge_article_read','discussion_answered'
);

CREATE TABLE IF NOT EXISTS badges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    tier badge_tier DEFAULT 'bronze',
    icon_url TEXT,
    points_required INTEGER DEFAULT 0,
    criteria_json JSONB,
    is_auto_award BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(organization_id, unique_code)
);

CREATE TABLE IF NOT EXISTS employee_badges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badges(id),
    awarded_at TIMESTAMPTZ DEFAULT NOW(),
    awarded_by UUID,
    award_context JSONB,
    is_featured BOOLEAN DEFAULT false,
    UNIQUE(employee_id, badge_id)
);

CREATE TABLE IF NOT EXISTS point_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    event_type point_event_type NOT NULL,
    points_awarded INTEGER NOT NULL,
    multiplier_json JSONB,
    is_active BOOLEAN DEFAULT true,
    UNIQUE(organization_id, event_type)
);

CREATE TABLE IF NOT EXISTS point_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    employee_id UUID NOT NULL REFERENCES employees(id),
    event_type point_event_type NOT NULL,
    points INTEGER NOT NULL,
    source_entity_type TEXT,
    source_entity_id UUID,
    awarded_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT
);

CREATE TABLE IF NOT EXISTS employee_point_balances (
    employee_id UUID PRIMARY KEY REFERENCES employees(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id),
    total_points INTEGER DEFAULT 0,
    current_level INTEGER DEFAULT 1,
    points_to_next_level INTEGER DEFAULT 100,
    current_streak_days INTEGER DEFAULT 0,
    longest_streak_days INTEGER DEFAULT 0,
    last_activity_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS leaderboards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    name TEXT NOT NULL,
    scope TEXT NOT NULL CHECK (scope IN ('org','plant','department','subgroup','role')),
    scope_id UUID,
    time_window TEXT NOT NULL CHECK (time_window IN ('daily','weekly','monthly','quarterly','yearly','all_time')),
    metric TEXT NOT NULL CHECK (metric IN ('points','courses_completed','perfect_scores','streak')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS leaderboard_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    leaderboard_id UUID NOT NULL REFERENCES leaderboards(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    rankings JSONB NOT NULL,
    taken_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(leaderboard_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_pt_employee ON point_transactions(employee_id, awarded_at DESC);
CREATE INDEX IF NOT EXISTS idx_eb_employee ON employee_badges(employee_id);

COMMENT ON TABLE badges IS 'Achievement badges employees can earn';
COMMENT ON TABLE point_transactions IS 'Append-only ledger of points awarded (never updated)';
