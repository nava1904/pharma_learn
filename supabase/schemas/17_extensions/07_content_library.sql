-- ===========================================
-- CONTENT LIBRARY / LESSONS / SCORM
-- Structured course content, lessons, media assets
-- ===========================================

CREATE TYPE content_type AS ENUM (
    'video','audio','pdf','slideshow','html5','scorm','xapi','interactive',
    'quiz','reading','embedded_link','live_session'
);
CREATE TYPE content_status AS ENUM ('draft','processing','ready','failed','archived');

CREATE TABLE IF NOT EXISTS content_assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    content_type content_type NOT NULL,
    file_id UUID,
    external_url TEXT,
    duration_seconds INTEGER,
    file_size_bytes BIGINT,
    language TEXT DEFAULT 'en',
    transcription TEXT,
    caption_file_id UUID,
    thumbnail_url TEXT,
    search_vector TSVECTOR,
    tags TEXT[] DEFAULT '{}',
    content_status content_status DEFAULT 'draft',
    is_reusable BOOLEAN DEFAULT true,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    topic_id UUID REFERENCES topics(id),
    title TEXT NOT NULL,
    description TEXT,
    lesson_order INTEGER NOT NULL,
    estimated_minutes INTEGER,
    is_mandatory BOOLEAN DEFAULT true,
    is_previewable BOOLEAN DEFAULT false,
    completion_rule TEXT DEFAULT 'viewed' CHECK (completion_rule IN ('viewed','full_watch','quiz_passed','manual','xapi_completed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(course_id, lesson_order)
);

CREATE TABLE IF NOT EXISTS lesson_content (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    content_asset_id UUID NOT NULL REFERENCES content_assets(id),
    display_order INTEGER DEFAULT 0,
    is_primary BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS scorm_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_asset_id UUID NOT NULL UNIQUE REFERENCES content_assets(id) ON DELETE CASCADE,
    scorm_version TEXT CHECK (scorm_version IN ('1.2','2004_3','2004_4')),
    launch_url TEXT NOT NULL,
    manifest_json JSONB,
    passing_score NUMERIC(5,2),
    mastery_threshold NUMERIC(5,2),
    uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS xapi_statements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    employee_id UUID NOT NULL REFERENCES employees(id),
    statement_json JSONB NOT NULL,
    verb TEXT NOT NULL,
    object_type TEXT,
    object_id TEXT,
    result_completion BOOLEAN,
    result_success BOOLEAN,
    result_score NUMERIC(5,2),
    stored_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS lesson_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ,
    last_accessed_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    watch_percent NUMERIC(5,2) DEFAULT 0,
    total_watch_seconds INTEGER DEFAULT 0,
    current_position_seconds INTEGER DEFAULT 0,
    bookmark_positions JSONB DEFAULT '[]',
    notes TEXT,
    UNIQUE(employee_id, lesson_id)
);

CREATE TABLE IF NOT EXISTS content_view_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_asset_id UUID NOT NULL REFERENCES content_assets(id),
    employee_id UUID REFERENCES employees(id),
    session_id UUID,
    viewed_at TIMESTAMPTZ DEFAULT NOW(),
    position_seconds INTEGER,
    event TEXT CHECK (event IN ('play','pause','seek','complete','exit','resume'))
);

CREATE INDEX IF NOT EXISTS idx_content_search ON content_assets USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS idx_lp_employee ON lesson_progress(employee_id);
CREATE INDEX IF NOT EXISTS idx_xapi_actor ON xapi_statements(employee_id, stored_at DESC);

COMMENT ON TABLE lessons IS 'Ordered content units inside a course (video/reading/quiz)';
COMMENT ON TABLE scorm_packages IS 'SCORM 1.2/2004 package metadata for e-learning interoperability';
COMMENT ON TABLE xapi_statements IS 'xAPI/Tin Can learning record store';
