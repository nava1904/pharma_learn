# TRAIN Module — Training Delivery & Real-Time Tracking
**PharmaLearn LMS — Detailed Implementation Guide**

> **Version:** 1.0  
> **Date:** 2026-04-23  
> **Module Owner:** Training Operations Team  
> **Status:** Production Planning  
> **Compliance:** 21 CFR Part 11, WHO GMP, GAMP 5  
> **Dependencies:** CREATE module (courses, documents), ACCESS module (authentication), CERTIFY module (assessments)

---

## Table of Contents

1. [Module Overview](#module-overview)
2. [Core Concepts](#core-concepts)
3. [Data Model & Supabase Schema](#data-model--supabase-schema)
4. [API Architecture](#api-architecture)
5. [Real-Time Tracking](#real-time-tracking)
6. [Business Logic & Workflows](#business-logic--workflows)
7. [UI/UX Design](#uiux-design)
8. [Real-World Reference: Learn IQ by Caliber](#real-world-reference-learn-iq-by-caliber)
9. [Vyuh Framework Integration](#vyuh-framework-integration)
10. [Compliance & Audit](#compliance--audit)
11. [Implementation Checklist](#implementation-checklist)

---

## Module Overview

### Purpose

The **TRAIN** module enables pharma organizations to deliver, track, and manage training programs across all modalities:
- **Classroom training** (instructor-led sessions with attendance tracking)
- **Self-learning** (online courses with progress tracking)
- **On-the-Job Training (OJT)** (practical skills with supervisor sign-off)
- **Induction programs** (new hire onboarding)
- **Periodic refresher training** (compliance-driven recurring training)

### Key Features

- **Training Schedules**: Plan classroom sessions with capacity, venue, trainer assignment
- **Real-Time Attendance**: Check-in/check-out with QR codes or biometric
- **Self-Learning Progress**: Track page views, document reading, video playback
- **OJT Tracking**: Supervisor sign-off on practical skills
- **Training Assignments**: Auto-assign courses based on roles/competencies
- **Notifications**: Real-time alerts for training deadlines, attendance reminders
- **Performance Analytics**: Dashboard showing completion rates, pass rates
- **Offline Capability**: Log attendance locally, sync when online

### Success Metrics

| Metric | Target | Rationale |
|--------|--------|-----------|
| Attendance check-in | < 10 sec | Queue management in large sessions |
| Progress tracking (p95) | < 100ms | Real-time dashboard updates |
| Notification delivery | < 1 min | Timely reminders |
| Self-learning page load | < 2 sec | Document reading experience |
| OJT sign-off (p95) | < 30 sec | Practical workflow |
| Sync delay (offline→online) | < 5 sec | Seamless handoff |

---

## Core Concepts

### 1. Training Types

```
┌─────────────────────────────────────────────────────────────┐
│              TRAINING DELIVERY MODALITIES                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Type 1: CLASSROOM                                          │
│  ├─ Trainer-led, time-bound                               │
│  ├─ Physical venue + capacity                             │
│  ├─ Real-time attendance (QR code / biometric)            │
│  ├─ Live discussion forum (Realtime)                      │
│  └─ Immediate certification on pass                       │
│                                                             │
│  Type 2: SELF-LEARNING                                     │
│  ├─ Asynchronous, self-paced                              │
│  ├─ Documents / videos / interactive content              │
│  ├─ Progress tracking (page views, time spent)            │
│  ├─ Optional: Assessments at end                          │
│  └─ Certificate issued on completion + pass               │
│                                                             │
│  Type 3: OJT (On-the-Job Training)                        │
│  ├─ Practical skill demonstration                         │
│  ├─ Supervisor checklist-based                            │
│  ├─ Multiple sign-offs over time                          │
│  ├─ Competency evaluation                                 │
│  └─ Certificate issued on supervisor approval             │
│                                                             │
│  Type 4: INDUCTION                                          │
│  ├─ New hire onboarding program                           │
│  ├─ Combination of classroom + self-learning              │
│  ├─ Mandatory modules (workplace safety, policies)        │
│  ├─ Tracked against 30-60-90 day milestones               │
│  └─ Completion report to HR                               │
│                                                             │
│  Type 5: PERIODIC (Refresher)                             │
│  ├─ Recurring every N months (e.g., GMP annually)        │
│  ├─ Rules-based assignment (auto-trigger)                │
│  ├─ Expiry tracking                                        │
│  └─ Non-compliance alerts                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2. GTP (Global Training Plan) vs. COURSE

```
GTP (Learning Path)           COURSE (Single Module)
├─ Multi-course program       ├─ Single training unit
├─ Structured sequence        ├─ Standalone
├─ Prerequisites enforced      ├─ Can have prerequisites
├─ Long duration (weeks)       ├─ Short duration (hours)
├─ Certification at end        ├─ Certificate issued
└─ Examples:                   └─ Examples:
   - Manufacturing onboarding     - GMP Basics (4 hours)
   - Quality Manager track         - Document Control (2 hours)
   - Compliance specialist prog.   - Safety Training (1 hour)
```

### 3. Training Session Lifecycle

```
┌──────────────┐
│   PLANNED    │ (Created, not yet started)
└──────┬───────┘
       │ Start date reached
       ▼
┌──────────────┐
│  IN_PROGRESS │ (Attendance open)
└──────┬───────┘
       │ End date reached
       ▼
┌──────────────┐
│  COMPLETED   │ (Attendance finalized, grading)
└──────┬───────┘
       │ Assessments graded
       ├─────────────────────┐
       ▼                     ▼
  ┌────────┐         ┌─────────────┐
  │ PASSED │         │   FAILED    │
  │        │         │             │
  │Cert    │         │Remedial     │
  │issued  │         │training req.│
  └────────┘         └─────────────┘
```

### 4. Attendance States

```
┌────────────┐     ┌────────────┐     ┌────────────┐
│   ABSENT   │────→│ REGISTERED │────→│  PRESENT   │
│            │     │  (Late)    │     │            │
└────────────┘     └────────────┘     └─────┬──────┘
                                            │
                                            ▼
                                       ┌─────────────┐
                                       │  COMPLETED  │
                                       │  (Checked   │
                                       │   out)      │
                                       └─────────────┘

Duration Tracking:
Session scheduled: 09:00 - 17:00 (8 hours)
Employee checked in: 09:15 (15 min late)
Employee checked out: 16:45 (15 min early)
Duration present: 7.5 hours
Status: ATTENDED (meets minimum 80%)
```

---

## Data Model & Supabase Schema

### Core Tables

#### 1. **gtp_masters** — Global Training Plans

```sql
CREATE TABLE IF NOT EXISTS gtp_masters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    -- GTP definition
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    gtp_category gtp_category,  -- 'onboarding', 'recurrent', 'competency'
    
    -- Structure
    estimated_duration_hours NUMERIC(6,2),
    total_courses INTEGER,
    
    -- Prerequisite
    prerequisite_gtp_id UUID REFERENCES gtp_masters(id),
    
    -- Frequency
    frequency_months INTEGER,  -- NULL = one-time, otherwise recurring
    is_mandatory BOOLEAN DEFAULT TRUE,
    
    -- Eligibility
    applicable_roles UUID[],  -- Role IDs who must take this
    applicable_departments UUID[],
    
    -- Status
    status workflow_state DEFAULT 'draft',
    effective_from DATE,
    effective_until DATE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID
);
```

#### 2. **training_schedules** — Planned sessions

```sql
CREATE TABLE IF NOT EXISTS training_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    -- What is being trained?
    gtp_id UUID REFERENCES gtp_masters(id),
    course_id UUID NOT NULL REFERENCES courses(id),
    
    -- Schedule details
    unique_code TEXT NOT NULL,
    training_type training_type NOT NULL,  -- 'initial', 'refresher', 'remedial'
    schedule_category schedule_type NOT NULL,  -- 'planned', 'recommended'
    
    -- Dates
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- Timing
    start_time TIME,  -- 09:00
    end_time TIME,    -- 17:00
    total_duration_hours NUMERIC(6,2),
    
    -- Venue & Capacity
    venue_id UUID REFERENCES training_venues(id),
    max_participants INTEGER,
    
    -- Trainer assignment
    trainer_id UUID REFERENCES trainers(id),
    external_trainer_id UUID REFERENCES external_trainers(id),
    
    -- Status & Workflow
    status workflow_state DEFAULT 'draft',
    initiated_by UUID REFERENCES employees(id),
    initiated_at TIMESTAMPTZ,
    approved_by UUID REFERENCES employees(id),
    approved_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    
    UNIQUE(organization_id, unique_code),
    CONSTRAINT chk_schedule_dates CHECK (end_date >= start_date)
);

CREATE INDEX idx_schedules_org ON training_schedules(organization_id);
CREATE INDEX idx_schedules_course ON training_schedules(course_id);
CREATE INDEX idx_schedules_dates ON training_schedules(start_date, end_date);
```

#### 3. **training_sessions** — Individual class instances

```sql
CREATE TABLE IF NOT EXISTS training_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id),
    
    -- Session details
    session_date DATE NOT NULL,
    session_number INTEGER,  -- 1, 2, 3 for multi-day courses
    
    -- Timing
    scheduled_start_time TIME NOT NULL,
    scheduled_end_time TIME NOT NULL,
    actual_start_time TIMESTAMPTZ,
    actual_end_time TIMESTAMPTZ,
    
    -- Room assignment
    venue_id UUID REFERENCES training_venues(id),
    room_number TEXT,
    
    -- Trainer
    trainer_id UUID REFERENCES trainers(id),
    
    -- Status
    status session_status,  -- 'planned', 'in_progress', 'completed', 'cancelled'
    
    -- Attendance tracking
    expected_attendees INTEGER,
    actual_attendees INTEGER,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sessions_schedule ON training_sessions(schedule_id);
CREATE INDEX idx_sessions_date ON training_sessions(session_date);
```

#### 4. **training_assignments** — Who should take which training?

```sql
CREATE TABLE IF NOT EXISTS training_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    course_id UUID NOT NULL REFERENCES courses(id),
    schedule_id UUID REFERENCES training_schedules(id),
    
    -- Assignment type
    assignment_type assignment_type,  -- 'mandatory', 'recommended', 'optional'
    assignment_reason TEXT,  -- 'role_requirement', 'compliance', 'skill_gap'
    
    -- Timing
    assigned_on DATE DEFAULT CURRENT_DATE,
    assignment_due_date DATE NOT NULL,
    
    -- Enrollment
    enrolled_on TIMESTAMPTZ,
    enrolled_by UUID REFERENCES employees(id),
    
    -- Status
    status training_status,  -- 'assigned', 'enrolled', 'in_progress', 'completed', 'failed', 'exempted'
    
    -- Completion
    completion_percentage INTEGER,
    completed_on TIMESTAMPTZ,
    
    -- Certificate
    certificate_issued_on TIMESTAMPTZ,
    certificate_id UUID REFERENCES certificates(id),
    
    -- Exemptions
    is_exempted BOOLEAN DEFAULT FALSE,
    exemption_reason TEXT,
    exempted_by UUID REFERENCES employees(id),
    exempted_on TIMESTAMPTZ,
    
    -- Compliance
    days_overdue INTEGER GENERATED ALWAYS AS (
        GREATEST(0, EXTRACT(day FROM (CURRENT_DATE - assignment_due_date))::INTEGER)
    ) STORED,
    
    UNIQUE(employee_id, course_id),
    CREATED_AT TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_assignments_emp ON training_assignments(employee_id);
CREATE INDEX idx_assignments_course ON training_assignments(course_id);
CREATE INDEX idx_assignments_status ON training_assignments(status);
CREATE INDEX idx_assignments_due ON training_assignments(assignment_due_date);
```

#### 5. **attendance** — Check-in/Check-out records

```sql
CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES training_sessions(id),
    employee_id UUID NOT NULL REFERENCES employees(id),
    
    -- Check-in
    check_in_time TIMESTAMPTZ,
    check_in_method check_in_method,  -- 'qr_code', 'biometric', 'manual'
    check_in_device TEXT,  -- Device ID
    check_in_ip INET,
    
    -- Check-out
    check_out_time TIMESTAMPTZ,
    check_out_method check_in_method,
    check_out_device TEXT,
    check_out_ip INET,
    
    -- Tracking
    attendance_status attendance_status,  -- 'present', 'absent', 'late', 'left_early'
    duration_minutes INTEGER GENERATED ALWAYS AS (
        EXTRACT(epoch FROM (check_out_time - check_in_time))::INTEGER / 60
    ) STORED,
    
    -- Compliance
    session_scheduled_minutes INTEGER,
    attendance_percentage NUMERIC(5,2) GENERATED ALWAYS AS (
        ROUND((duration_minutes::NUMERIC / session_scheduled_minutes) * 100, 2)
    ) STORED,
    
    -- Remarks
    remarks TEXT,  -- "Left for medical emergency"
    approved_by UUID REFERENCES employees(id),
    approved_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(session_id, employee_id)
);

CREATE INDEX idx_attendance_session ON attendance(session_id);
CREATE INDEX idx_attendance_employee ON attendance(employee_id);
CREATE INDEX idx_attendance_status ON attendance(attendance_status);
```

#### 6. **self_learning_assignments** — Online course assignments

```sql
CREATE TABLE IF NOT EXISTS self_learning_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    course_id UUID NOT NULL REFERENCES courses(id),
    
    -- Assignment
    assigned_on TIMESTAMPTZ DEFAULT NOW(),
    assigned_by UUID REFERENCES employees(id),
    assignment_due_date DATE NOT NULL,
    
    -- Progress
    started_on TIMESTAMPTZ,
    completed_on TIMESTAMPTZ,
    
    -- Tracking
    documents_accessed INTEGER,
    pages_read INTEGER,
    videos_watched INTEGER,
    time_spent_seconds INTEGER,
    
    -- Status
    status training_status,  -- 'not_started', 'in_progress', 'completed'
    completion_percentage INTEGER,
    
    -- Assessment
    assessment_attempted BOOLEAN DEFAULT FALSE,
    assessment_passed BOOLEAN,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 7. **ojt_assignments** — On-the-Job Training

```sql
CREATE TABLE IF NOT EXISTS ojt_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    course_id UUID NOT NULL REFERENCES courses(id),
    supervisor_id UUID NOT NULL REFERENCES employees(id),
    
    -- OJT details
    assigned_on TIMESTAMPTZ DEFAULT NOW(),
    expected_completion_date DATE NOT NULL,
    
    -- Competency checklist
    skills_to_demonstrate TEXT[],  -- ["Operate lathe", "Quality check", ...]
    
    -- Tracking
    skill_progress JSONB,  -- {
                           --   "Operate lathe": {"status": "in_progress", "attempts": 2},
                           --   "Quality check": {"status": "completed", "sign_off_date": "2026-04-20"}
                           -- }
    
    -- Completion
    completed_on TIMESTAMPTZ,
    supervisor_sign_off_date TIMESTAMPTZ,
    supervisor_comments TEXT,
    
    -- Status
    status ojt_status,  -- 'assigned', 'in_progress', 'completed', 'failed'
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 8. **induction_plans** — New hire onboarding structure

```sql
CREATE TABLE IF NOT EXISTS induction_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    department_id UUID NOT NULL REFERENCES departments(id),
    job_role TEXT,  -- "Manufacturing Technician", "QA Officer"
    
    -- Induction stages
    stage_1_courses UUID[],  -- First week: safety, policies
    stage_2_courses UUID[],  -- Week 2-3: role-specific
    stage_3_courses UUID[],  -- Week 4-8: advanced
    
    -- Milestones
    day_30_milestone TIMESTAMP,
    day_60_milestone TIMESTAMP,
    day_90_milestone TIMESTAMP,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Induction tracking per employee
CREATE TABLE IF NOT EXISTS employee_inductions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    induction_plan_id UUID NOT NULL REFERENCES induction_plans(id),
    
    -- Tracking
    started_on TIMESTAMPTZ DEFAULT NOW(),
    stage_1_completed_on TIMESTAMPTZ,
    stage_2_completed_on TIMESTAMPTZ,
    stage_3_completed_on TIMESTAMPTZ,
    
    -- Milestones
    day_30_assessment_completed BOOLEAN,
    day_60_assessment_completed BOOLEAN,
    day_90_assessment_completed BOOLEAN,
    
    -- Final status
    status induction_status,  -- 'in_progress', 'completed', 'failed'
    completed_on TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## API Architecture

### 1. Create Training Schedule

**Endpoint:** `POST /v1/training-schedules`

**Request:**
```json
{
  "course_id": "course-uuid",
  "training_type": "initial",
  "schedule_category": "planned",
  
  "dates": {
    "start_date": "2026-05-15",
    "end_date": "2026-05-17",
    "start_time": "09:00",
    "end_time": "17:00"
  },
  
  "venue": {
    "venue_id": "venue-uuid",
    "max_participants": 30
  },
  
  "trainer": {
    "trainer_id": "trainer-uuid"
  },
  
  "metadata": {
    "unique_code": "SESSION-GMP-001-MAY2026",
    "total_duration_hours": 24
  }
}
```

**Response (201 Created):**
```json
{
  "id": "schedule-uuid",
  "unique_code": "SESSION-GMP-001-MAY2026",
  "status": "draft",
  "created_at": "2026-04-23T10:00:00Z",
  "_links": {
    "self": { "href": "/v1/training-schedules/schedule-uuid" },
    "sessions": { "href": "/v1/training-schedules/schedule-uuid/sessions" },
    "assign-employees": { "href": "/v1/training-schedules/schedule-uuid/assign" }
  }
}
```

### 2. Assign Employees to Schedule

**Endpoint:** `POST /v1/training-schedules/{schedule_id}/assign`

**Request:**
```json
{
  "assignment_method": "auto",  // or "manual"
  "criteria": {
    "department_ids": ["dept-uuid-1", "dept-uuid-2"],
    "role_ids": ["role-uuid"],
    "exclude_already_trained": true,
    "exclude_exempted": true
  }
}
```

**Response (200 OK):**
```json
{
  "schedule_id": "schedule-uuid",
  "assignments_created": 42,
  "employees": [
    {
      "employee_id": "emp-uuid",
      "name": "John Trainer",
      "status": "assigned",
      "enrollment_status": "pending"
    }
  ],
  "message": "42 employees assigned successfully"
}
```

### 3. Enroll Employee in Schedule

**Endpoint:** `POST /v1/training-schedules/{schedule_id}/enroll`

**Request:**
```json
{
  "employee_ids": ["emp-uuid-1", "emp-uuid-2"]
}
```

**Response (200 OK):**
```json
{
  "schedule_id": "schedule-uuid",
  "enrollments": [
    {
      "employee_id": "emp-uuid-1",
      "status": "enrolled",
      "enrolled_on": "2026-04-23T11:00:00Z",
      "session_id": "session-uuid-day1"
    }
  ]
}
```

### 4. Check-In to Session

**Endpoint:** `POST /v1/training-sessions/{session_id}/check-in`

**Request:**
```json
{
  "employee_id": "emp-uuid",
  "check_in_method": "qr_code",  // or "biometric", "manual"
  "device_id": "ipad-001",
  "ip_address": "192.168.1.50"
}
```

**Response (200 OK):**
```json
{
  "attendance_id": "attendance-uuid",
  "employee": {
    "id": "emp-uuid",
    "name": "John Trainer"
  },
  "session": {
    "id": "session-uuid",
    "course_name": "GMP Fundamentals",
    "date": "2026-05-15",
    "time": "09:00 - 17:00"
  },
  "check_in_time": "2026-05-15T09:10:30Z",
  "status": "present",
  "remarks": "Checked in 10 minutes late",
  "message": "Welcome to training! Check-in recorded."
}
```

### 5. Check-Out from Session

**Endpoint:** `POST /v1/training-sessions/{session_id}/check-out`

**Request:**
```json
{
  "employee_id": "emp-uuid",
  "check_out_method": "qr_code"
}
```

**Response (200 OK):**
```json
{
  "attendance_id": "attendance-uuid",
  "check_out_time": "2026-05-15T16:45:00Z",
  "duration_minutes": 465,  // 7.75 hours
  "attendance_percentage": 96.9,
  "status": "present",
  "message": "Check-out recorded. Thank you for attending!"
}
```

### 6. Get Session Attendance Dashboard

**Endpoint:** `GET /v1/training-sessions/{session_id}/attendance`

**Response (200 OK):**
```json
{
  "session": {
    "id": "session-uuid",
    "course": "GMP Fundamentals",
    "date": "2026-05-15",
    "expected_attendees": 30,
    "actual_attendees": 28,
    "attendance_rate": 93.3
  },
  "attendance_details": [
    {
      "employee_id": "emp-uuid-1",
      "name": "John Trainer",
      "check_in_time": "2026-05-15T09:10:30Z",
      "check_out_time": "2026-05-15T16:45:00Z",
      "duration": "7h 35m",
      "status": "present",
      "percentage": 95
    },
    {
      "employee_id": "emp-uuid-2",
      "name": "Jane Smith",
      "status": "absent",
      "absence_reason": "unexcused"
    }
  ],
  "statistics": {
    "present": 26,
    "late": 2,
    "absent": 2,
    "average_attendance_percentage": 94.5
  }
}
```

### 7. Assign Self-Learning Course

**Endpoint:** `POST /v1/self-learning/assign`

**Request:**
```json
{
  "employee_ids": ["emp-uuid-1", "emp-uuid-2"],
  "course_id": "course-uuid",
  "due_date": "2026-06-15",
  "assignment_reason": "annual_compliance"
}
```

**Response (200 OK):**
```json
{
  "assignments_created": 2,
  "assignments": [
    {
      "id": "assign-uuid-1",
      "employee_id": "emp-uuid-1",
      "course_id": "course-uuid",
      "status": "assigned",
      "due_date": "2026-06-15"
    }
  ]
}
```

### 8. Get Self-Learning Progress

**Endpoint:** `GET /v1/self-learning/{assignment_id}/progress`

**Response (200 OK):**
```json
{
  "assignment_id": "assign-uuid",
  "employee": "John Trainer",
  "course": "Manufacturing SOP Review",
  "assigned_on": "2026-04-20",
  "due_date": "2026-06-15",
  "status": "in_progress",
  
  "progress": {
    "documents_accessed": 8,
    "total_documents": 12,
    "pages_read": 45,
    "total_pages": 120,
    "videos_watched": 2,
    "total_videos": 4,
    "time_spent_minutes": 180,
    "completion_percentage": 42
  },
  
  "last_activity": "2026-04-23T14:30:00Z",
  "pages_accessed_today": [
    { "page": 10, "time": "2026-04-23T14:15:00Z" },
    { "page": 11, "time": "2026-04-23T14:30:00Z" }
  ],
  
  "assessment": {
    "available": true,
    "attempted": false,
    "required_for_completion": true
  }
}
```

### 9. Get Training Dashboard (Employee)

**Endpoint:** `GET /v1/training/my-dashboard`

**Response (200 OK):**
```json
{
  "employee_id": "emp-uuid",
  "name": "John Trainer",
  
  "pending_trainings": [
    {
      "id": "assign-uuid-1",
      "course_name": "Annual GMP Refresher",
      "type": "classroom",
      "status": "assigned",
      "due_date": "2026-05-31",
      "days_remaining": 38,
      "priority": "high",
      "is_overdue": false
    },
    {
      "id": "assign-uuid-2",
      "course_name": "Safety Training",
      "type": "self-learning",
      "status": "in_progress",
      "due_date": "2026-06-15",
      "completion_percentage": 42,
      "priority": "medium"
    }
  ],
  
  "overdue_trainings": [
    {
      "course_name": "Compliance Update",
      "due_date": "2026-04-10",
      "days_overdue": 13,
      "escalation_level": "manager_alert"
    }
  ],
  
  "completed_this_month": 3,
  "overall_completion_rate": 78,
  
  "upcoming_sessions": [
    {
      "course": "Manufacturing Best Practices",
      "schedule": "2026-05-15 to 2026-05-17",
      "enrollment_status": "enrolled",
      "session_1": "2026-05-15 09:00-17:00 Room A"
    }
  ]
}
```

### 10. OJT Sign-Off

**Endpoint:** `POST /v1/ojt/{assignment_id}/sign-off`

**Request:**
```json
{
  "skill": "Operate lathe",
  "status": "completed",  // or "needs_improvement"
  "supervisor_comments": "Employee demonstrated excellent machine operation skills",
  "sign_off_date": "2026-04-23"
}
```

**Response (200 OK):**
```json
{
  "ojt_id": "ojt-uuid",
  "skill": "Operate lathe",
  "status": "completed",
  "signed_off_by": "supervisor-name",
  "signed_off_on": "2026-04-23T14:00:00Z",
  "skills_completed": 2,
  "total_skills": 5,
  "completion_percentage": 40
}
```

### 11. Get Training Compliance Report

**Endpoint:** `GET /v1/training/compliance-report?department_id=dept-uuid`

**Response (200 OK):**
```json
{
  "department": "Manufacturing",
  "report_date": "2026-04-23",
  "total_employees": 45,
  
  "training_status": {
    "compliant": 35,
    "due_soon": 8,
    "overdue": 2,
    "exempted": 3
  },
  
  "trainings": [
    {
      "course": "Annual GMP Training",
      "frequency": "yearly",
      "total_assigned": 45,
      "completed": 35,
      "completion_rate": 77.8,
      "overdue_count": 2,
      "overdue_employees": ["John Doe", "Jane Smith"]
    }
  ],
  
  "compliance_score": 77.8,
  "status": "needs_attention",
  
  "recommendations": [
    "Follow up with 2 overdue employees",
    "Schedule refresher session for due_soon group (8 employees)"
  ]
}
```

---

## Real-Time Tracking

### Using Supabase Realtime for Live Updates

**Scenario:** Trainer dashboard showing real-time attendance as employees check in

```dart
// Initialize Realtime subscription
class AttendanceRealtimeService {
  late RealtimeChannel _channel;
  
  void subscribeToSessionAttendance(String sessionId) {
    _channel = supabase.realtime.channel('attendance:session_$sessionId');
    
    // Listen for new check-ins
    _channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: 'INSERT',
        schema: 'public',
        table: 'attendance',
        filter: 'session_id=eq.$sessionId',
      ),
      (payload, [ref]) {
        final attendance = Attendance.fromJson(payload['new']);
        
        // Update UI immediately (Riverpod state update)
        ref.read(sessionAttendanceProvider.notifier)
            .addAttendanceRecord(attendance);
        
        // Show toast: "John checked in at 09:15"
        showNotification(
          '${attendance.employee.name} checked in at ${attendance.checkInTime.format()}',
        );
      },
    ).subscribe();
  }
  
  void unsubscribe() {
    _channel.unsubscribe();
  }
}
```

**Real-Time Dashboard View (Flutter):**

```dart
class SessionAttendanceDashboard extends ConsumerWidget {
  final String sessionId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsyncValue = ref.watch(
      sessionAttendanceProvider(sessionId),
    );
    
    return RefreshIndicator(
      onRefresh: () => ref.refresh(sessionAttendanceProvider(sessionId)),
      child: attendanceAsyncValue.when(
        data: (attendance) {
          final presentCount = attendance
              .where((a) => a.status == AttendanceStatus.present)
              .length;
          
          return Column(
            children: [
              // Header with live count
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('Present',
                              style: Theme.of(context).textTheme.bodySmall),
                          Text(
                            '$presentCount',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      // ... other metrics
                    ],
                  ),
                ),
              ),
              
              // Live attendance list with animated entries
              Expanded(
                child: ListView.builder(
                  itemCount: attendance.length,
                  itemBuilder: (context, index) {
                    final record = attendance[index];
                    return AttendanceListTile(
                      attendance: record,
                      // Slide animation on new entry
                      key: ValueKey(record.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
```

### Offline Attendance with Sync

```dart
// User checks in offline
class OfflineAttendanceService {
  Future<void> checkInOffline(String sessionId, String employeeId) async {
    final attendance = Attendance(
      id: uuid.v4(),
      sessionId: sessionId,
      employeeId: employeeId,
      checkInTime: DateTime.now(),
      status: AttendanceStatus.pending,
      isSynced: false,  // Mark as not synced
    );
    
    // Save to local Hive box
    await hiveBox.put(attendance.id, attendance.toJson());
    
    // Show UI: "Recorded offline - will sync when online"
    showSnackBar('Check-in recorded. Will sync when online.');
  }
  
  // Background sync when online
  Future<void> syncPendingAttendance() async {
    if (!await isConnected()) return;
    
    final unsyncedRecords = hiveBox.values
        .where((record) => !record['isSynced'])
        .toList();
    
    for (var record in unsyncedRecords) {
      try {
        await supabase
            .from('attendance')
            .insert(record)
            .then((_) {
          // Mark as synced
          record['isSynced'] = true;
          hiveBox.put(record['id'], record);
        });
      } catch (e) {
        // Retry on next sync
        print('Sync failed: $e');
      }
    }
  }
}
```

---

## Business Logic & Workflows

### Workflow 1: Classroom Training Execution

```
Step 1: Create Schedule
  Input: Course, dates, venue, trainer
  Output: Schedule created (DRAFT status)
  
Step 2: Assign Employees
  Input: Criteria (dept, role, excludes)
  Output: Assignments created (30-100 employees)
  Rules:
    - Check for prerequisites
    - Check for exemptions
    - Notify employees of assignment
  
Step 3: Enrollments Open
  Input: Manual or auto-enrollment
  Output: Training assignments updated to ENROLLED
  Notifications:
    - Enroll confirmation sent
    - Calendar invite sent
  
Step 4: Session Starts (Pre-training)
  Input: Schedule date reached
  Output: Session status → IN_PROGRESS
  Trainer actions:
    - Generate QR code for check-in
    - Enable biometric check-in device
  
Step 5: Attendance Tracking
  Duration: 09:00 - 17:00 (8 hours)
  ├─ 09:00: Session starts
  ├─ 09:15: John checks in (QR) → Status: PRESENT
  ├─ 09:30: Jane checks in (QR) → Status: PRESENT
  ├─ 10:00: Mike absent → Status: ABSENT (no check-in)
  ├─ 12:00-13:00: Lunch break (no check-out needed)
  ├─ 16:45: John checks out → Duration: 7h 45m
  ├─ 16:50: Jane checks out → Duration: 7h 50m
  └─ 17:00: Session ends
  
Step 6: Attendance Finalization
  Rules:
    - Duration < 80% of session → Mark as ABSENT or PARTIAL
    - Absence + Exemption → No follow-up
    - Absence + Mandatory course → Escalate to manager
  
Step 7: Certificate Processing
  Input: Assessment results
  ├─ If PASSED: Generate certificate
  ├─ If FAILED: Assign remedial training
  └─ If NOT_ATTEMPTED: Allow retake
```

### Workflow 2: Self-Learning Tracking

```
Step 1: Assignment
  Employee receives self-learning assignment
  Due date: 2026-06-15
  
Step 2: Start Course
  Employee clicks "Start Learning"
  ├─ Open first document/video
  ├─ Track start time
  └─ Local progress saved to Hive
  
Step 3: Progress Tracking (Real-time)
  As employee interacts:
  ├─ Page 10 viewed (start_time, end_time)
  ├─ Video 2 started (timestamp, duration)
  ├─ Document 3 downloaded (offline)
  │
  └─ Realtime updates to:
     - Employee dashboard (completion %)
     - Manager dashboard (team progress)
     - Compliance report (training status)
  
Step 4: Assessment
  Employee completes all content
  ├─ Unlocked assessment
  ├─ Takes quiz (max attempts: 3)
  └─ Submission
  
Step 5: Result Processing
  ├─ AUTO_GRADE: Multiple choice
  │  └─ If PASSED: Issue certificate
  │  └─ If FAILED: Attempt 2 available
  │
  └─ MANUAL_GRADE: Essays (if applicable)
     └─ Grader reviews & assigns marks
  
Step 6: Completion
  Status: COMPLETED
  Certificate: Issued
  Compliance: Updated (training satisfied for this course)
```

### Workflow 3: OJT Skill Development

```
Skills Required:
├─ Operate lathe
├─ Quality check
├─ Documentation
└─ Safety protocol

Timeline: 4 weeks

Week 1: Operate Lathe
  Day 1-2: Trainer demonstrates (1 day)
  Day 3: Employee practices supervised (1 day)
  Day 4: Employee practices, trainer observes (1 day)
  Day 5: Employee operates independently, supervisor validates
         Sign-off: "Employee demonstrated competency"
  Status: SKILL COMPLETED ✓
  
Week 2: Quality Check
  (Same pattern as Operate Lathe)
  Status: SKILL COMPLETED ✓
  
Week 3: Documentation
  (Same pattern)
  Status: IN_PROGRESS (Day 1 of 5)
  
Week 4: Safety Protocol
  (Same pattern)
  Status: NOT_STARTED
  
Summary:
  ├─ 2 skills completed
  ├─ 1 skill in progress
  ├─ 1 skill pending
  └─ Estimated completion: 2026-05-21
  
Completion Criteria:
  All skills signed off by supervisor
  → Certificate issued
  → Training assignment marked COMPLETED
```

### Business Rules

**Rule 1: Attendance Calculation**
```
Session duration: 9:00-17:00 (8 hours)
Employee: Checked in 9:15, checked out 16:45
Present duration: 7h 30m (450 minutes)
Attendance %: 450 / 480 = 93.75%
Status: ATTENDED (meets 80% threshold)
```

**Rule 2: Training Overdue Escalation**
```
Day 1-7 after due date: Yellow flag (upcoming)
Day 8-14: Notification to employee
Day 15+: Notification to manager
Day 30+: Escalation to director
```

**Rule 3: Mandatory vs. Optional**
```
Mandatory course:
  └─ Non-completion = compliance risk
     → Flag in compliance report
     → Alert to manager
     
Optional course:
  └─ Tracked but not enforced
```

**Rule 4: Prerequisites**
```
Course A (Prerequisite) → Course B
├─ Employee not assigned to B until A completed
├─ If A failed: Remedial training required before B
└─ Exemptions: Manager approval required
```

---

## UI/UX Design

### Screen 1: Training Dashboard (Employee)

```
┌──────────────────────────────────────────────────┐
│ My Training                                  [+] │
├──────────────────────────────────────────────────┤
│                                                  │
│  ┌─ URGENT ─────────────────────────────────┐  │
│  │ GMP Refresher - DUE IN 7 DAYS             │  │
│  │ Training Type: Classroom                  │  │
│  │ Schedule: May 15-17, 2026                 │  │
│  │ [ENROLL NOW]                              │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ┌─ IN PROGRESS ──────────────────────────────┐ │
│  │ Safety Training                            │ │
│  │ Type: Self-Learning                        │ │
│  │ Progress: [████████░░░░░░░░░░] 42%         │ │
│  │ Due: June 15, 2026                         │ │
│  │ [CONTINUE] [DETAILS]                       │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  ┌─ UPCOMING ─────────────────────────────────┐ │
│  │ Manufacturing OJT                          │ │
│  │ Type: On-the-Job Training                 │ │
│  │ Assigned: May 20, 2026                     │ │
│  │ [DETAILS]                                  │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  ┌─ COMPLETED ────────────────────────────────┐ │
│  │ ✓ GMP Basics (Apr 2026)                    │ │
│  │ ✓ Safety Training (Mar 2026)               │ │
│  │ ✓ New Hire Induction (Jan 2026)            │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Screen 2: Session Check-In (iPad/Mobile)

```
┌──────────────────────────────────────────────────┐
│  GMP Fundamentals Training                       │
│  May 15, 2026 — 09:00 to 17:00                   │
├──────────────────────────────────────────────────┤
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │                                            │ │
│  │     Scan QR Code or Use Biometric         │ │
│  │                                            │ │
│  │            [QR SCANNER FRAME]             │ │
│  │            (Point camera at QR)           │ │
│  │                                            │ │
│  │  OR  [👆 TAP TO USE FINGERPRINT]           │ │
│  │                                            │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  Attendance so far:                             │
│  ✓ Checked in: 25 employees                    │
│  ○ Pending:    5 employees                     │
│  ✗ Absent:     2 employees                     │
│                                                  │
│  Last 3 check-ins:                             │
│  • John Trainer (09:10)                        │
│  • Jane Smith (09:12)                          │
│  • Mike Johnson (09:15)                        │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Screen 3: Training Session List (Trainer View)

```
┌────────────────────────────────────────────────┐
│ Training Sessions                          [+]  │
├────────────────────────────────────────────────┤
│                                                │
│ Filter: [Today ▼] [Upcoming ▼] [Past ▼]      │
│                                                │
│ MAY 15 (Today) — GMP Fundamentals              │
│ 09:00 - 17:00  |  Room A  |  30 participants  │
│ ┌──────────────────────────────────────────┐  │
│ │ ✓ LIVE: 25 present, 2 absent, 3 pending │  │
│ │                                          │  │
│ │ [📊 ATTENDANCE] [🎬 LIVE FEED] [⚙ MORE] │  │
│ └──────────────────────────────────────────┘  │
│                                                │
│ MAY 16 — GMP Fundamentals (Day 2)              │
│ 09:00 - 17:00  |  Room A  |  30 participants  │
│ ┌──────────────────────────────────────────┐  │
│ │ SCHEDULED: Opens tomorrow at 09:00       │  │
│ │                                          │  │
│ │ [📋 ROSTER] [⚙ EDIT] [🔔 NOTIFY]         │  │
│ └──────────────────────────────────────────┘  │
│                                                │
│ MAY 17 — GMP Fundamentals (Day 3)              │
│ 09:00 - 17:00  |  Room A  |  30 participants  │
│ ┌──────────────────────────────────────────┐  │
│ │ SCHEDULED: Opens May 17 at 09:00        │  │
│ └──────────────────────────────────────────┘  │
│                                                │
└────────────────────────────────────────────────┘
```

---

## Real-World Reference: Learn IQ by Caliber

### How Learn IQ Informs Our Design

**Learn IQ** is Caliber's competency-based training platform (used by major pharma companies).

#### 1. Competency Mapping

Learn IQ pattern we adopt:
```
Job Role: Manufacturing Manager
├─ Core Competencies
│  ├─ GMP Knowledge (Level 3 required)
│  ├─ Process Understanding (Level 2)
│  └─ Leadership Skills (Level 2)
│
├─ Required Training
│  ├─ Annual GMP Refresher
│  ├─ Safety Training
│  └─ Compliance Update
│
└─ Assessment
   ├─ Certification exam
   ├─ Practical assessment
   └─ Manager sign-off
```

#### 2. Training Recommendation Engine

Learn IQ logic we implement:
```
Algorithm: Recommend training if
├─ (current_date - last_training_date) > frequency_interval
├─ employee_competency_level < required_level
├─ role_changed_recently == true
└─ compliance_requirement_active == true

Output: Training recommendations with priority
├─ High: Annual compliance due today
├─ Medium: Due in 30 days
└─ Low: Optional skill development
```

#### 3. Attendance Flexibility

Learn IQ model:
```
Virtual attendance: 
├─ Live online session (real-time check-in via system)
├─ On-demand recording (watch within 7 days, auto-recorded)
└─ Self-paced classroom content (view at own pace)

Hybrid attendance:
├─ Half classroom, half online
├─ Flexible attendance windows
└─ Make-up sessions available
```

---

## Vyuh Framework Integration

### 1. **vyuh_workflow_engine** for GTP

```dart
// Global Training Plan as a workflow
final gtpWorkflow = WorkflowDefinition(
  id: 'manufacturing_gtp',
  label: 'Manufacturing New Hire GTP',
  
  steps: [
    TaskNode(
      id: 'stage_1',
      label: 'Week 1-2: Safety & Policies',
      courses: ['safety_101', 'gmp_basics', 'policies'],
      duration: Duration(days: 14),
    ),
    TaskNode(
      id: 'stage_1_assessment',
      label: 'Stage 1 Assessment',
      action: 'assessment/take_quiz',
      requires_pass: true,
    ),
    TaskNode(
      id: 'stage_2',
      label: 'Week 3-6: Technical Training',
      courses: ['manufacturing_101', 'quality_control'],
      duration: Duration(days: 28),
    ),
    // ... more stages
  ],
);

// Execution
final instance = WorkflowEngine.start(
  workflow: gtpWorkflow,
  context: {'employee_id': emp_uuid, 'role': 'technician'},
);

// Listen to stage completion
instance.on('stage_completed', (event) {
  final stageName = event['stage_name'];
  print('$stageName completed!');
  
  // Notify employee of next steps
  notificationService.send(
    to: empUuid,
    title: 'Ready for next training stage',
    body: 'You have completed Stage 1. Continue to Stage 2.',
  );
});
```

### 2. **vyuh_entity_system_ui** for Training UI

```dart
// Auto-generate training list UI from entity definition
final trainingAssignmentEntity = EntityDefinition(
  id: 'training_assignment',
  label: 'Training Assignment',
  displayProperties: [
    'course_name',
    'assignment_type',
    'due_date',
    'status',
  ],
  features: [
    'list_view',
    'detail_view',
    'filter',
    'search',
  ],
);

// Automatically generates:
// - List screen with filters
// - Detail screen
// - Edit screen
// - Search functionality
```

### 3. **vyuh_rule_engine** for Eligibility

```dart
// Can employee take this course?
final trainingEligibilityRule = Rule(
  id: 'training_eligibility',
  name: 'Employee Training Eligibility',
  conditions: [
    'employee.employment_status == "active"',
    'employee.induction_completed == true',
    'prerequisite_training.status == "completed" OR prerequisite_waived',
    'employee_competency_level < course.required_level OR course.is_refresher',
    'days_since_last_training > course.frequency_interval',
  ],
  action: 'allow_training_assignment',
  otherwise: 'deny_with_reason',
);

// Evaluate
final isEligible = ruleEngine.evaluate(
  rule: trainingEligibilityRule,
  context: {
    'employee': employeeData,
    'course': courseData,
    'prerequisite_training': prereqTrainingData,
    'employee_competency_level': 2,
  },
);

if (!isEligible) {
  print('Ineligible: ${isEligible.reason}');
  // "Ineligible: Must complete prerequisite 'GMP Basics' first"
}
```

---

## Compliance & Audit

### 21 CFR Part 11 Compliance

**Attendance Records Immutable:**
```sql
-- Insert-only table (no updates, no deletes)
CREATE POLICY attendance_immutable ON attendance
    AS (operation = DELETE OR operation = UPDATE)
    USING (FALSE);

-- Corrections require new record
-- Original record: DELETE attempt (rejected)
-- New record: attendance_correction table with full audit
```

**Audit Trail:**
```sql
INSERT INTO audit_trail (
    entity_type, entity_id, action, changed_by_id,
    old_values, new_values, ip_address, timestamp
) VALUES (
    'attendance', attendance_id, 'check_in',
    employee_id, NULL,
    jsonb_build_object(
        'session_id', session_id,
        'check_in_time', NOW(),
        'check_in_method', 'qr_code'
    ),
    get_client_ip(),
    NOW()
);
```

### Training Records Retention

```sql
-- Per 21 CFR Part 11 § 11.10 (a)
-- Training records must be retained for regulatory period
-- Typically 6 years for pharma

-- Policy: No deletion of completed training records
-- Archive only (mark as archived, still queryable)
CREATE POLICY training_retention ON training_assignments
    AS (operation = DELETE)
    USING (
        -- Only allow delete if within first 24 hours
        -- and not yet marked as completed
        EXTRACT(epoch FROM (NOW() - created_at))::INTEGER < 86400
        AND status NOT IN ('completed', 'passed', 'failed')
    );
```

---

## Implementation Checklist

### Phase 1: Schema & Data Model (Weeks 1-2)

- [ ] Create Supabase tables
  - [ ] training_schedules
  - [ ] training_sessions
  - [ ] training_assignments
  - [ ] attendance
  - [ ] self_learning_assignments
  - [ ] ojt_assignments
  - [ ] induction_plans
- [ ] Create audit tables & triggers
- [ ] Set up RLS policies

### Phase 2: API Endpoints (Weeks 3-4)

- [ ] Schedule management (CRUD, assign, enroll)
- [ ] Session management (create, update status)
- [ ] Attendance endpoints (check-in, check-out, report)
- [ ] Self-learning endpoints (assign, progress, completion)
- [ ] OJT endpoints (sign-off, progress)
- [ ] Dashboard endpoints (employee, manager, trainer views)

### Phase 3: Real-Time Features (Week 5)

- [ ] Implement Realtime subscriptions (attendance, progress)
- [ ] Build live dashboards (trainer, manager views)
- [ ] Notifications (assignments, reminders, completions)

### Phase 4: Flutter UI (Weeks 6-7)

- [ ] Employee dashboard
- [ ] Session check-in UI (iPad/mobile)
- [ ] Self-learning progress viewer
- [ ] OJT tracking UI
- [ ] Trainer/Manager dashboards

### Phase 5: Offline & Sync (Week 8)

- [ ] Offline attendance storage (Hive)
- [ ] Background sync service
- [ ] Conflict resolution (offline vs. server)

### Phase 6: Testing & Compliance (Week 9)

- [ ] Unit tests (business logic, rules)
- [ ] Integration tests (end-to-end flows)
- [ ] 21 CFR Part 11 compliance audit
- [ ] Load testing (1000+ concurrent users, check-ins)
- [ ] Performance testing (dashboard load times, Realtime latency)

---

## Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Check-in time (p95) | < 10 seconds | — |
| Dashboard load (p95) | < 2 seconds | — |
| Realtime update latency | < 1 second | — |
| Offline sync (p95) | < 5 seconds | — |
| Attendance accuracy | > 99.9% | — |
| Training compliance SLA | > 95% | — |

---

## References

- Learn IQ by Caliber: https://www.caliberclearpoint.com/products/learn-iq
- WHO GMP Guidelines: https://www.who.int/publications/m/item/who-technical-report-series-no-1025-2024
- GAMP 5 Guidelines: https://www.ispe.org/standards/gamp
- Vyuh Framework: https://pub.vyuh.tech
- Supabase Realtime: https://supabase.com/docs/guides/realtime

---

**Document Author:** Training Operations Team  
**Last Updated:** 2026-04-23  
**Next Review:** 2026-05-23
