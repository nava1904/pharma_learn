# Phase 2: Schema-Handler Mismatch Analysis

## Summary of Mismatches Found

### 1. self_learning_handler.dart ↔ 08_self_learning.sql

**Handler Uses:**
- `learning_progress.employee_assignment_id` - FK to `employee_assignments`
- `learning_progress.course_id`
- `learning_progress.completion_method`
- `learning_progress.started_at`
- `learning_progress.last_activity_at`
- `learning_progress.bookmark`
- `learning_progress.scorm_session_time`

**Schema Has:**
- `learning_progress.assignment_id` - FK to `self_learning_assignments`
- `learning_progress.content_type`
- `learning_progress.content_id`
- `learning_progress.last_position`
- `learning_progress.progress_percentage`
- `learning_progress.time_spent_minutes`
- `learning_progress.last_accessed_at`
- `learning_progress.completed_at`

**Resolution:** ✅ FIXED - Updated `learning_progress` schema to support both:
- Added `employee_assignment_id UUID` for compliance-track training
- Added `course_id UUID` FK to courses
- Added `started_at`, `last_activity_at`, `bookmark`, `scorm_session_time`, `completion_method`
- Made `assignment_id` nullable for dual-use

---

### 2. me_training_history_handler.dart ↔ Multiple Schema Files

**Handler References (Non-Existent):**
- `ojt_assignments` table
- `ojt_assignments.ojt_name`
- `ojt_assignments.ojt_code`
- `self_learning_progress` table
- `self_learning_modules` table

**Schema Actually Has:**
- `employee_ojt` (not `ojt_assignments`)
- Uses FK to `ojt_masters` (not denormalized `ojt_name`, `ojt_code`)
- `learning_progress` (not `self_learning_progress`)
- `self_learning_assignments` + `learning_progress` (not `self_learning_modules`)

**Resolution:** ✅ FIXED - Updated handler to use correct table names and joins:
- `ojt_assignments` → `employee_ojt` JOIN `ojt_masters`
- `self_learning_progress` → `self_learning_assignments`
- `self_learning_modules` → `courses` / `documents` from `self_learning_assignments`

---

### 3. report_schedules_handler.dart ↔ 02_reports.sql

**Handler Uses:**
- `template_id` (string for static templates)
- `parameters` (JSONB)
- `cron_expression`
- `timezone`
- `delivery_method`
- `run_count`
- `created_by`

**Schema Had:**
- `report_definition_id` only
- `user_id` (not `created_by`)
- `schedule_config` (no separate cron/timezone)
- No `template_id`, `parameters`, `delivery_method`, `run_count`

**Resolution:** ✅ FIXED - Updated `scheduled_reports` schema to support both patterns:
- Added `organization_id`
- Added `template_id` for static templates
- Added `description`
- Added `cron_expression`, `timezone` as separate columns
- Added `parameters` JSONB
- Added `delivery_method`
- Added `run_count`
- Changed `user_id` to `created_by` (references employees)

---

### 4. schedule_invitations_handler.dart ↔ 04_invitations.sql

**Handler Uses:**
- `enrollment_id`
- `status` ('draft', 'sent', 'delivered', 'failed')
- `sent_at`
- `include_calendar`
- `custom_message`

**Schema Had:**
- No `enrollment_id`
- `invited_by` (NOT NULL - but handler doesn't provide it)
- `response_status` (invitation response enum)
- No `status`, `sent_at`, `include_calendar`, `custom_message`

**Resolution:** ✅ FIXED - Updated `training_invitations` schema:
- Added `enrollment_id UUID` FK to schedule_enrollments
- Added `status TEXT` for sending state
- Added `sent_at TIMESTAMPTZ`
- Added `include_calendar BOOLEAN`
- Added `custom_message TEXT`
- Made `invited_by` nullable

---

## Status Summary

| File | Status | Notes |
|------|--------|-------|
| 08_self_learning.sql | ✅ Fixed | Added compliance-track columns |
| me_training_history_handler.dart | ✅ Fixed | Updated table names |
| 02_reports.sql | ✅ Fixed | Extended scheduled_reports |
| 04_invitations.sql | ✅ Fixed | Added invitation tracking fields |

## Verified

- `dart analyze lib/` - No errors (12 lint info warnings only)
