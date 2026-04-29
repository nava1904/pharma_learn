# PharmaLearn LMS — API Reference

> **Version:** 2.0 | **Date:** April 2026 | **Endpoints:** 646+ | **Framework:** Relic HTTP

---

## Executive Summary

| Metric | Value |
|--------|-------|
| **Total Endpoints** | 646+ |
| **Handler Files** | 197 |
| **Route Modules** | 7 (access, certify, create, health, reports, train, workflow) |
| **Authentication** | JWT + E-Signature Reauth |
| **Compliance** | 21 CFR Part 11 |

---

## 1. API Architecture

```
apps/api_server/pharma_learn/api/lib/routes/
├── access/     (42 handlers)  — Auth, employees, roles, groups, SSO, biometrics
├── certify/    (31 handlers)  — E-signatures, assessments, certificates, compliance
├── create/     (49 handlers)  — Courses, documents, GTPs, SCORM, config
├── health/     (3 handlers)   — Health checks, readiness probes
├── reports/    (8 handlers)   — Report generation, templates, execution
├── train/      (42 handlers)  — Sessions, attendance, OJT, induction, self-learning
└── workflow/   (9 handlers)   — Approvals, quality events, audit trails
```

---

## 2. Authentication & Authorization

### 2.1 JWT Authentication

All endpoints (except `/health/*` and `/v1/auth/login`) require JWT:

```http
Authorization: Bearer <jwt_token>
```

### 2.2 E-Signature Re-authentication (21 CFR §11.200)

Critical actions require e-signature with re-authentication:

```http
POST /v1/certify/reauth/create
{
  "password": "user_password"
}
→ { "reauth_session_id": "uuid", "expires_at": "timestamp" }
```

Then include in request body:
```json
{
  "esig": {
    "reauth_session_id": "uuid",
    "meaning": "approved"
  }
}
```

---

## 3. Route Modules

### 3.1 ACCESS Module (98 endpoints)

#### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/auth/login` | User login (returns JWT) |
| POST | `/v1/auth/logout` | Logout (invalidates token) |
| POST | `/v1/auth/refresh` | Refresh JWT token |
| GET | `/v1/auth/profile` | Get current user profile |
| POST | `/v1/auth/password/change` | Change password |
| POST | `/v1/auth/mfa/enable` | Enable MFA |
| POST | `/v1/auth/mfa/verify` | Verify MFA code |

#### Employees
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/access/employees` | List employees (paginated) |
| POST | `/v1/access/employees` | Create employee |
| POST | `/v1/access/employees/bulk` | Bulk create employees |
| GET | `/v1/access/employees/:id` | Get employee details |
| PATCH | `/v1/access/employees/:id` | Update employee |
| POST | `/v1/access/employees/:id/deactivate` | Deactivate employee |
| POST | `/v1/access/employees/:id/unlock` | Unlock locked account |
| POST | `/v1/access/employees/:id/credentials/reset` | Reset credentials |
| GET | `/v1/access/employees/:id/roles` | List employee roles |
| POST | `/v1/access/employees/:id/roles` | Assign role |
| DELETE | `/v1/access/employees/:id/roles/:roleId` | Remove role |
| GET | `/v1/access/employees/:id/permissions` | Get effective permissions |
| POST | `/v1/access/employees/:id/permissions/grant` | Grant permission |
| POST | `/v1/access/employees/:id/permissions/revoke` | Revoke permission |
| POST | `/v1/access/employees/:id/pending-tasks/terminate` | Terminate all open tasks |

#### Roles & Permissions
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/access/roles` | List roles |
| POST | `/v1/access/roles` | Create role |
| GET | `/v1/access/roles/:id` | Get role details |
| PATCH | `/v1/access/roles/:id` | Update role |
| DELETE | `/v1/access/roles/:id` | Delete role |
| GET | `/v1/access/permissions` | List all permissions |

#### Groups & Subgroups
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/access/groups` | List groups |
| POST | `/v1/access/groups` | Create group |
| GET | `/v1/access/groups/:id` | Get group with members |
| PATCH | `/v1/access/groups/:id` | Update group |
| DELETE | `/v1/access/groups/:id` | Delete group |
| POST | `/v1/access/groups/:id/members` | Add members |
| DELETE | `/v1/access/groups/:id/members/:empId` | Remove member |

#### SSO & Biometrics
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/access/sso/configs` | List SSO configurations |
| POST | `/v1/access/sso/login` | SSO login initiate |
| GET | `/v1/access/sso/callback` | SSO callback handler |
| POST | `/v1/access/biometric/register` | Register biometric |
| POST | `/v1/access/biometric/login` | Biometric login |
| DELETE | `/v1/access/biometric/:id` | Revoke biometric |

#### Delegations
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/access/delegations` | List delegations |
| POST | `/v1/access/delegations` | Create delegation |
| GET | `/v1/access/delegations/:id` | Get delegation |
| PATCH | `/v1/access/delegations/:id` | Update delegation |
| POST | `/v1/access/delegations/:id/revoke` | Revoke delegation |

---

### 3.2 CREATE Module (113 endpoints)

#### Courses
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/courses` | List courses |
| POST | `/v1/courses` | Create course |
| GET | `/v1/courses/:id` | Get course details |
| PATCH | `/v1/courses/:id` | Update course |
| DELETE | `/v1/courses/:id` | Delete course |
| POST | `/v1/courses/:id/submit` | Submit for approval |
| POST | `/v1/courses/:id/approve` | Approve course (e-sig) |
| GET | `/v1/courses/:id/topics` | List course topics |
| POST | `/v1/courses/:id/topics` | Add topic to course |
| GET | `/v1/courses/:id/documents` | List course documents |
| POST | `/v1/courses/:id/documents` | Link document |

#### Documents
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/documents` | List documents |
| POST | `/v1/documents` | Create document |
| GET | `/v1/documents/:id` | Get document details |
| PATCH | `/v1/documents/:id` | Update document |
| DELETE | `/v1/documents/:id` | Delete document (draft only) |
| POST | `/v1/documents/:id/submit` | Submit for approval |
| POST | `/v1/documents/:id/approve` | Approve (e-sig) |
| POST | `/v1/documents/:id/reject` | Reject with reason |
| GET | `/v1/documents/:id/versions` | List versions |
| POST | `/v1/documents/:id/versions` | Create new version |
| GET | `/v1/documents/:id/export` | Export as PDF (21 CFR §11.10(b)) |
| GET | `/v1/documents/:id/acknowledgements` | List acknowledgements |
| POST | `/v1/documents/:id/acknowledge` | Acknowledge reading (e-sig) |

#### Question Banks & Papers
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/question-banks` | List question banks |
| POST | `/v1/question-banks` | Create question bank |
| GET | `/v1/question-banks/:id` | Get question bank |
| PATCH | `/v1/question-banks/:id` | Update question bank |
| DELETE | `/v1/question-banks/:id` | Delete question bank |
| GET | `/v1/questions` | List questions |
| POST | `/v1/questions` | Create question |
| PATCH | `/v1/questions/:id` | Update question |
| DELETE | `/v1/questions/:id` | Delete question |
| GET | `/v1/question-papers` | List question papers |
| POST | `/v1/question-papers` | Create question paper |
| GET | `/v1/question-papers/:id` | Get question paper |
| PATCH | `/v1/question-papers/:id` | Update paper |
| POST | `/v1/question-papers/:id/publish` | Publish paper (e-sig) |
| GET | `/v1/question-papers/:id/print` | Generate PDF |

#### GTPs (Group Training Plans)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/gtps` | List GTPs |
| POST | `/v1/gtps` | Create GTP |
| GET | `/v1/gtps/:id` | Get GTP details |
| PATCH | `/v1/gtps/:id` | Update GTP |
| POST | `/v1/gtps/:id/submit` | Submit for approval |
| POST | `/v1/gtps/:id/approve` | Approve (e-sig) |
| GET | `/v1/gtps/:id/courses` | List GTP courses |
| POST | `/v1/gtps/:id/courses` | Add course to GTP |

#### SCORM
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/scorm/packages` | List SCORM packages |
| POST | `/v1/scorm/packages` | Upload SCORM package |
| GET | `/v1/scorm/packages/:id` | Get package details |
| DELETE | `/v1/scorm/packages/:id` | Delete package |
| GET | `/v1/scorm/packages/:id/launch` | Get launch parameters |
| POST | `/v1/scorm/:id/initialize` | Initialize SCORM session |
| POST | `/v1/scorm/:id/commit` | Commit SCORM data |
| GET | `/v1/scorm/:id/progress` | Get progress |

#### Trainers & Venues
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/trainers` | List trainers |
| POST | `/v1/trainers` | Register trainer |
| GET | `/v1/trainers/:id` | Get trainer details |
| PATCH | `/v1/trainers/:id` | Update trainer |
| POST | `/v1/trainers/:id/approve` | Approve trainer (e-sig) |
| GET | `/v1/venues` | List venues |
| POST | `/v1/venues` | Create venue |
| GET | `/v1/venues/:id` | Get venue details |
| PATCH | `/v1/venues/:id` | Update venue |
| DELETE | `/v1/venues/:id` | Delete venue |

#### Configuration
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/config/password-policies` | Get password policies |
| PATCH | `/v1/config/password-policies` | Update password policies |
| GET | `/v1/config/approval-matrices` | List approval matrices |
| POST | `/v1/config/approval-matrices` | Create approval matrix |
| GET | `/v1/config/feature-flags` | List feature flags |
| PATCH | `/v1/config/feature-flags/:key` | Toggle feature flag |
| GET | `/v1/config/retention-policies` | List retention policies |
| POST | `/v1/config/retention-policies` | Create retention policy |

---

### 3.3 TRAIN Module (66 endpoints)

#### Schedules
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/train/schedules` | List schedules |
| POST | `/v1/train/schedules` | Create schedule |
| GET | `/v1/train/schedules/:id` | Get schedule details |
| PATCH | `/v1/train/schedules/:id` | Update schedule |
| POST | `/v1/train/schedules/:id/cancel` | Cancel schedule |
| POST | `/v1/train/schedules/:id/submit` | Submit for approval |
| POST | `/v1/train/schedules/:id/approve` | Approve (e-sig) |
| POST | `/v1/train/schedules/:id/enroll` | Enroll employees |
| DELETE | `/v1/train/schedules/:id/enroll/:empId` | Unenroll employee |
| GET | `/v1/train/schedules/:id/enrollments` | List enrollments |
| POST | `/v1/train/schedules/:id/self-nominate` | Self-nominate |
| GET | `/v1/train/schedules/:id/nominations` | List nominations |
| POST | `/v1/train/schedules/:id/nominations/:empId/accept` | Accept nomination |
| POST | `/v1/train/schedules/:id/nominations/:empId/reject` | Reject nomination |

#### Sessions & Attendance
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/train/sessions` | List sessions |
| GET | `/v1/train/sessions/:id` | Get session details |
| POST | `/v1/train/sessions/:id/check-in` | Check-in (QR/manual) |
| POST | `/v1/train/sessions/:id/check-out` | Check-out |
| GET | `/v1/train/sessions/:id/attendance` | List attendance |
| POST | `/v1/train/sessions/:id/attendance/mark` | Mark attendance |
| POST | `/v1/train/sessions/:id/attendance/correct` | Correct attendance (21 CFR §11.10) |
| POST | `/v1/train/sessions/:id/attendance/upload` | Upload attendance sheet |
| GET | `/v1/train/sessions/:id/qr` | Generate QR code |

#### Batches
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/train/batches` | List batches |
| POST | `/v1/train/batches` | Create batch |
| GET | `/v1/train/batches/:id` | Get batch details |
| PATCH | `/v1/train/batches/:id` | Update batch |
| POST | `/v1/train/batches/:id/add-schedule` | Add schedule to batch |
| GET | `/v1/train/batches/:id/attendance-sheet` | Generate attendance PDF |

#### OJT (On-the-Job Training)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/train/ojt` | List OJT assignments |
| GET | `/v1/train/ojt/:id` | Get OJT details |
| GET | `/v1/train/ojt/:id/tasks` | List OJT tasks |
| POST | `/v1/train/ojt/:id/tasks/:taskId/complete` | Complete task (e-sig) |
| POST | `/v1/train/ojt/:id/sign-off` | Evaluator sign-off (e-sig) |
| POST | `/v1/train/ojt/:id/complete` | Complete OJT (e-sig) |

#### Induction
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/train/induction/status` | My induction status |
| GET | `/v1/train/induction/modules` | List my modules |
| GET | `/v1/train/induction/modules/:id` | Get module details |
| POST | `/v1/train/induction/complete` | Complete induction (e-sig) |
| POST | `/v1/train/induction` | Register employee (coordinator) |
| GET | `/v1/train/induction` | List all inductions (coordinator) |
| POST | `/v1/train/induction/:id/trainer-respond` | Trainer accept/decline |
| POST | `/v1/train/induction/:id/record` | Record completion (e-sig) |

#### Self-Learning
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/train/self-learning/start` | Start self-learning |
| GET | `/v1/train/self-learning/progress` | Get progress |
| POST | `/v1/train/self-learning/complete` | Complete self-learning |
| GET | `/v1/train/self-learning/status` | Get status |

#### Employee Dashboard
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/train/me/dashboard` | My training dashboard |
| GET | `/v1/train/me/history` | My training history |
| GET | `/v1/train/me/obligations` | My training obligations |
| GET | `/v1/train/me/certificates` | My certificates |

#### Training Triggers
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/train/triggers/rules` | List trigger rules |
| POST | `/v1/train/triggers/rules` | Create trigger rule |
| GET | `/v1/train/triggers/rules/:id` | Get rule details |
| PATCH | `/v1/train/triggers/rules/:id` | Update rule |
| DELETE | `/v1/train/triggers/rules/:id` | Delete rule |
| GET | `/v1/train/triggers/events` | List trigger events |
| POST | `/v1/train/triggers/events/:id/reprocess` | Reprocess event |
| POST | `/v1/train/triggers/fire` | Manually fire trigger |
| GET | `/v1/train/triggers/stats` | Get trigger statistics |

---

### 3.4 CERTIFY Module (63 endpoints)

#### Assessments
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/certify/assessments/start` | Start assessment |
| POST | `/v1/certify/assessments/:id/answer` | Submit answer |
| POST | `/v1/certify/assessments/:id/submit` | Submit assessment |
| GET | `/v1/certify/assessments/:id` | Get assessment |
| GET | `/v1/certify/assessments/history` | Assessment history |
| POST | `/v1/certify/assessments/:id/grade` | Grade assessment |
| GET | `/v1/certify/assessments/:id/analysis` | Question analysis |
| POST | `/v1/certify/assessments/:id/extend` | Request extension |
| POST | `/v1/certify/assessments/:id/extend/approve` | Approve extension (e-sig) |
| POST | `/v1/certify/assessments/:id/extend/reject` | Reject extension |

#### E-Signatures
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/certify/esignatures` | List e-signatures |
| GET | `/v1/certify/esignatures/:id` | Get e-signature details |
| POST | `/v1/certify/esignatures/create` | Create e-signature |
| GET | `/v1/certify/esignatures/:id/verify` | Verify e-signature |
| GET | `/v1/certify/esignatures/history/:entityType/:entityId` | E-sig history |
| POST | `/v1/certify/reauth/create` | Create reauth session |
| POST | `/v1/certify/reauth/validate` | Validate reauth session |

#### Certificates
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/certify/certificates` | List certificates |
| GET | `/v1/certify/certificates/:id` | Get certificate |
| GET | `/v1/certify/certificates/:id/download` | Download certificate PDF |
| POST | `/v1/certify/certificates/:id/revoke/initiate` | Initiate revocation (e-sig) |
| POST | `/v1/certify/certificates/:id/revoke/confirm` | Confirm revocation (e-sig) |
| POST | `/v1/certify/certificates/:id/revoke/cancel` | Cancel revocation |
| GET | `/v1/certify/certificates/verify/:number` | Public verification |

#### Compliance
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/certify/compliance/my` | My compliance status |
| GET | `/v1/certify/compliance/dashboard` | Compliance dashboard |
| GET | `/v1/certify/compliance/employee/:id` | Employee compliance |
| GET | `/v1/certify/compliance/summary` | Summary report |

#### Competencies
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/certify/competencies/my` | My competencies |
| GET | `/v1/certify/competencies/gaps` | My competency gaps |
| GET | `/v1/certify/competencies/employee/:id` | Employee competencies |

#### Waivers
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/certify/waivers/my` | My waivers |
| POST | `/v1/certify/waivers` | Request waiver |
| GET | `/v1/certify/waivers` | List waivers (coordinator) |
| GET | `/v1/certify/waivers/:id` | Get waiver details |
| POST | `/v1/certify/waivers/:id/approve` | Approve waiver (e-sig) |
| POST | `/v1/certify/waivers/:id/reject` | Reject waiver |

#### Integrity
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/certify/integrity/verify` | Verify hash chain integrity |
| GET | `/v1/certify/integrity/status` | Get integrity status |

---

### 3.5 WORKFLOW Module (16 endpoints)

#### Approvals
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/workflow/approvals` | List pending approvals |
| GET | `/v1/workflow/approvals/:id` | Get approval details |
| POST | `/v1/workflow/approvals/:id/approve` | Approve (e-sig) |
| POST | `/v1/workflow/approvals/:id/reject` | Reject |
| POST | `/v1/workflow/approvals/:id/return` | Return for corrections |

#### Quality Events
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/workflow/deviations` | List deviations |
| POST | `/v1/workflow/deviations` | Create deviation |
| GET | `/v1/workflow/deviations/:id` | Get deviation |
| PATCH | `/v1/workflow/deviations/:id` | Update deviation |
| GET | `/v1/workflow/capas` | List CAPAs |
| POST | `/v1/workflow/capas` | Create CAPA |
| GET | `/v1/workflow/change-controls` | List change controls |
| POST | `/v1/workflow/change-controls` | Create change control |

#### Audit
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/workflow/audit/:entityType/:entityId` | Get audit trail |
| GET | `/v1/workflow/audit/:entityType/:entityId/export` | Export audit (CSV/PDF) |

---

### 3.6 REPORTS Module (9 endpoints)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/reports/templates` | List report templates |
| GET | `/v1/reports/templates/:id` | Get template details |
| POST | `/v1/reports/run` | Run report |
| GET | `/v1/reports/executions` | List report executions |
| GET | `/v1/reports/executions/:id` | Get execution details |
| GET | `/v1/reports/executions/:id/download` | Download report |

#### Available Report Types
- Training History
- Compliance Summary
- Overdue Training
- Assessment Results
- Trainer Qualification
- Course List
- Session Batch
- Induction Status
- OJT Completion
- Pending Training
- Attendance
- Training Matrix Coverage
- E-Signature Audit

---

### 3.7 HEALTH Module (4 endpoints)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Basic health check |
| GET | `/health/ready` | Readiness probe |
| GET | `/health/live` | Liveness probe |
| GET | `/metrics` | Prometheus metrics |

---

## 4. Error Responses

### Standard Error Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": [
      { "field": "email", "message": "Invalid email format" }
    ]
  }
}
```

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request (validation error) |
| 401 | Unauthorized (missing/invalid JWT) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found |
| 409 | Conflict (duplicate, immutable record) |
| 422 | Unprocessable Entity (business rule violation) |
| 500 | Internal Server Error |

---

## 5. Pagination

All list endpoints support pagination:

```http
GET /v1/employees?page=1&limit=20&sort=created_at&order=desc
```

Response includes:
```json
{
  "data": [...],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}
```

---

## 6. Filtering

List endpoints support filtering via query parameters:

```http
GET /v1/train/sessions?status=scheduled&trainer_id=uuid&date_from=2026-04-01
```

---

*API Reference updated: April 2026*
