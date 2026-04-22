# Phase 4: Training-Operation Parity

## Schema Additions

### 1. External Training Records Schema (NEW)
**File:** `supabase/schemas/09_compliance/05_external_training.sql`

**Table:** `external_training_records`
- Pre-approval staging table for external training submissions
- Supports workflow: draft → pending_approval → approved/rejected
- On approval, creates entry in `training_records` table
- Columns: course_name, institution_name, completion_date, training_hours, training_type, skills_acquired, certificate_attachment_id
- Workflow columns: submitted_by, submitted_at, approved_by, approved_at, rejected_by, rejection_reason

---

### 2. Self-Study Courses Schema (NEW)
**File:** `supabase/schemas/07_training/09_self_study.sql`

**Table:** `self_study_courses`
- Open enrollment course catalog for employee-driven learning
- Supports e_learning, video, document, scorm, external_link types
- Enrollment settings: is_open_enrollment, max_enrollments, date range
- Completion settings: requires_assessment, passing_score

**Table:** `self_study_enrollments`
- Employee self-enrollments in open catalog courses
- Status: enrolled, in_progress, completed, dropped
- Progress tracking: progress_percentage, started_at, completed_at
- Assessment tracking: attempts, score, passed
- Time tracking: total_time_minutes, last_access_at

---

## Existing Training Handlers Verified

| Handler | Path | Status |
|---------|------|--------|
| OJT Handler | `train/ojt/ojt_handler.dart` | ✅ Exists |
| External Training Handler | `train/external/external_training_handler.dart` | ✅ Exists (schema added) |
| Self-Study Handler | `train/self_study/self_study_handler.dart` | ✅ Exists (schema added) |
| Self-Learning Handler | `train/self_learning/self_learning_handler.dart` | ✅ Exists (schema fixed in Phase 2) |
| Sessions Handler | `train/sessions/` | ✅ Exists |
| Schedules Handler | `train/schedules/` | ✅ Exists |
| Induction Handler | `train/induction/` | ✅ Exists |
| Batches Handler | `train/batches/` | ✅ Exists |
| Evaluations Handler | `train/evaluations/` | ✅ Exists |
| Feedback Handler | `train/feedback/` | ✅ Exists |
| Retraining Handler | `train/retraining/` | ✅ Exists |

---

## Schema Files Verified

| Training Mode | Schema File | Status |
|---------------|-------------|--------|
| Courses | `06_courses/03_courses.sql` | ✅ |
| Sessions/Batches | `07_training/03_sessions_batches.sql` | ✅ |
| Invitations | `07_training/04_invitations.sql` | ✅ (fixed in Phase 2) |
| OJT | `07_training/07_ojt.sql` | ✅ |
| Self-Learning | `07_training/08_self_learning.sql` | ✅ (fixed in Phase 2) |
| Self-Study | `07_training/09_self_study.sql` | ✅ NEW |
| Training Records | `09_compliance/01_training_records.sql` | ✅ |
| External Training | `09_compliance/05_external_training.sql` | ✅ NEW |

---

## Summary

**Phase 4 Complete:**
- 2 new schema files created
- 3 new tables added
- All training mode handlers verified
- Schema-handler mismatches resolved

**Verified:** `dart analyze lib/` - No errors (12 lint info warnings only)
