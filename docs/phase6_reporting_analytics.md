# Phase 6: Reporting and Analytics Parity

**Date:** 2026-04-27  
**Status:** ✅ Complete

---

## Summary

Phase 6 completes the standard report templates required by the scope document. The reporting infrastructure was already well-implemented with job queuing, PDF/CSV generation, and scheduled reports. This phase adds the remaining report templates to provide full coverage.

---

## Existing Infrastructure (Already Complete)

### Report System Components
- `report_templates_handler.dart` - List available templates
- `report_template_handler.dart` - Get template details
- `report_run_handler.dart` - Execute reports
- `report_run_status_handler.dart` - Check run status
- `report_run_download_handler.dart` - Download completed reports
- `report_schedules_handler.dart` - CRUD for scheduled reports
- `report_schedule_handler.dart` - Individual schedule management

### Report Generator Service
- `lifecycle_monitor/lib/services/report_generator_service.dart`
- Polls for queued reports
- Generates PDF and CSV outputs
- Uploads to storage bucket
- Handles prioritization

---

## Report Templates Added

### 1. Qualified Trainer Report (`qualified_trainer_report`)
**Category:** trainers

List of all qualified trainers with certifications and competencies.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| plant_id | uuid | No | Filter to specific plant |
| department_id | uuid | No | Filter to specific department |
| topic_id | uuid | No | Filter to trainers qualified for specific topic |
| include_external | boolean | No | Include external/contract trainers (default: true) |
| active_only | boolean | No | Only show active trainers (default: true) |

---

### 2. Course List Report (`course_list_report`)
**Category:** training

Master list of all courses with status and metadata.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| status | string | No | Filter by status (draft, approved, effective, obsolete) |
| topic_id | uuid | No | Filter to courses under specific topic |
| subject_id | uuid | No | Filter to courses under specific subject |
| delivery_method | string | No | Filter by delivery method (ilt, self_study, ojt, document) |
| effective_date_from | date | No | Only courses effective on or after this date |

---

### 3. Session/Batch Report (`session_batch_report`)
**Category:** training

Training sessions and batches with attendance summary.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| date_from | date | No | Start of reporting period |
| date_to | date | No | End of reporting period |
| course_id | uuid | No | Filter to specific course |
| trainer_id | uuid | No | Filter to specific trainer |
| department_id | uuid | No | Filter to sessions for specific department |
| status | string | No | Filter by status (scheduled, in_progress, completed, cancelled) |

---

### 4. Induction Status Report (`induction_status_report`)
**Category:** compliance

Induction completion status for employees.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| department_id | uuid | No | Filter to specific department |
| plant_id | uuid | No | Filter to specific plant |
| status | string | No | Filter by status (completed, in_progress, not_started) |
| hire_date_from | date | No | Filter to employees hired on or after this date |
| hire_date_to | date | No | Filter to employees hired on or before this date |

---

### 5. OJT Completion Report (`ojt_completion_report`)
**Category:** training

On-the-Job Training assignment and completion status.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| department_id | uuid | No | Filter to specific department |
| course_id | uuid | No | Filter to specific OJT course or module |
| trainer_id | uuid | No | Filter by OJT trainer/assessor |
| date_from | date | No | Assignment date from |
| date_to | date | No | Assignment date to |
| status | string | No | Filter by status (pending, in_progress, completed, failed) |

---

### 6. Pending Training Report (`pending_training_report`)
**Category:** compliance

All employees with pending training obligations.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| department_id | uuid | No | Filter to specific department |
| plant_id | uuid | No | Filter to specific plant |
| course_id | uuid | No | Filter to specific course |
| due_within_days | integer | No | Show obligations due within this many days |
| include_overdue | boolean | No | Include items already overdue (default: true) |

---

### 7. Attendance Report (`attendance_report`)
**Category:** training

Session attendance records with time tracking.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| date_from | date | **Yes** | Start of reporting period |
| date_to | date | **Yes** | End of reporting period |
| department_id | uuid | No | Filter to specific department |
| batch_id | uuid | No | Filter to specific training batch |
| session_id | uuid | No | Filter to specific session |
| include_corrections | boolean | No | Include correction history (default: false) |

---

### 8. Training Matrix Coverage Report (`training_matrix_coverage_report`)
**Category:** compliance

Coverage analysis for training matrices.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| matrix_id | uuid | No | Specific matrix to analyze (omit for all) |
| department_id | uuid | No | Filter to specific department |
| role_id | uuid | No | Filter to specific role |
| as_of | date | No | Coverage status as of this date |
| show_gaps_only | boolean | No | Only show employees with gaps (default: false) |

---

## Complete Template Registry

The `ReportTemplate.all` list now includes 18 templates:

### Compliance Reports
1. `employee_training_dossier` - Single-employee complete training history
2. `department_compliance_summary` - Department compliance rollup
3. `overdue_training_report` - Overdue training obligations
4. `audit_readiness_report` - Comprehensive audit preparation
5. `induction_status_report` - Induction completion status *(NEW)*
6. `pending_training_report` - Pending training obligations *(NEW)*
7. `training_matrix_coverage_report` - Matrix coverage analysis *(NEW)*

### Training Reports
8. `course_list_report` - Course master list *(NEW)*
9. `session_batch_report` - Sessions and batches *(NEW)*
10. `ojt_completion_report` - OJT assignments *(NEW)*
11. `attendance_report` - Attendance records *(NEW)*

### Trainer Reports
12. `qualified_trainer_report` - Qualified trainers list *(NEW)*

### Certificate Reports
13. `certificate_expiry_report` - Expiring certificates

### Document Reports
14. `sop_acknowledgment_report` - Document acknowledgment coverage

### Assessment Reports
15. `assessment_performance_report` - Assessment pass/fail analysis

### Audit Reports
16. `esignature_audit_report` - E-signature audit trail
17. `system_access_log_report` - Login/logout history
18. `integrity_verification_report` - Audit trail verification

---

## File Changed

**`packages/pharmalearn_shared/lib/src/models/report_templates.dart`**

Added 8 new report template definitions and updated the `all` registry.

---

## Validation Status

```
$ dart analyze lib/src/models/report_templates.dart
Analyzing report_templates.dart...
No issues found!

$ cd apps/api_server/pharma_learn/api && dart analyze lib/
Analyzing lib...
12 issues found (all info-level lint warnings).
```

---

## Next Steps for Report Generator

The report templates are defined. To fully implement report generation, the `ReportGeneratorService` needs to add data fetching logic for each new template. This involves:

1. Adding SQL queries in `_fetchReportData()` method for each template ID
2. Adding PDF rendering sections in `_generatePdf()` method
3. Adding CSV column definitions in `_generateCsv()` method

The infrastructure is already in place - only the template-specific queries and rendering need to be added.

---

## Phase 6 Checklist

- [x] Review existing report infrastructure
- [x] Add qualified trainer report template
- [x] Add course list report template
- [x] Add session/batch report template
- [x] Add induction status report template
- [x] Add OJT completion report template
- [x] Add pending training report template
- [x] Add attendance report template
- [x] Add training matrix coverage report template
- [x] Update ReportTemplate.all registry
- [x] Validate compilation
- [x] Document all parameters
