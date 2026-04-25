# CERTIFY Module — Assessment & Certification
**PharmaLearn LMS — Detailed Implementation Guide**

> **Version:** 1.0  
> **Date:** 2026-04-23  
> **Module Owner:** Assessment & Compliance Team  
> **Status:** Production Planning  
> **Compliance:** 21 CFR Part 11, GAMP 5, ISO 17024  
> **Dependencies:** CREATE module (assessments), TRAIN module (training completion), ACCESS module (e-signatures)

---

## Table of Contents

1. [Module Overview](#module-overview)
2. [Core Concepts](#core-concepts)
3. [Data Model & Supabase Schema](#data-model--supabase-schema)
4. [API Architecture](#api-architecture)
5. [Assessment Engine](#assessment-engine)
6. [Grading & Scoring](#grading--scoring)
7. [Certificate Generation](#certificate-generation)
8. [Real-World Reference: Veeva Vault Compliance](#real-world-reference-veeva-vault-compliance)
9. [Vyuh Framework Integration](#vyuh-framework-integration)
10. [Compliance & Audit](#compliance--audit)
11. [Implementation Checklist](#implementation-checklist)

---

## Module Overview

### Purpose

The **CERTIFY** module manages the complete assessment lifecycle and certification process:
- **Assessment Creation**: Question banks, question papers, assessments
- **Test Execution**: Multiple-choice, short-answer, essay questions
- **Auto-Grading**: Immediate results for objective questions
- **Manual Grading**: Supervisor/manager review for subjective answers
- **Remedial Training**: Automatic reassignment for failed candidates
- **Certificate Generation**: Digital certificates with e-signatures
- **Expiry Tracking**: Compliance alerts for expiring certificates
- **Competency Mapping**: Track skill levels post-assessment

### Key Features

- **Question Banks**: Organized by subject, difficulty level, reusable
- **Assessment Types**: Pre-assessment, post-training, certification, competency evaluation
- **Question Types**: MCQ, true/false, short-answer, essay, matching, scenario
- **Adaptive Testing**: Question selection based on difficulty/performance
- **Proctoring**: Monitor suspicious activity (copy-paste, window switches)
- **Audit Trail**: Every click, keystroke, time spent logged
- **Instant Feedback**: Show correct answers and explanations
- **Certificate Templates**: Customizable designs with signatures

### Success Metrics

| Metric | Target | Rationale |
|--------|--------|-----------|
| Assessment load time | < 2 seconds | First question appears fast |
| Question response time (p95) | < 100ms | Smooth interaction |
| Auto-grading | < 1 second | Instant results |
| Certificate generation | < 5 seconds | Available immediately after pass |
| Remedial assignment | < 1 minute | Auto-trigger for failed employees |
| Audit trail completeness | 100% | Every action recorded |

---

## Core Concepts

### 1. Assessment Types

```
┌──────────────────────────────────────────────────────────┐
│              ASSESSMENT TYPES & WORKFLOWS                 │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Type 1: PRE-ASSESSMENT (Baseline)                       │
│  ├─ Before training begins                             │
│  ├─ No pass/fail (informational)                        │
│  ├─ Identifies knowledge gaps                           │
│  ├─ Customizes training path                            │
│  └─ Not included in compliance tracking                 │
│                                                          │
│  Type 2: POST-TRAINING (Certification)                  │
│  ├─ After training completion                          │
│  ├─ Pass/fail decision                                 │
│  ├─ Threshold: ≥70% correct                            │
│  ├─ Max attempts: 3                                    │
│  ├─ Certificate issued on pass                         │
│  └─ Included in compliance tracking                    │
│                                                          │
│  Type 3: COMPETENCY EVALUATION                          │
│  ├─ Practical demonstration                            │
│  ├─ Multi-rater (manager + peer)                      │
│  ├─ Rubric-based scoring                              │
│  ├─ Example: "Can operate lathe safely?"              │
│  └─ Certificate: "Competency Level 3"                 │
│                                                          │
│  Type 4: REMEDIAL (Re-certification)                    │
│  ├─ For employees who failed post-training            │
│  ├─ Additional training content + re-test             │
│  ├─ Lower threshold: ≥60% correct                     │
│  ├─ Max attempts: 2                                   │
│  └─ Lighter grading (shows effort)                    │
│                                                          │
│  Type 5: PERIODIC RE-CERTIFICATION                      │
│  ├─ Annual/bi-annual refresher exam                   │
│  ├─ Maintain competency proof                         │
│  ├─ Typically same difficulty as original             │
│  ├─ Certificate renewal issued on pass                │
│  └─ Compliance requirement                            │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### 2. Question Types

```
┌─ Multiple Choice (MCQ) ─────────────────────┐
│                                            │
│ Q: What does GMP stand for?                │
│                                            │
│ ○ Good Manufacturing Practices   [CORRECT]│
│ ○ General Management Procedures            │
│ ○ General Manufacturing Protocol           │
│ ○ Global Medical Practice                  │
│                                            │
│ Score: 1 point (auto-graded)              │
└────────────────────────────────────────────┘

┌─ True/False ───────────────────────────────┐
│                                            │
│ Q: Cleanrooms require positive pressure.   │
│                                            │
│ ◉ True                  [CORRECT]         │
│ ○ False                                    │
│                                            │
│ Score: 1 point (auto-graded)              │
└────────────────────────────────────────────┘

┌─ Short Answer ─────────────────────────────┐
│                                            │
│ Q: Name 3 key elements of GMP.             │
│                                            │
│ [_____________________]                   │
│                                            │
│ Acceptable answers:                        │
│ • "Quality culture, procedures, training" │
│ • "People, processes, documentation"      │
│                                            │
│ Score: 3 points (manual graded)           │
│ Grade: "Partially correct (1.5 points)"   │
└────────────────────────────────────────────┘

┌─ Essay ────────────────────────────────────┐
│                                            │
│ Q: Describe the document control process.  │
│                                            │
│ [_____________________]                   │
│ [_____________________]                   │
│ [_____________________]                   │
│ [_____________________]                   │
│                                            │
│ Score: 10 points (manual graded)          │
│ Grader: Quality Manager                    │
│ Comments: "Excellent! Covered versioning, │
│  approval, archival correctly."            │
│ Grade: 9/10                                │
└────────────────────────────────────────────┘

┌─ Scenario ─────────────────────────────────┐
│                                            │
│ Scenario: A cleaning agent spill occurs   │
│ in the sterile zone. What do you do?      │
│                                            │
│ Step 1: [_____________________] (Correct) │
│ Step 2: [_____________________] (Check!)  │
│ Step 3: [_____________________] (Correct) │
│                                            │
│ Score: 5 points (auto-graded with hints)  │
└────────────────────────────────────────────┘
```

### 3. Assessment Lifecycle

```
┌──────────────────┐
│  DRAFT           │ (Being created, not yet available)
└────────┬─────────┘
         │ Ready for testing
         ▼
┌──────────────────┐
│  PUBLISHED       │ (Available for employees to take)
└────────┬─────────┘
         │ Assigned to employees
         ├─────────────────────────────────┐
         │                                 │
    Attempt 1                          (Can retry)
         │ Submit answers
         ├─────────────────────────────────┤
         │                                 │
    Result: PASSED                    Result: FAILED
         │                                 │
         ▼                                 ▼
    ┌─────────────┐              ┌──────────────────┐
    │ Certificate │              │ Assign Remedial  │
    │  Issued     │              │ Training         │
    └─────────────┘              └────────┬─────────┘
                                          │
                                          ▼
                                     ┌──────────────────┐
                                     │ Remedial Training│
                                     │ + Re-test        │
                                     └────────┬─────────┘
                                              │
                                              ▼
                                         Attempt 2
                                              │
                                         (Pass/Fail)
```

### 4. Grading Model

```
Manual Grading:
├─ Rubric-based assessment
│  ├─ Criteria 1: Accuracy (0-5 points)
│  ├─ Criteria 2: Completeness (0-3 points)
│  └─ Criteria 3: Presentation (0-2 points)
│
├─ Grader workflow
│  ├─ View question + answer
│  ├─ Apply rubric
│  ├─ Add comments
│  └─ Assign score
│
└─ Grade moderation
   ├─ Second grader reviews 10% of submissions
   ├─ If discrepancy > 5%: Resolve disagreement
   └─ Final grade approved by moderator

Auto-Grading:
├─ MCQ, True/False, Matching
├─ Pattern matching for short answers
│  └─ Fuzzy match against answer bank (85% threshold)
├─ Instant feedback
└─ No manual intervention needed
```

---

## Data Model & Supabase Schema

### Core Tables

#### 1. **question_banks** — Question repository

```sql
CREATE TABLE IF NOT EXISTS question_banks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    -- Metadata
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    
    -- Organization
    subject_id UUID REFERENCES subjects(id),
    category TEXT,  -- 'gmp', 'quality', 'safety'
    
    -- Statistics
    total_questions INTEGER DEFAULT 0,
    questions_by_difficulty JSONB,  -- {"easy": 20, "medium": 15, "hard": 5}
    
    -- Management
    created_by UUID REFERENCES employees(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX idx_qbanks_org ON question_banks(organization_id);
CREATE INDEX idx_qbanks_subject ON question_banks(subject_id);
```

#### 2. **questions** — Individual questions

```sql
CREATE TABLE IF NOT EXISTS questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_bank_id UUID NOT NULL REFERENCES question_banks(id),
    
    -- Question content
    question_text TEXT NOT NULL,
    question_type question_type,  -- 'mcq', 'true_false', 'short_answer', 'essay'
    difficulty_level difficulty_level,  -- 'easy', 'medium', 'hard'
    
    -- Difficulty score (used for adaptive testing)
    discrimination_index NUMERIC(3,2),  -- 0.00 to 1.00
    difficulty_index NUMERIC(3,2),      -- 0.00 to 1.00
    
    -- MCQ options
    options JSONB,  -- [
                     --   {"id": "opt_1", "text": "Answer 1"},
                     --   {"id": "opt_2", "text": "Answer 2"}
                     -- ]
    correct_answer_id TEXT,  -- Reference to option
    
    -- For non-MCQ questions
    acceptable_answers TEXT[],  -- Array of acceptable answers
    expected_answer TEXT,       -- Primary expected answer
    answer_explanation TEXT,
    
    -- Scoring
    max_points INTEGER DEFAULT 1,
    
    -- Metadata
    tags TEXT[],  -- ['document-control', 'approval', 'version']
    version INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID
);

CREATE INDEX idx_questions_bank ON questions(question_bank_id);
CREATE INDEX idx_questions_difficulty ON questions(difficulty_level);
CREATE INDEX idx_questions_type ON questions(question_type);
```

#### 3. **question_papers** — Test composition

```sql
CREATE TABLE IF NOT EXISTS question_papers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    course_id UUID REFERENCES courses(id),
    
    -- Paper definition
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    
    -- Question composition
    questions_json JSONB,  -- Ordered list of question IDs
    total_questions INTEGER,
    total_marks NUMERIC(6,2),
    
    -- Settings
    pass_mark NUMERIC(5,2) DEFAULT 70.00,
    max_attempts INTEGER DEFAULT 3,
    max_duration_minutes INTEGER,  -- Time limit (e.g., 60 min)
    shuffle_questions BOOLEAN DEFAULT TRUE,
    show_answers_after BOOLEAN DEFAULT TRUE,
    show_feedback BOOLEAN DEFAULT TRUE,
    
    -- Question distribution
    -- Example: {"easy": 5, "medium": 4, "hard": 1}
    question_distribution JSONB,
    
    -- Auto-grading rules
    use_auto_grading BOOLEAN DEFAULT TRUE,
    manual_grading_required_for TEXT[],  -- ['essay', 'short_answer']
    
    -- Status
    status workflow_state DEFAULT 'draft',
    published_at TIMESTAMPTZ,
    
    created_by UUID REFERENCES employees(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX idx_papers_org ON question_papers(organization_id);
CREATE INDEX idx_papers_course ON question_papers(course_id);
```

#### 4. **assessment_attempts** — Test sessions

```sql
CREATE TABLE IF NOT EXISTS assessment_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_paper_id UUID NOT NULL REFERENCES question_papers(id),
    employee_id UUID NOT NULL REFERENCES employees(id),
    
    -- Attempt details
    attempt_number INTEGER NOT NULL DEFAULT 1,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    submitted_at TIMESTAMPTZ,
    time_taken_seconds INTEGER,
    
    -- Status
    status assessment_status,  -- 'in_progress', 'submitted', 'in_review', 'graded'
    is_passed BOOLEAN,
    
    -- Scoring
    total_questions INTEGER NOT NULL,
    attempted_questions INTEGER DEFAULT 0,
    skipped_questions INTEGER DEFAULT 0,
    correct_answers INTEGER DEFAULT 0,
    total_marks NUMERIC(6,2) NOT NULL,
    obtained_marks NUMERIC(6,2) DEFAULT 0,
    percentage NUMERIC(5,2) DEFAULT 0,
    
    -- Audit (21 CFR Part 11)
    ip_address INET,
    user_agent TEXT,
    device_id TEXT,
    proctoring_alerts JSONB,  -- [{alert: "copy_detected", time: "...", action: "warned"}]
    
    -- Grading
    graded_by UUID REFERENCES employees(id),
    graded_at TIMESTAMPTZ,
    grading_comments TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(question_paper_id, employee_id, attempt_number)
);

CREATE INDEX idx_attempts_paper ON assessment_attempts(question_paper_id);
CREATE INDEX idx_attempts_employee ON assessment_attempts(employee_id);
CREATE INDEX idx_attempts_status ON assessment_attempts(status);
```

#### 5. **assessment_responses** — Individual answers

```sql
CREATE TABLE IF NOT EXISTS assessment_responses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attempt_id UUID NOT NULL REFERENCES assessment_attempts(id),
    question_id UUID NOT NULL REFERENCES questions(id),
    
    -- Question context
    question_number INTEGER NOT NULL,
    question_text TEXT,
    question_type question_type,
    
    -- Answer data
    response_data JSONB,  -- {"selected_option": "opt_1"} or {"text": "answer"}
    is_answered BOOLEAN DEFAULT FALSE,
    is_marked_for_review BOOLEAN DEFAULT FALSE,
    
    -- Timing
    time_spent_seconds INTEGER DEFAULT 0,
    started_at TIMESTAMPTZ,
    answered_at TIMESTAMPTZ,
    
    -- Grading
    is_correct BOOLEAN,
    marks_obtained NUMERIC(5,2) DEFAULT 0,
    auto_graded BOOLEAN DEFAULT TRUE,
    
    -- If manual grading needed
    graded_by UUID REFERENCES employees(id),
    graded_at TIMESTAMPTZ,
    grading_comments TEXT,
    grader_feedback TEXT,
    
    -- Audit
    modification_count INTEGER DEFAULT 0,  -- How many times changed
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(attempt_id, question_id)
);

CREATE INDEX idx_responses_attempt ON assessment_responses(attempt_id);
CREATE INDEX idx_responses_question ON assessment_responses(question_id);
```

#### 6. **certificates** — Digital certificates

```sql
CREATE TABLE IF NOT EXISTS certificates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    course_id UUID NOT NULL REFERENCES courses(id),
    question_paper_id UUID REFERENCES question_papers(id),
    attempt_id UUID NOT NULL REFERENCES assessment_attempts(id),
    
    -- Certificate details
    certificate_number TEXT UNIQUE NOT NULL,  -- Unique identifier
    issue_date TIMESTAMPTZ NOT NULL,
    expiry_date DATE,  -- NULL = no expiry
    
    -- Achievement
    marks_obtained NUMERIC(6,2),
    total_marks NUMERIC(6,2),
    percentage_score NUMERIC(5,2),
    grade CHAR(1),  -- 'A', 'B', 'C', 'Pass', 'Fail'
    
    -- Certificate
    certificate_url TEXT,  -- S3 path to PDF
    file_hash TEXT,  -- SHA-256 for integrity
    
    -- Verification
    verification_code TEXT UNIQUE,  -- QR code content
    verification_url TEXT,  -- Public verification link
    
    -- E-signature (21 CFR Part 11)
    signed_by_id UUID REFERENCES employees(id),
    signed_at TIMESTAMPTZ,
    signature_data JSONB,  -- Certificate + signature
    
    -- Status
    status certificate_status,  -- 'issued', 'revoked', 'expired'
    revocation_reason TEXT,
    revoked_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID
);

CREATE INDEX idx_certs_employee ON certificates(employee_id);
CREATE INDEX idx_certs_course ON certificates(course_id);
CREATE INDEX idx_certs_expiry ON certificates(expiry_date);
CREATE UNIQUE INDEX idx_certs_verification ON certificates(verification_code);
```

#### 7. **remedial_trainings** — Auto-assignment for failed employees

```sql
CREATE TABLE IF NOT EXISTS remedial_trainings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    course_id UUID NOT NULL REFERENCES courses(id),
    failed_attempt_id UUID NOT NULL REFERENCES assessment_attempts(id),
    
    -- Remedial assignment
    assigned_on TIMESTAMPTZ DEFAULT NOW(),
    assigned_by UUID REFERENCES employees(id),
    
    -- Remedial details
    remedial_course_id UUID REFERENCES courses(id),  -- Different course? Or same with additional materials
    remedial_due_date DATE NOT NULL,
    
    -- Additional resources
    remedial_materials JSONB,  -- Documents, videos specifically for remedial
    
    -- Re-attempt
    reassessment_question_paper_id UUID REFERENCES question_papers(id),
    reassessment_attempted BOOLEAN DEFAULT FALSE,
    reassessment_attempt_id UUID REFERENCES assessment_attempts(id),
    
    -- Result
    final_status remedial_status,  -- 'assigned', 'in_progress', 'passed', 'failed'
    completed_on TIMESTAMPTZ,
    
    -- Audit
    notes TEXT,  -- Why did they fail? What to improve?
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_remedial_employee ON remedial_trainings(employee_id);
CREATE INDEX idx_remedial_status ON remedial_trainings(final_status);
```

#### 8. **certificate_templates** — Design templates (from CREATE module)

```sql
-- Reused from CREATE module
-- Includes certificate layout, placeholders, QR code support
-- See architecture_onpremise.md for details
```

---

## API Architecture

### 1. Create Question

**Endpoint:** `POST /v1/questions`

**Request:**
```json
{
  "question_bank_id": "qbank-uuid",
  "question_text": "What does GMP stand for?",
  "question_type": "mcq",
  "difficulty_level": "easy",
  "options": [
    { "id": "opt_1", "text": "Good Manufacturing Practices" },
    { "id": "opt_2", "text": "General Management Procedures" },
    { "id": "opt_3", "text": "General Manufacturing Protocol" },
    { "id": "opt_4", "text": "Global Medical Practice" }
  ],
  "correct_answer_id": "opt_1",
  "answer_explanation": "GMP stands for Good Manufacturing Practices, a regulatory requirement for pharma.",
  "max_points": 1,
  "tags": ["gmp", "fundamentals"]
}
```

**Response (201 Created):**
```json
{
  "id": "question-uuid",
  "question_text": "What does GMP stand for?",
  "question_type": "mcq",
  "created_at": "2026-04-23T10:00:00Z",
  "_links": {
    "self": { "href": "/v1/questions/question-uuid" },
    "bank": { "href": "/v1/question-banks/qbank-uuid" }
  }
}
```

### 2. Create Question Paper

**Endpoint:** `POST /v1/question-papers`

**Request:**
```json
{
  "course_id": "course-uuid",
  "name": "GMP Fundamentals Assessment",
  "unique_code": "QPAPER-GMP-001",
  
  "questions": [
    { "question_id": "q-uuid-1", "order": 1 },
    { "question_id": "q-uuid-2", "order": 2 },
    { "question_id": "q-uuid-3", "order": 3 }
  ],
  
  "settings": {
    "total_marks": 10,
    "pass_mark": 7,
    "max_attempts": 3,
    "max_duration_minutes": 30,
    "shuffle_questions": true,
    "show_answers_after": true
  }
}
```

**Response (201 Created):**
```json
{
  "id": "qpaper-uuid",
  "name": "GMP Fundamentals Assessment",
  "total_questions": 3,
  "total_marks": 10,
  "pass_mark": 7,
  "status": "draft",
  "_links": {
    "publish": { "href": "/v1/question-papers/qpaper-uuid/publish" }
  }
}
```

### 3. Publish Question Paper

**Endpoint:** `POST /v1/question-papers/{id}/publish`

**Response (200 OK):**
```json
{
  "id": "qpaper-uuid",
  "status": "published",
  "published_at": "2026-04-23T11:00:00Z",
  "message": "Question paper published successfully"
}
```

### 4. Start Assessment

**Endpoint:** `POST /v1/assessments/start`

**Request:**
```json
{
  "question_paper_id": "qpaper-uuid",
  "employee_id": "emp-uuid"
}
```

**Response (201 Created):**
```json
{
  "attempt_id": "attempt-uuid",
  "attempt_number": 1,
  "question_paper": {
    "id": "qpaper-uuid",
    "name": "GMP Fundamentals Assessment",
    "total_questions": 10,
    "total_marks": 20,
    "time_limit_minutes": 60
  },
  "started_at": "2026-04-23T14:00:00Z",
  "expires_at": "2026-04-23T15:00:00Z",
  "questions": [
    {
      "id": "q-uuid-1",
      "question_number": 1,
      "question_text": "What does GMP stand for?",
      "question_type": "mcq",
      "options": [
        { "id": "opt_1", "text": "Good Manufacturing Practices", "order": 1 },
        { "id": "opt_2", "text": "General Management Procedures", "order": 2 }
      ],
      "max_points": 2
    }
  ],
  "_links": {
    "submit_response": { "href": "/v1/assessments/attempt-uuid/response" }
  }
}
```

### 5. Submit Response

**Endpoint:** `POST /v1/assessments/{attempt_id}/response`

**Request:**
```json
{
  "question_id": "q-uuid-1",
  "response_data": {
    "selected_option": "opt_1"
  },
  "time_spent_seconds": 45,
  "marked_for_review": false
}
```

**Response (200 OK):**
```json
{
  "response_id": "response-uuid",
  "question_id": "q-uuid-1",
  "status": "saved",
  "message": "Response saved"
}
```

### 6. Get Assessment Progress

**Endpoint:** `GET /v1/assessments/{attempt_id}/progress`

**Response (200 OK):**
```json
{
  "attempt_id": "attempt-uuid",
  "question_paper": "GMP Fundamentals Assessment",
  "total_questions": 10,
  "progress": {
    "answered": 5,
    "skipped": 2,
    "marked_for_review": 1,
    "remaining": 2
  },
  "time_elapsed_seconds": 720,
  "time_remaining_seconds": 1080,
  "percentage_complete": 50,
  "current_question": 6
}
```

### 7. Submit Assessment

**Endpoint:** `POST /v1/assessments/{attempt_id}/submit`

**Request:**
```json
{
  "confirm": true  // Final submission confirmation
}
```

**Response (200 OK):**
```json
{
  "attempt_id": "attempt-uuid",
  "status": "submitted",
  "submitted_at": "2026-04-23T14:45:00Z",
  "time_taken_seconds": 2700,
  "message": "Assessment submitted successfully. Your responses are being evaluated."
}
```

### 8. Get Assessment Results (Auto-Graded)

**Endpoint:** `GET /v1/assessments/{attempt_id}/results`

**Response (200 OK):**
```json
{
  "attempt_id": "attempt-uuid",
  "attempt_number": 1,
  "employee": {
    "id": "emp-uuid",
    "name": "John Trainer"
  },
  "course": "GMP Fundamentals",
  
  "results": {
    "submitted_at": "2026-04-23T14:45:00Z",
    "status": "graded",
    "total_questions": 10,
    "attempted_questions": 10,
    "correct_answers": 8,
    "total_marks": 20,
    "obtained_marks": 16,
    "percentage": 80,
    "grade": "A"
  },
  
  "pass_status": {
    "is_passed": true,
    "pass_mark": 14,
    "obtained_marks": 16,
    "passed_with": 2,
    "message": "Congratulations! You passed the assessment."
  },
  
  "detailed_responses": [
    {
      "question_number": 1,
      "question_text": "What does GMP stand for?",
      "question_type": "mcq",
      "your_answer": "Good Manufacturing Practices",
      "is_correct": true,
      "marks_obtained": 2,
      "feedback": "Correct!"
    },
    {
      "question_number": 2,
      "question_text": "Name 3 key elements of GMP.",
      "question_type": "short_answer",
      "your_answer": "Quality culture, procedures, training",
      "is_correct": true,
      "marks_obtained": 2,
      "feedback": "Excellent answer covering all key elements."
    }
  ],
  
  "next_steps": [
    {
      "action": "issue_certificate",
      "status": "pending",
      "message": "Your certificate is being generated..."
    }
  ],
  
  "_links": {
    "certificate": { "href": "/v1/certificates/cert-uuid" },
    "detailed_report": { "href": "/v1/assessments/attempt-uuid/detailed-report" }
  }
}
```

### 9. Get Certificate

**Endpoint:** `GET /v1/certificates/{id}`

**Response (200 OK):**
```json
{
  "id": "cert-uuid",
  "certificate_number": "CERT-2026-0001234",
  "employee": {
    "id": "emp-uuid",
    "name": "John Trainer",
    "employee_code": "EMP001"
  },
  "course": "GMP Fundamentals Training",
  
  "achievement": {
    "marks_obtained": 16,
    "total_marks": 20,
    "percentage": 80,
    "grade": "A"
  },
  
  "validity": {
    "issue_date": "2026-04-23",
    "expiry_date": "2027-04-23",  // 1 year validity
    "days_remaining": 365,
    "is_expired": false
  },
  
  "certificate_file": {
    "url": "s3://certificates/cert-uuid.pdf",
    "file_name": "GMP_Fundamentals_Certificate_JohnTrainer.pdf"
  },
  
  "verification": {
    "verification_code": "CERT-2026-0001234-ABC123",
    "verification_url": "https://pharmalearn.com/verify/CERT-2026-0001234-ABC123",
    "qr_code_url": "s3://certificates/qrcodes/cert-uuid.png"
  },
  
  "e_signature": {
    "signed_by": "Quality Manager",
    "signed_at": "2026-04-23T15:00:00Z",
    "signature_valid": true
  },
  
  "download": {
    "pdf_url": "s3://certificates/cert-uuid.pdf",
    "email": "john.trainer@pharmalearn.com"
  }
}
```

### 10. Publish Assessment Results (For Review)

**Endpoint:** `POST /v1/assessments/{attempt_id}/publish-results`

**Request:**
```json
{
  "approve": true,
  "published_by": "approver-uuid",
  "approval_comments": "Results verified and approved"
}
```

**Response (200 OK):**
```json
{
  "attempt_id": "attempt-uuid",
  "status": "results_published",
  "published_at": "2026-04-23T15:30:00Z",
  "message": "Results published and certificate issued"
}
```

### 11. Manage Remedial Training

**Endpoint:** `POST /v1/remedial-trainings`

**Auto-triggered when assessment fails:**
```json
{
  "employee_id": "emp-uuid",
  "failed_attempt_id": "attempt-uuid",
  "remedial_due_date": "2026-05-07",  // 2 weeks to complete
  "notes": "Focus on document control and approval processes"
}
```

**Response (201 Created):**
```json
{
  "id": "remedial-uuid",
  "employee": "John Trainer",
  "course": "GMP Fundamentals - Remedial",
  "assigned_on": "2026-04-23T16:00:00Z",
  "due_date": "2026-05-07",
  "status": "assigned",
  "remedial_materials": [
    {
      "type": "document",
      "title": "Document Control Process (Detailed Guide)",
      "url": "s3://..."
    },
    {
      "type": "video",
      "title": "GMP Approval Workflows",
      "duration_minutes": 15
    }
  ],
  "message": "Remedial training assigned. Complete by May 7 to re-take assessment."
}
```

### 12. Get Compliance Report (Certifications)

**Endpoint:** `GET /v1/compliance/certificates?department_id=dept-uuid&status=expiring`

**Response (200 OK):**
```json
{
  "department": "Manufacturing",
  "report_date": "2026-04-23",
  "total_employees": 45,
  
  "certificate_status": {
    "valid": 38,
    "expiring_soon": 5,  // Expiring within 30 days
    "expired": 2,
    "not_certified": 0
  },
  
  "expiring_certificates": [
    {
      "employee": "John Doe",
      "course": "Annual GMP Training",
      "expiry_date": "2026-05-15",
      "days_remaining": 22,
      "status": "needs_renewal",
      "action_required": "Schedule refresher training"
    },
    {
      "employee": "Jane Smith",
      "course": "Safety Training",
      "expiry_date": "2026-05-02",
      "days_remaining": 9,
      "status": "urgent",
      "action_required": "Immediate refresher required"
    }
  ],
  
  "compliance_score": 93.3,  // (38 + 5) / 45 = valid + expiring soon
  
  "recommendations": [
    "Schedule refresher training for 5 employees with expiring certificates",
    "Immediate action: 2 employees have expired certificates - restrict from work",
    "Plan annual GMP refresher in batches of 10-15 people"
  ]
}
```

---

## Assessment Engine

### Adaptive Testing Algorithm

```dart
// Start with medium difficulty
currentDifficulty = 0.5;  // 0.0 = easy, 1.0 = hard

for (int i = 0; i < totalQuestions; i++) {
  // Select question at current difficulty
  question = selectQuestion(
    difficulty: currentDifficulty,
    usedQuestions: previousQuestions,
  );
  
  // Display question
  answer = waitForUserAnswer();
  
  // Grade response
  isCorrect = gradeAnswer(answer);
  
  // Adjust difficulty for next question
  if (isCorrect) {
    currentDifficulty += 0.1;  // Increase difficulty
    userScore += 1;
  } else {
    currentDifficulty -= 0.05;  // Decrease difficulty
  }
  
  // Cap difficulty
  currentDifficulty = max(0.0, min(1.0, currentDifficulty));
}

// Calculate IRT (Item Response Theory) score
finalScore = calculateIRTScore(
  answeredQuestions: answers,
  difficulty: difficultyLevels,
  discrimination: discriminationIndices,
);
```

### Proctoring Alerts

```dart
// Monitor suspicious activity
class ProctoringEngine {
  void detectAnomalies(AssessmentAttempt attempt) {
    // Flag 1: Copy-paste detected
    if (userAttemptedCopyPaste()) {
      logAlert('copy_paste_detected', attempt.id);
      showWarning('Copying is not allowed');
    }
    
    // Flag 2: Window switch
    if (browserTabSwitched || appMinimized()) {
      logAlert('window_switch_detected', attempt.id);
      showWarning('Please stay on the assessment window');
    }
    
    // Flag 3: Unusual time per question
    if (timePerQuestion < 5 || timePerQuestion > 300) {
      logAlert('unusual_timing', attempt.id, {'time': timePerQuestion});
    }
    
    // Flag 4: Multiple rapid submissions
    if (submissionsPerMinute > 10) {
      logAlert('rapid_submission', attempt.id);
      showWarning('Slow down and think carefully');
    }
    
    // Flag 5: Shared device detected
    if (multipleUserAgents() || multipleIPs()) {
      logAlert('shared_device_detected', attempt.id);
      suggestProctoring();  // Recommend live proctoring
    }
  }
  
  void escalateForReview(String alertType) {
    if (alertType == 'copy_paste' && alertCount > 3) {
      // Escalate to reviewer
      assignForManualReview(attempt.id);
      notifyManager('Assessment flagged for review');
    }
  }
}
```

---

## Grading & Scoring

### Auto-Grading Logic

```sql
-- Auto-grade MCQ questions
UPDATE assessment_responses SET
    is_correct = (response_data->>'selected_option' = correct_answer_id),
    marks_obtained = CASE
        WHEN (response_data->>'selected_option' = correct_answer_id)
        THEN (SELECT max_points FROM questions WHERE id = question_id)
        ELSE 0
    END,
    auto_graded = TRUE,
    graded_at = NOW()
WHERE question_id IN (
    SELECT id FROM questions WHERE question_type = 'mcq'
)
AND attempt_id = $1;
```

### Manual Grading Workflow

```dart
class ManualGradingService {
  Future<void> startManualGrading(String attemptId) async {
    // Get all short-answer/essay responses
    final responsesToGrade = await db.assessmentResponses
        .where((r) => r.attemptId == attemptId)
        .where((r) => ['short_answer', 'essay'].contains(r.questionType))
        .toList();
    
    // Assign to graders (round-robin)
    for (var response in responsesToGrade) {
      final grader = selectNextGrader();  // Round-robin
      
      await notificationService.send(
        to: grader.id,
        title: 'New response to grade',
        body: '${employee.name} submitted response to: "${response.questionText}"',
        actionUrl: '/grading/response/${response.id}',
      );
    }
  }
  
  Future<void> submitGrade(
    String responseId,
    double marks,
    String comments,
  ) async {
    await db.assessmentResponses.update(
      responseId,
      {
        'marks_obtained': marks,
        'grading_comments': comments,
        'graded_by': currentUser.id,
        'graded_at': DateTime.now(),
        'auto_graded': false,
      },
    );
    
    // Check if all responses for attempt are graded
    final attempt = await getAttempt(responseId);
    final pendingResponses = await db.assessmentResponses
        .where((r) => r.attemptId == attempt.id)
        .where((r) => r.gradedAt == null)
        .count();
    
    if (pendingResponses == 0) {
      // All responses graded, calculate final score
      await calculateFinalScore(attempt.id);
    }
  }
}
```

### Grade Moderation

```dart
// Quality check: Second grader reviews random 10% of grades
Future<void> performGradeModeration(String attemptId) async {
  final responses = await db.assessmentResponses
      .where((r) => r.attemptId == attemptId)
      .toList();
  
  final sampleSize = max(1, (responses.length * 0.1).toInt());
  final sample = responses.sample(sampleSize);
  
  for (var response in sample) {
    // Assign to moderator (different from original grader)
    final moderator = selectModeratorDifferentFrom(response.gradedBy);
    
    await notificationService.send(
      to: moderator.id,
      title: 'Grade moderation required',
      body: 'Please review grade for: ${response.questionText}',
      actionUrl: '/moderation/response/${response.id}',
    );
  }
}

// Moderator submits review
Future<void> submitModerationReview(
  String responseId,
  ModerationReview review,
) async {
  // Compare grades
  final discrepancy = (review.marksAssigned - response.marksObtained).abs();
  final threshold = (response.questionMaxPoints * 0.25);  // 25% threshold
  
  if (discrepancy > threshold) {
    // Escalate for resolution
    await db.gradeModeration.insert({
      'response_id': responseId,
      'original_grader': response.gradedBy,
      'moderator': currentUser.id,
      'discrepancy': discrepancy,
      'status': 'needs_resolution',
    });
    
    // Notify both graders
    notifyGraders('Grade discrepancy detected. Please discuss and agree.');
  } else {
    // Approve grade
    response.gradedApproved = true;
  }
}
```

---

## Certificate Generation

### PDF Generation with E-Signature

```dart
Future<String> generateCertificate(
  String certificateTemplateId,
  Certificate cert,
) async {
  // Load template
  final template = await db.certificateTemplates.get(certificateTemplateId);
  
  // Generate PDF from template
  final pdf = PDF();
  final document = await rootBundle.load(template.layoutTemplate);
  
  // Replace placeholders
  final placeholders = {
    'employee_name': cert.employee.name,
    'course_name': cert.course.name,
    'completion_date': cert.issueDate.toDateString(),
    'expiry_date': cert.expiryDate?.toDateString() ?? 'N/A',
    'marks': '${cert.marksObtained} / ${cert.totalMarks}',
    'grade': cert.grade,
    'certificate_number': cert.certificateNumber,
  };
  
  // Add QR code for verification
  final qrCode = generateQRCode(
    data: cert.verificationCode,
    size: 200,
  );
  
  // Add e-signature
  final signatureImage = await renderESignature(
    certificate: cert.signatureData['certificate'],
    employeeId: cert.signedById,
  );
  
  // Create final PDF
  final finalPdf = mergeElements([
    template.layout,
    replacePlaceholders(template.layout, placeholders),
    addElement(qrCode, position: 'bottom_right'),
    addElement(signatureImage, position: 'bottom_center'),
  ]);
  
  // Save to S3
  final fileHash = calculateHash(finalPdf);
  final url = await s3Service.upload(
    bucket: 'certificates',
    key: 'cert_${cert.id}.pdf',
    data: finalPdf,
  );
  
  // Update certificate record
  await db.certificates.update(cert.id, {
    'certificate_url': url,
    'file_hash': fileHash,
  });
  
  return url;
}
```

### E-Signature on Certificate

```dart
Future<void> signCertificate(
  String certificateId,
  String employeePassword,
) async {
  final cert = await db.certificates.get(certificateId);
  
  // Load employee's e-signature certificate
  final eSignCert = await db.eSignatureCertificates
      .where((c) => c.employeeId == cert.signedById)
      .where((c) => c.isActive)
      .first;
  
  // Verify certificate validity
  if (eSignCert.validUntil.isBefore(DateTime.now())) {
    throw Exception('E-signature certificate expired');
  }
  
  // Decrypt private key
  final privateKey = decryptPrivateKey(
    eSignCert.privateKeyEncrypted,
    employeePassword,
  );
  
  // Sign PDF
  final pdfBytes = await downloadPDF(cert.certificateUrl);
  final signature = _signWithPrivateKey(
    pdfBytes,
    privateKey,
    'SHA256withRSA',
  );
  
  // Store signature record
  await db.eSignatures.insert({
    'signed_by_id': cert.signedById,
    'document_id': null,  // Not a document
    'certificate_id': certificateId,
    'certificate_thumbprint': eSignCert.certificateThumbprint,
    'signature_value': signature,
    'signed_timestamp': DateTime.now(),
    'signing_reason': 'Certificate issuance: ${cert.employeeId}',
    'signed_document_hash': calculateHash(pdfBytes),
    'ip_address': getClientIp(),
  });
  
  // Update certificate status
  await db.certificates.update(certificateId, {
    'signed_by_id': cert.signedById,
    'signed_at': DateTime.now(),
    'status': 'issued',
  });
}
```

---

## Real-World Reference: Veeva Vault Compliance

### Veeva's Competency Model (Adapted)

```
Veeva tracks competency progression:
├─ Not Demonstrated (0)
├─ Developing (1)
├─ Proficient (2)
└─ Expert (3)

Our Implementation:
├─ Pre-assessment → Baseline level
├─ Training → Move to next level
├─ Post-assessment:
│  ├─ Failed → Remedial → Retry
│  ├─ Passed → Competency validated
│  └─ High score → Expert level
└─ Re-certification → Maintain level
```

### Veeva's Compliance Dashboard

```
We adopt Veeva's reporting structure:
├─ Training Due List
├─ Overdue Trainings (escalated)
├─ Certificate Expiry Alerts
├─ Compliance Gap Report
└─ Audit Trail (every action logged)
```

---

## Vyuh Framework Integration

### 1. **vyuh_form_editor** for Assessment UI

```dart
// Dynamic assessment form builder
final assessmentForm = FormDefinition(
  id: 'gmp_assessment_form',
  title: 'GMP Fundamentals Assessment',
  fields: [
    TextField(
      id: 'q1',
      label: 'Q1: What does GMP stand for?',
      type: 'radio_group',
      options: [
        {'value': 'opt_1', 'label': 'Good Manufacturing Practices'},
        {'value': 'opt_2', 'label': 'General Management Procedures'},
      ],
      required: true,
      points: 2,
      validation: RequiredValidator(),
    ),
    TextField(
      id: 'q2',
      label: 'Q2: Name 3 key elements of GMP',
      type: 'text_area',
      required: true,
      points: 3,
      validation: TextLengthValidator(minLength: 20),
    ),
  ],
);

// Auto-generates Flutter UI with:
// - Question rendering
// - Answer collection
// - Validation
// - Progress tracking
// - Timer (if applicable)
```

### 2. **vyuh_rule_engine** for Remedial Logic

```dart
// Automatic remedial assignment rule
final remedialAssignmentRule = Rule(
  id: 'remedial_assignment',
  name: 'Auto-assign Remedial Training',
  conditions: [
    'assessment.is_passed == false',
    'assessment.attempt_number < max_attempts',
    'course.remedial_training_available == true',
  ],
  action: 'assign_remedial_training',
  otherwise: 'no_action',
  priority: 10,  // High priority
);

// Evaluate
ruleEngine.evaluate(
  rule: remedialAssignmentRule,
  context: {
    'assessment': assessmentResult,
    'course': courseData,
    'max_attempts': 3,
  },
  onAction: (action) {
    if (action == 'assign_remedial_training') {
      // Auto-create remedial training assignment
      remedialService.assignRemedialTraining(
        employeeId: employee.id,
        courseId: course.id,
        failedAttemptId: attempt.id,
      );
    }
  },
);
```

---

## Compliance & Audit

### 21 CFR Part 11 Compliance

**Every Assessment Action Logged:**

```sql
-- Immutable audit trail
INSERT INTO audit_trail (
    entity_type, entity_id, action, changed_by_id,
    old_values, new_values, ip_address, timestamp
) VALUES (
    'assessment_attempt', attempt_id, 'started', employee_id,
    NULL,
    jsonb_build_object(
        'question_paper_id', question_paper_id,
        'started_at', NOW(),
        'ip_address', client_ip
    ),
    client_ip,
    NOW()
);

-- Each response logged
INSERT INTO audit_trail VALUES (
    'assessment_response', response_id, 'submitted', employee_id,
    NULL,
    jsonb_build_object(
        'question_id', question_id,
        'response_data', response_data,
        'submitted_at', NOW()
    ),
    client_ip,
    NOW()
);

-- Grading logged
INSERT INTO audit_trail VALUES (
    'assessment_response', response_id, 'graded', grader_id,
    jsonb_build_object('marks_obtained', old_marks),
    jsonb_build_object('marks_obtained', new_marks),
    grader_ip,
    NOW()
);
```

**Certificate E-Signature (§11.200):**

```sql
-- Certificate signed and timestamp verified
INSERT INTO e_signatures (
    signed_by_id, certificate_id, certificate_thumbprint,
    signature_value, signed_timestamp, signing_reason,
    signed_document_hash, ip_address
) VALUES (
    manager_id, cert_id, cert_thumbprint,
    signature_bytes, NOW(), 'Certificate issuance for training completion',
    sha256(certificate_pdf), client_ip
);
```

---

## Implementation Checklist

### Phase 1: Question Banks & Papers (Weeks 1-2)

- [ ] Create question, question_bank tables
- [ ] Implement question CRUD API
- [ ] Create question_paper table
- [ ] Implement paper composition (add/remove/reorder questions)
- [ ] Create publish workflow

### Phase 2: Assessment Execution (Weeks 3-4)

- [ ] Implement attempt start/end logic
- [ ] Build response recording (POST endpoint)
- [ ] Implement auto-grading engine
- [ ] Build manual grading workflow
- [ ] Grade moderation process

### Phase 3: Results & Certificates (Week 5)

- [ ] Calculate final scores (auto + manual)
- [ ] Generate certificates (PDF)
- [ ] Implement e-signature on certificates
- [ ] Implement verification links & QR codes
- [ ] Setup certificate delivery (email, download)

### Phase 4: Remedial Training (Week 6)

- [ ] Auto-assign remedial on fail
- [ ] Create remedial course variations
- [ ] Track remedial completion
- [ ] Re-attempt logic

### Phase 5: Flutter UI (Weeks 7-8)

- [ ] Assessment player interface
- [ ] Timer widget
- [ ] Progress indicator
- [ ] Results display screen
- [ ] Certificate viewer (PDF)

### Phase 6: Testing & Compliance (Week 9)

- [ ] Unit tests (grading, scoring)
- [ ] Integration tests (attempt → results → certificate)
- [ ] 21 CFR Part 11 audit trail validation
- [ ] Load testing (1000+ concurrent attempts)
- [ ] Performance testing (question load, result calculation)

---

## Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Assessment load time | < 2 sec | — |
| Question response time (p95) | < 100ms | — |
| Auto-grading speed | < 1 sec | — |
| Certificate generation | < 5 sec | — |
| Remedial auto-assignment | < 1 min | — |
| Audit trail completeness | 100% | — |

---

## References

- ISO 17024 Competency Validation: https://www.iso.org/standard/63667.html
- 21 CFR Part 11: https://www.ecfr.gov/ead/title-21/chapter-I/part-11
- GAMP 5 Assessment Strategy: https://www.ispe.org/standards/gamp
- Veeva Vault Compliance: https://www.veeva.com/
- Vyuh Framework: https://pub.vyuh.tech

---

**Document Author:** Assessment & Compliance Team  
**Last Updated:** 2026-04-23  
**Next Review:** 2026-05-23
