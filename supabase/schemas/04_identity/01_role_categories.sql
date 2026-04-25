-- ===========================================
-- ROLE CATEGORIES TABLE
-- Login users vs Non-login users (biometric)
-- ===========================================

CREATE TABLE IF NOT EXISTS role_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    category role_category NOT NULL,
    description TEXT,
    is_system BOOLEAN DEFAULT false, -- System categories cannot be deleted
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(name)
);

-- Seed default categories per Learn-IQ
INSERT INTO role_categories (name, category, description, is_system) VALUES
    ('System Administrator', 'login', 'Full system access with login credentials', true),
    ('Manager', 'login', 'Management access with login credentials', true),
    ('Supervisor', 'login', 'Supervisory access with login credentials', true),
    ('Operator', 'login', 'Standard operator with login credentials', true),
    ('Quality Assurance', 'login', 'QA personnel with login credentials', true),
    ('Trainer', 'login', 'Training department with login credentials', true),
    ('Floor Staff', 'non_login', 'Non-login users verified by biometrics only', true),
    ('Trainee', 'non_login', 'Temporary/trainee users with biometric access', true),
    ('Contract Worker', 'non_login', 'Contract workers with biometric verification', true)
ON CONFLICT (name) DO NOTHING;

COMMENT ON TABLE role_categories IS 'Learn-IQ: Categories for login vs non-login (biometric) users';
COMMENT ON COLUMN role_categories.category IS 'login = user account with credentials; non_login = biometric verification only';
