# Backend-Only Readiness Checklist

## Scope

This checklist evaluates only the:

- database schema
- backend services
- API layer

It does **not** evaluate Flutter UI readiness.

The question being answered is:

> Is the backend solid, extendable, and complete enough against the `ref` docs that UI development can safely begin?

## Verdict

### Short answer

- **For the full Learn-IQ-style scope from the ref docs:** `No`
- **For a controlled MVP/subset of implemented modules:** `Yes, with caution`

### Confidence statement

The backend is **architecturally strong and extendable**, but it is **not yet fully backend-complete** against the full business and admin surface described in the `ref` docs.

The biggest blockers are:

- self-learning schema/handler inconsistency
- incomplete parity for some Learn-IQ master-data modules
- partial reporting completeness
- partial Learn-IQ Course Manager parity for reference-only features

## Overall Readiness Rating

| Area | Rating | Notes |
| --- | --- | --- |
| Architecture extensibility | `Strong` | Modular route structure, rich schema, compliance-first design |
| Database foundation | `Strong` | Broad domain coverage, triggers, audit, RLS, workflow, integrity |
| API organization | `Strong` | Clear `access/create/train/certify/workflow/reports` separation |
| Learn-IQ feature parity | `Partial` | Most core capabilities exist, but not full parity |
| Backend consistency | `Moderate` | Good overall, but some schema/handler drift remains |
| Safe to begin full UI | `No` | Not for the complete ref-doc scope |
| Safe to begin scoped UI | `Yes` | If UI targets implemented modules only |

## Module-by-Module Readiness

## 1. Access / System Manager

### Status

- `Partial to Ready`

### What is clearly present

- auth
- roles
- employees
- groups
- departments
- subgroups
- job responsibilities
- global profiles
- SSO
- delegations
- biometrics
- notifications
- mail settings

### Evidence

- [access/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/access/routes.dart)
- [departments/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/access/departments/routes.dart)
- [subgroups/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/access/subgroups/routes.dart)
- [job_responsibilities/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/access/job_responsibilities/routes.dart)
- [global_profiles/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/access/global_profiles/routes.dart)
- [mail_settings/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/access/mail_settings/routes.dart)

### Assessment

This is much better than a basic auth module. It already resembles a regulated LMS admin backbone.

### Remaining gaps

- user-profile parity with classic Learn-IQ is not yet obvious as a first-class surface
- full validation of all admin workflows was not executed in this review

### UI readiness

- `Yes`

## 2. Document Manager

### Status

- `Ready`

### What is clearly present

- document CRUD
- submit/approve/reject
- versions
- readings
- reading acknowledgment
- integrity verification
- export
- issued/controlled copy flow

### Evidence

- [create/documents/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/create/documents/routes.dart)

### Assessment

This is one of the strongest and most complete backend areas.

### UI readiness

- `Yes`

## 3. Course Manager Core

### Status

- `Partial`

### What is clearly present

- courses
- course approval flow
- course-document linking
- question banks
- question papers
- trainers
- venues
- GTPs
- curricula
- feedback/evaluation templates
- periodic reviews

### Evidence

- [create/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/create/routes.dart)
- [create/courses/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/create/courses/routes.dart)
- [create/question_banks/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/create/question_banks/routes.dart)
- [create/question_papers/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/create/question_papers/routes.dart)

### Missing or incomplete against ref docs

- dedicated topic management API is not exposed even though `topics` exists in schema
- no dedicated subject management API is exposed
- no format-number API surface is exposed
- no satisfaction-scale API surface is exposed

### Evidence of backend objects without surfaced APIs

- [02_topics.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/06_courses/02_topics.sql)
- [05_venues_templates.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/06_courses/05_venues_templates.sql)

### Assessment

This module is strong for modern core authoring flows, but not yet full Learn-IQ parity.

### UI readiness

- `Only for implemented submodules`

## 4. Training Schedules, Sessions, Invitations, Attendance

### Status

- `Ready`

### What is clearly present

- schedules
- submit/approve/reject
- assignment/enrollment
- invitations
- self-nomination
- batches
- sessions
- document reading
- offline document reading actions
- attendance sheet
- attendance recording patterns

### Evidence

- [train/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/train/routes.dart)
- [train/schedules/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/train/schedules/routes.dart)

### Assessment

This is one of the stronger backend areas and is good enough for UI work.

### UI readiness

- `Yes`

## 5. Induction and OJT

### Status

- `Ready`

### What is clearly present

- induction flow
- coordinator/trainer induction flows
- OJT routes
- OJT task completion and sign-off model
- induction gating concepts in platform and schema

### Evidence

- [train/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/train/routes.dart)
- schema and middleware support such as induction gate

### Assessment

This looks sufficiently mature for UI work.

### UI readiness

- `Yes`

## 6. Self-Learning / Self-Study

### Status

- `Not Ready`

### Why

There is a serious mismatch between handler assumptions and canonical schema.

### Evidence

- handler writes and reads fields like `employee_assignment_id`, `course_id`, `started_at`, `last_activity_at`, `completion_method` in [self_learning_handler.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/train/self_learning/self_learning_handler.dart)
- canonical `learning_progress` schema uses `assignment_id`, `content_type`, `content_id`, `last_position`, `last_accessed_at` in [08_self_learning.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/07_training/08_self_learning.sql:37)
- training history also queries `self_learning_modules`, which is not defined in canonical schema, in [me_training_history_handler.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/train/me/me_training_history_handler.dart:136)

### Assessment

This area should be fixed before UI is built on top of it.

### UI readiness

- `No`

## 7. Assessments and Qualification

### Status

- `Ready`

### What is clearly present

- assessment start/answer/submit/results
- grading routes
- question banks
- question papers
- question paper print
- remedial training
- e-signatures / reauth

### Evidence

- [certify/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/certify/routes.dart)
- [create/question_papers/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/create/question_papers/routes.dart)

### Assessment

This backend area appears solid enough for UI.

### UI readiness

- `Yes`

## 8. Retraining, Remedial, Waivers

### Status

- `Ready`

### What is clearly present

- retraining routes
- remedial routes
- waiver routes
- standard reasons and workflow support

### Evidence

- [train/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/train/routes.dart)
- [certify/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/certify/routes.dart)
- [workflow/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/workflow/routes.dart)

### UI readiness

- `Yes`

## 9. Certificates, Compliance, Integrity

### Status

- `Ready`

### What is clearly present

- certificates
- verification
- revocation
- compliance routes
- integrity routes
- e-signature and reauth

### Assessment

This area is backend-ready and one of the strongest parts of the system.

### UI readiness

- `Yes`

## 10. Workflow, Audit, Standard Reasons, Quality

### Status

- `Ready`

### What is clearly present

- approval routes
- audit routes
- workflow notifications
- standard reasons
- quality routes for CAPA / deviation / change control

### Evidence

- [workflow/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/workflow/routes.dart)

### Assessment

This gives the backend a strong regulated-process backbone.

### UI readiness

- `Yes`

## 11. Reports and Analytics

### Status

- `Partial`

### What is clearly present

- report templates
- report runs
- report schedules
- compliance analytics/reporting structures

### Evidence

- [reports/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/reports/routes.dart)

### Remaining issues

- not all Learn-IQ-style reporting surfaces are proven complete
- some history/report aggregation is weakened by self-learning inconsistency

### Assessment

Good foundation, but not ready to claim full reference-doc reporting parity.

### UI readiness

- `Yes, for core reports`
- `No, for “full parity” reporting claims`

## 12. Periodic Review

### Status

- `Ready`

### Why

The periodic review implementation now aligns with the canonical schema.

### Evidence

- [periodic_reviews_handler.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/create/periodic_reviews/periodic_reviews_handler.dart)
- [13_periodic_review_schedule.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/07_training/13_periodic_review_schedule.sql)

### UI readiness

- `Yes`

## Learn-IQ Reference Parity Gaps Still Open

These are the main backend gaps against the `ref` docs, even if the overall platform is strong:

1. `Self-learning` is not backend-safe enough yet because of schema/handler inconsistency.
2. `Training history` is not fully trustworthy while self-learning aggregation is inconsistent.
3. `Topics` exist in schema but are not exposed as a first-class API surface.
4. `Format numbers` exist in schema but are not exposed as an API surface.
5. `Satisfaction scales` exist in schema but are not exposed as an API surface.
6. `Full reporting parity` with the Learn-IQ reference is not yet proven.

## Backend Solidity Assessment

## What is solid

- modular route structure
- broad schema coverage
- compliance-first design
- document control
- workflows and audit
- assessment and certification backbone
- schedule/session/invitation flows

## What is easily extendable

Yes, the backend appears **easily extendable** because:

- domains are well separated
- schema is rich and normalized
- workflow/audit/e-signature concerns are cross-cutting primitives, not bolted-on hacks
- missing surfaces like topics/format numbers/satisfaction scales can be added without rethinking the whole platform

## What is not yet solid enough

- self-learning
- some cross-source history/report aggregation
- full feature-parity confidence against all smaller Learn-IQ reference capabilities

## Go / No-Go for UI

## Go for UI if

You are building UI for this subset first:

- auth and admin basics
- departments / roles / groups / subgroups / job responsibilities / global profiles
- documents
- courses
- GTPs / curricula
- schedules / sessions / attendance / invitations / nominations
- induction / OJT
- assessments
- retraining / waivers / remedial
- certificates / compliance / workflow / audit

## No-Go for full UI if

You expect backend completeness for all `ref`-doc features, especially:

- self-learning
- fully consolidated training history
- topic/format number/satisfaction scale administration
- full Learn-IQ reporting parity

## Recommended Pre-UI Backend Fixes

1. Reconcile self-learning handlers with canonical schema.
2. Fix training-history aggregation for self-learning.
3. Add topic APIs.
4. Add format-number APIs.
5. Add satisfaction-scale APIs.
6. Re-run a backend traceability check for reports that depend on cross-domain aggregation.

## Final Recommendation

### Recommendation

- **Do not start full-product UI assuming backend completeness.**
- **Do start UI for the implemented core modules after first fixing self-learning/history.**

### Practical decision

If you want the safest path:

1. fix self-learning + history first
2. add topic / format number / satisfaction scale APIs
3. then begin UI in parallel for core modules

That gives you a backend that is both:

- solid enough for UI
- much closer to the Learn-IQ-style scope in the `ref` docs
