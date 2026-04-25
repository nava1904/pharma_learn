-- ===========================================
-- DISCUSSIONS / Q&A / COLLABORATION
-- Course forums, topic-based Q&A, peer learning
-- ===========================================

CREATE TYPE discussion_scope AS ENUM ('course','topic','gtp','learning_path','kb_article','general');
CREATE TYPE thread_status    AS ENUM ('open','answered','closed','locked','flagged');

CREATE TABLE IF NOT EXISTS discussion_threads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    scope discussion_scope NOT NULL,
    scope_id UUID,
    title TEXT NOT NULL,
    body_markdown TEXT,
    tags TEXT[] DEFAULT '{}',
    is_question BOOLEAN DEFAULT false,
    accepted_answer_id UUID,
    thread_status thread_status DEFAULT 'open',
    view_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    upvote_count INTEGER DEFAULT 0,
    pinned BOOLEAN DEFAULT false,
    moderated_at TIMESTAMPTZ,
    moderated_by UUID,
    moderation_reason TEXT,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS discussion_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    thread_id UUID NOT NULL REFERENCES discussion_threads(id) ON DELETE CASCADE,
    parent_post_id UUID REFERENCES discussion_posts(id),
    body_markdown TEXT NOT NULL,
    is_answer BOOLEAN DEFAULT false,
    is_edited BOOLEAN DEFAULT false,
    edit_history JSONB DEFAULT '[]',
    upvote_count INTEGER DEFAULT 0,
    flagged_count INTEGER DEFAULT 0,
    author_id UUID NOT NULL REFERENCES employees(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS discussion_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    target_type TEXT NOT NULL CHECK (target_type IN ('thread','post')),
    target_id UUID NOT NULL,
    employee_id UUID NOT NULL REFERENCES employees(id),
    reaction_type TEXT NOT NULL CHECK (reaction_type IN ('upvote','downvote','helpful','celebrate','insightful')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(target_type, target_id, employee_id, reaction_type)
);

CREATE TABLE IF NOT EXISTS discussion_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    thread_id UUID NOT NULL REFERENCES discussion_threads(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id),
    notify_on_reply BOOLEAN DEFAULT true,
    subscribed_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(thread_id, employee_id)
);

CREATE TABLE IF NOT EXISTS discussion_flags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    target_type TEXT NOT NULL CHECK (target_type IN ('thread','post')),
    target_id UUID NOT NULL,
    reporter_id UUID NOT NULL REFERENCES employees(id),
    reason TEXT NOT NULL,
    resolution TEXT,
    resolved_by UUID,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dt_scope ON discussion_threads(scope, scope_id);
CREATE INDEX IF NOT EXISTS idx_dp_thread ON discussion_posts(thread_id);
CREATE INDEX IF NOT EXISTS idx_dp_author ON discussion_posts(author_id);

COMMENT ON TABLE discussion_threads IS 'Forum/Q&A threads scoped to courses, topics, GTPs, or general';
