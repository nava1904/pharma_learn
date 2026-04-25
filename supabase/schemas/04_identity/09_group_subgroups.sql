-- ===========================================
-- GROUP SUBGROUPS TABLE
-- Many-to-many: Groups ↔ Subgroups
-- ===========================================

CREATE TABLE IF NOT EXISTS group_subgroups (
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    subgroup_id UUID NOT NULL REFERENCES subgroups(id) ON DELETE CASCADE,
    
    -- Order within group
    display_order INTEGER DEFAULT 0,
    
    -- Metadata
    added_at TIMESTAMPTZ DEFAULT NOW(),
    added_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    
    PRIMARY KEY (group_id, subgroup_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_group_subgroups_group ON group_subgroups(group_id);
CREATE INDEX IF NOT EXISTS idx_group_subgroups_subgroup ON group_subgroups(subgroup_id);

-- Function to get subgroups in a group
CREATE OR REPLACE FUNCTION get_group_subgroups(p_group_id UUID)
RETURNS TABLE (
    subgroup_id UUID,
    subgroup_name TEXT,
    subgroup_code TEXT,
    member_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.name,
        s.unique_code,
        (SELECT COUNT(*) FROM employee_subgroups es WHERE es.subgroup_id = s.id AND es.is_active = true)
    FROM group_subgroups gs
    JOIN subgroups s ON s.id = gs.subgroup_id
    WHERE gs.group_id = p_group_id
      AND s.is_active = true
    ORDER BY gs.display_order, s.name;
END;
$$ LANGUAGE plpgsql;

-- Function to get groups containing a subgroup
CREATE OR REPLACE FUNCTION get_subgroup_groups(p_subgroup_id UUID)
RETURNS TABLE (
    group_id UUID,
    group_name TEXT,
    group_code TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        g.id,
        g.name,
        g.unique_code
    FROM group_subgroups gs
    JOIN groups g ON g.id = gs.group_id
    WHERE gs.subgroup_id = p_subgroup_id
      AND g.is_active = true
    ORDER BY g.name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE group_subgroups IS 'Many-to-many relationship between groups and subgroups';
