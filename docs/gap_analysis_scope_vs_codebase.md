# Gap Analysis: `pharma_lms_scope_document.md` vs `pharma_learn` Codebase

## 1. Purpose

This document compares the target scope described in [pharma_lms_scope_document.md](/Users/navadeepreddy/pharma_learn/docs/pharma_lms_scope_document.md) with the current `pharma_learn` implementation across:

- backend route surface
- schema/domain coverage
- workflow/compliance engines
- integrations
- frontend product surface
- architectural fit to the Learn-IQ / EPIQ reference model

This is a **scope-to-codebase** gap analysis, not just a route inventory.

## 2. How to read this

Status meanings:

- `Aligned`: clear implementation exists and matches the scope well
- `Partial`: implementation exists, but coverage is incomplete, uneven, or not yet surfaced end-to-end
- `Gap`: required scope area has little or no usable implementation
- `Divergence`: the codebase intentionally uses a different technical architecture than the Learn-IQ / EPIQ reference stack

## 3. Executive Summary

The codebase is **strong on backend domain modeling and regulated-system primitives**, but **weak on end-user product completeness**.

High-level conclusion:

- The **business domain** of a pharma LMS is broadly represented in the schema and API layout.
- The **regulated controls** layer is also well represented: audit, e-signature, workflow, compliance, retention, integrity, and reports all exist in the data model and route surface.
- The **biggest current gap is the usable application layer**, especially the Flutter client and several admin surfaces required by the scope document.
- There is also an important **architecture divergence**: the codebase does not resemble the original Learn-IQ/EPIQ Windows/IIS/SQL Server deployment stack. It is a modern Dart/Flutter + Supabase/Postgres platform.

## 4. Overall Scorecard

| Area | Status | Summary |
| --- | --- | --- |
| Business-domain coverage | Partial to Aligned | Most core LMS concepts exist in schema and routes |
| System Manager / admin model | Partial | Roles/employees/groups exist, but departments, subgroups, job responsibilities, and global profiles are not fully surfaced as APIs/UI |
| Document Manager | Aligned | Document CRUD, submit/approve/reject, versions, readings, export, integrity, issuance are present |
| Course Manager | Partial to Aligned | Strong backend coverage for courses, trainers, venues, GTPs, curricula, assessments; UI absent |
| Training operations | Partial to Aligned | Sessions, schedules, induction, OJT, self-learning, retraining, external training exist |
| Reporting and dashboards | Partial | Backend report infrastructure exists; end-user reporting surface is not complete |
| Compliance controls | Aligned | Audit, e-sign, integrity, password policy, retention, tests, RLS are clearly present |
| Integrations | Partial | SSO, biometrics, notifications exist; AD/DMS/mail admin surface is incomplete or implicit |
| Frontend product surface | Gap | Router exists, but actual screens are missing and routes use placeholders |
| Architecture match to reference Learn-IQ stack | Divergence | Modern Supabase/Postgres/Dart stack rather than Windows Server/IIS/SQL Server EPIQ baseline |

## 5. Strong Alignments

## 5.1 Modular platform shape matches the scope well

The scope document organizes the product around business domains like access, creation, training, certification, workflow, and reporting. The backend route tree is already organized that way.

Evidence:

- [apps/api_server/pharma_learn/api/lib/routes/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/routes.dart)
- [apps/api_server/pharma_learn/api/lib/routes/access/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/access/routes.dart)
- [apps/api_server/pharma_learn/api/lib/routes/create/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/create/routes.dart)

Assessment:

- `Aligned` for overall modular decomposition

## 5.2 Core regulated controls are present

The scope document emphasizes 21 CFR Part 11, Annex 11, audit trail immutability, e-signatures, record retention, and integrity. These are strongly reflected in the schema and tests.

Evidence:

- [supabase/schemas/02_core/01_audit_log.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/02_core/01_audit_log.sql)
- [supabase/schemas/02_core/05_esignature_base.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/02_core/05_esignature_base.sql)
- [supabase/schemas/10_integrity_verification.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/02_core/10_integrity_verification.sql)
- [supabase/tests/01_compliance_tests.sql](/Users/navadeepreddy/pharma_learn/supabase/tests/01_compliance_tests.sql)

Assessment:

- `Aligned` for compliance primitives

## 5.3 Document control is much stronger than a basic LMS

The scope document treats document-driven training as central. The codebase has a real document-control surface, not just file upload.

Evidence:

- [apps/api_server/pharma_learn/api/lib/routes/create/documents/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/create/documents/routes.dart)

This includes:

- document CRUD
- submit/approve/reject workflow
- version history
- document readings and acknowledgment
- integrity verification
- export
- controlled copy issuance

Assessment:

- `Aligned` for Document Manager backend

## 5.4 Training and qualification domains are broadly modeled

The scope document expects:

- curricula
- GTPs
- schedules and sessions
- induction
- OJT
- self-learning
- assessment
- retraining
- certificates

Evidence:

- `create` routes for curricula, GTPs, courses, trainers, venues, question banks, question papers
- `train` routes for sessions, schedules, OJT, induction, self-learning, retraining, external training
- `certify` routes for assessments, competencies, compliance, certificates, waivers, e-signatures

Schema evidence:

- [supabase/schemas/07_training](/Users/navadeepreddy/pharma_learn/supabase/schemas/07_training)
- [supabase/schemas/08_assessment](/Users/navadeepreddy/pharma_learn/supabase/schemas/08_assessment)
- [supabase/schemas/09_compliance](/Users/navadeepreddy/pharma_learn/supabase/schemas/09_compliance)

Assessment:

- `Partial to Aligned` depending on sub-domain

## 6. Major Gaps

## 6.1 The frontend is not a usable LMS yet

The scope document describes a rich multi-persona system. The Flutter app does not yet expose that experience.

Evidence:

- [apps/pharma_learn/lib/core/router/app_router.dart](/Users/navadeepreddy/pharma_learn/apps/pharma_learn/lib/core/router/app_router.dart)
- [apps/pharma_learn/lib/screens/screens.dart](/Users/navadeepreddy/pharma_learn/apps/pharma_learn/lib/screens/screens.dart)

Observed state:

- the router exists and covers major flows
- almost every route renders `_PlaceholderScreen`
- `screens.dart` exports many screen files
- the `screens/` directory only contains `screens.dart`

This means:

- learner UI is not implemented
- trainer UI is not implemented
- coordinator UI is not implemented
- admin UI is not implemented
- reporting UI is not implemented

Assessment:

- `Gap`

Impact:

- the codebase currently behaves more like a backend platform than a complete LMS product

## 6.2 System Manager is only partially surfaced

The scope document expects a Learn-IQ-like System Manager with:

- role registration
- global profiles
- user profiles
- departments
- groups and subgroups
- subgroup assignment
- job responsibilities
- standard reasons
- mail settings

What exists clearly:

- auth
- employees
- roles
- groups
- SSO configs
- delegations
- biometrics
- standard reasons

Evidence:

- [apps/api_server/pharma_learn/api/lib/routes/access/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/access/routes.dart)
- [apps/api_server/pharma_learn/api/lib/routes/workflow/standard_reasons/standard_reason_handler.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/workflow/standard_reasons/standard_reason_handler.dart)

What is missing or not clearly surfaced as APIs:

- dedicated department management routes
- subgroup CRUD and subgroup assignment routes
- job responsibility CRUD and acceptance routes
- global profile management routes
- user profile management routes
- mail settings management routes

Schema evidence that these concepts exist:

- [supabase/schemas/03_organization/03_departments.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/03_organization/03_departments.sql)
- [supabase/schemas/04_identity/07_subgroups.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/04_identity/07_subgroups.sql)
- [supabase/schemas/04_identity/10_employee_subgroups.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/04_identity/10_employee_subgroups.sql)
- [supabase/schemas/04_identity/11_job_responsibilities.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/04_identity/11_job_responsibilities.sql)
- [supabase/schemas/04_identity/04_global_profiles.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/04_identity/04_global_profiles.sql)
- [supabase/schemas/03_config/08_mail_settings.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/03_config/08_mail_settings.sql)

Assessment:

- `Partial`

## 6.3 Reporting exists more as infrastructure than as a finished product surface

The scope document expects rich operational and compliance reporting, dashboards, and graphical visibility.

What exists:

- report template models
- report run routes
- report schedule routes
- PDF/report services
- lifecycle monitor report generation service

Evidence:

- [apps/api_server/pharma_learn/api/lib/routes/reports](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/reports)
- [apps/api_server/pharma_learn/lifecycle_monitor/lib/services/report_generator_service.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/lifecycle_monitor/lib/services/report_generator_service.dart)
- [packages/pharmalearn_shared/lib/src/models/report_templates.dart](/Users/navadeepreddy/pharma_learn/packages/pharmalearn_shared/lib/src/models/report_templates.dart)

What is still weak:

- no completed reporting UI
- no clear evidence of full report catalog parity with the scope document’s rich report set
- no visible executive dashboard screens in the client

Assessment:

- `Partial`

## 6.4 Quality-to-training linkage is not yet proven end-to-end

The scope document highlights training needs arising from CAPA, deviation, and change control. The codebase has:

- quality workflow routes
- training trigger infrastructure

Evidence:

- [apps/api_server/pharma_learn/api/lib/routes/workflow/quality/routes.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/workflow/quality/routes.dart)
- [apps/api_server/pharma_learn/api/lib/routes/train/triggers_handler.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/train/triggers_handler.dart)

But the comparison gap is:

- the codebase shows the pieces
- it does not yet clearly demonstrate a complete end-to-end business flow where a quality event automatically creates, routes, tracks, and closes training obligations in the user-facing product

Assessment:

- `Partial`

## 7. Scope Section by Section

## 7.1 Business Objective and Pharma Context

Status:

- `Aligned`

Reason:

- the schema and route domains are clearly designed for regulated training, not generic learning
- training obligations, compliance, audit, e-signatures, waivers, certificates, OJT, and induction all exist

## 7.2 Learn-IQ Inside EPIQ vs Current Product Architecture

Status:

- `Divergence`

Reason:

The scope document describes Learn-IQ as part of the broader EPIQ ecosystem and its historical/reference technology patterns. The current codebase is a redesigned platform:

- Flutter client
- Dart/Relic backend services
- Supabase/Postgres
- edge functions
- self-hosted/private cloud shape

Evidence:

- [docs/architecture_onpremise.md](/Users/navadeepreddy/pharma_learn/docs/architecture_onpremise.md)
- [apps/api_server/pharma_learn/api/bin/server.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/bin/server.dart)

Implication:

- this is not a code-level gap
- it is an intentional platform divergence from the Learn-IQ/EPIQ reference stack

## 7.3 Functional Scope Baseline

### System Manager

- `Partial`

Backend coverage exists for roles, employees, groups, SSO, delegations, biometrics, standard reasons.
Missing exposure remains for departments, subgroups, job responsibilities, global/user profiles, and mail settings.

### Document Manager

- `Aligned`

This is one of the best-aligned parts of the implementation.

### Course Manager

- `Partial to Aligned`

Strong backend coverage exists for:

- categories/topics/courses
- trainers/venues
- question banks/question papers
- GTPs
- curricula
- periodic reviews

Main gap:

- client-side product surface is not yet present

### Reporting Layer

- `Partial`

Good backend foundation, unfinished end-user delivery.

## 7.4 Personas

Status:

- `Partial`

Reason:

- the backend supports many persona-specific surfaces
- the frontend does not yet implement real screens for those personas

Examples:

- coordinators: backend present
- learners: backend present
- trainers: backend present
- QA/compliance: backend present
- admin: backend present
- UI for all of the above: missing

## 7.5 End-to-End Process Coverage

Status:

- `Partial to Aligned`

Covered well in backend:

- assignment concepts
- sessioning
- attendance
- assessment
- retraining
- certification

Still weak:

- visible end-user orchestration
- proven business flow across admin, trainer, learner, supervisor, QA UI surfaces

## 7.6 Business Rules

Status:

- `Partial to Aligned`

Strongly covered:

- access control
- password policy
- session control
- e-signatures
- audit trail
- induction gate
- retention and integrity concepts

Partially surfaced:

- job responsibility lifecycle
- subgroup-driven assignment administration
- explicit global profile / user profile administration
- mail settings / notification administration

## 7.7 Architecture Understanding

Status:

- `Divergence`

The scope document includes the original Learn-IQ/EPIQ deployment picture:

- Windows Server
- IIS
- SQL Server
- SSRS
- AD-centric identity

The codebase is architected differently:

- Supabase/Postgres
- Relic services
- Flutter app
- edge functions
- private cloud / self-hosted architecture

This is not inherently a weakness, but it means:

- infrastructure, validation documentation, and operational controls must be re-expressed for the modern stack
- one cannot assume technical compatibility with the original Learn-IQ operating model

## 7.8 Integration Scope

Status:

- `Partial`

Present:

- SSO route surface
- biometrics route surface
- notifications
- report infrastructure

Less clear or absent as full product features:

- real AD connector behavior
- explicit DMS integration layer comparable to the reference ecosystem
- mail settings administration surface
- visible enterprise integration management UI

## 7.9 Compliance Scope

Status:

- `Aligned`

This is one of the strongest parts of the codebase.

Evidence includes:

- schema-level immutability and controlled record structures
- audit and e-signature services
- compliance tests
- integrity endpoints
- certificate verification/revocation flows

Relevant files:

- [supabase/tests/01_compliance_tests.sql](/Users/navadeepreddy/pharma_learn/supabase/tests/01_compliance_tests.sql)
- [apps/api_server/pharma_learn/api/lib/routes/certify/esignatures](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/certify/esignatures)
- [apps/api_server/pharma_learn/api/lib/routes/certify/integrity](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/certify/integrity)

## 7.10 Analytics, NFRs, Risks

Status:

- `Partial`

Covered:

- analytics schema and services
- health and metrics endpoints
- offline sync service class
- lifecycle background services

Still weak:

- operational dashboards in product UI
- proof of full observability delivery
- no visible frontend test surface

## 8. Concrete Implementation Gaps

## 8.1 Missing admin APIs for scope-critical entities

Gap:

- no clear dedicated route surface for `departments`
- no clear dedicated route surface for `subgroups`
- no clear dedicated route surface for `employee_subgroups`
- no clear dedicated route surface for `job_responsibilities`
- no clear dedicated route surface for `global_profiles`

Why this matters:

- these are central to the Learn-IQ-style System Manager and role-based assignment model described in the scope document

## 8.2 Flutter route shell exists, but screens do not

Gap:

- route skeleton exists
- actual screen implementations do not

Why this matters:

- this blocks the codebase from satisfying the scope document as a usable LMS, even where backend support is already present

## 8.3 Periodic review implementation appears misaligned to canonical schema

Gap:

- periodic review routes use `periodic_reviews`
- canonical schema file defines `periodic_review_schedules`

Evidence:

- [apps/api_server/pharma_learn/api/lib/routes/create/periodic_reviews/periodic_reviews_handler.dart](/Users/navadeepreddy/pharma_learn/apps/api_server/pharma_learn/api/lib/routes/create/periodic_reviews/periodic_reviews_handler.dart)
- [supabase/schemas/07_training/13_periodic_review_schedule.sql](/Users/navadeepreddy/pharma_learn/supabase/schemas/07_training/13_periodic_review_schedule.sql)

Why this matters:

- this is not only a scope gap
- it is a likely runtime/data-shape mismatch

## 8.4 Shared package barrel is not fully aligned with available services

Observation:

- `packages/pharmalearn_shared/lib/src/services/certificate_service.dart` exists
- the shared library barrel does not export it

Evidence:

- [packages/pharmalearn_shared/lib/pharmalearn_shared.dart](/Users/navadeepreddy/pharma_learn/packages/pharmalearn_shared/lib/pharmalearn_shared.dart)
- [packages/pharmalearn_shared/lib/src/services/certificate_service.dart](/Users/navadeepreddy/pharma_learn/packages/pharmalearn_shared/lib/src/services/certificate_service.dart)

Assessment:

- minor engineering gap rather than a scope gap

## 9. Architecture Divergence Summary

This deserves explicit treatment because it is easy to misclassify.

## 9.1 What the scope document reflects

The scope document includes the Learn-IQ/EPIQ reference architecture:

- Windows-hosted web application
- IIS
- SQL Server
- SSRS
- SSO/AD integration in an enterprise quality platform

## 9.2 What the codebase actually is

- Flutter client
- Dart backend services using Relic
- Supabase/Postgres backend platform
- edge functions for selected workflows
- modern modular service topology

## 9.3 Interpretation

This means:

- the codebase is **business-domain aligned**
- the codebase is **technology-stack divergent**

That is acceptable if intentional, but it changes:

- validation strategy
- infrastructure qualification approach
- deployment documentation
- integration design details
- support model compared with original EPIQ environments

## 10. Recommended Priority Order

## P1. Finish the System Manager surface

Build or expose:

- departments
- subgroups
- employee subgroup assignment
- job responsibilities
- global profiles
- user profiles or equivalent admin permission surface
- mail settings

## P2. Turn the Flutter app into a real product

Replace placeholder routes with implemented screens for:

- login and MFA
- dashboard
- obligations and sessions
- induction and OJT
- assessments
- certificates
- compliance and reporting
- settings and notifications

## P3. Close schema/handler mismatches

Start with:

- periodic review route/table alignment

Then systematically verify:

- route handlers against canonical schema names
- views vs tables used by reports and admin APIs

## P4. Prove end-to-end quality-triggered training

Show and test:

- deviation/CAPA/change-control event
- training trigger generation
- obligation creation
- learner completion
- QA/compliance visibility

## P5. Convert backend reporting into product reporting

Add:

- real report screens
- report filters
- dashboard graphs
- printable/downloadable user-facing outputs

## 11. Final Assessment

The `pharma_learn` codebase is **not an empty LMS scaffold**. It already has substantial backend depth and a serious compliance model. Against the scope document, its biggest weaknesses are not core pharma concepts but:

- unfinished admin surface
- unfinished frontend surface
- some entity-surface gaps between schema and exposed APIs
- technical divergence from the Learn-IQ/EPIQ reference architecture

The net result is:

- **backend platform maturity: medium to high**
- **scope completeness as a usable pharma LMS product: medium**
- **frontend and operational product readiness: low to medium**

If you want this comparison turned into an execution plan, the next best step is a **traceability matrix** from scope section -> schema tables -> API routes -> Flutter screens -> test coverage.
