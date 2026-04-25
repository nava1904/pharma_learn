-- ===========================================
-- TRANSLATED VIEWS (LIGHTWEIGHT)
-- Uses content_translations to overlay translated fields
-- ===========================================

CREATE OR REPLACE VIEW v_courses_translated AS
SELECT
    c.*,
    COALESCE(t_name.translated_text, c.name) AS display_name,
    COALESCE(t_desc.translated_text, c.description) AS display_description,
    COALESCE(pref.locale, 'en') AS effective_locale
FROM courses c
LEFT JOIN user_preferences pref ON pref.employee_id = get_user_employee_id()
LEFT JOIN content_translations t_name
    ON t_name.organization_id = c.organization_id
   AND t_name.entity_type = 'course'
   AND t_name.entity_id = c.id
   AND t_name.field_name = 'name'
   AND t_name.locale = COALESCE(pref.locale, 'en')
   AND t_name.is_approved = true
LEFT JOIN content_translations t_desc
    ON t_desc.organization_id = c.organization_id
   AND t_desc.entity_type = 'course'
   AND t_desc.entity_id = c.id
   AND t_desc.field_name = 'description'
   AND t_desc.locale = COALESCE(pref.locale, 'en')
   AND t_desc.is_approved = true;

