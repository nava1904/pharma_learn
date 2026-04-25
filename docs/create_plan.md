# CREATE Module — Document & Course Authoring
**PharmaLearn LMS — Detailed Implementation Guide**

> **Version:** 1.0  
> **Date:** 2026-04-23  
> **Module Owner:** Content Management Team  
> **Status:** Production Planning  
> **Dependencies:** ACCESS module (authentication), CERTIFY module (assessment linking)

---

## Table of Contents

1. [Module Overview](#module-overview)
2. [Core Concepts](#core-concepts)
3. [Data Model & Supabase Schema](#data-model--supabase-schema)
4. [API Architecture](#api-architecture)
5. [Business Logic & Workflows](#business-logic--workflows)
6. [UI/UX Design](#uiux-design)
7. [Real-World Reference: Veeva Vault](#real-world-reference-veeva-vault)
8. [Vyuh Framework Integration](#vyuh-framework-integration)
9. [Compliance & Audit](#compliance--audit)
10. [Implementation Checklist](#implementation-checklist)

---

## Module Overview

### Purpose
The **CREATE** module enables pharma organizations to author, manage, and control documents (SOPs, work instructions, training materials) and courses (structured training programs) with full version control, approval workflows, and regulatory compliance.

### Key Features
- **Document Management**: SOPs, work instructions, reference materials with versioning
- **Course Authoring**: Structured training programs with topics, assessment linking
- **Approval Workflows**: Multi-level approval matrices with e-signatures
- **Version Control**: Full history with change tracking and audit trails
- **Access Control**: Granular document/course access by role and department
- **Certificate Templates**: Design reusable certificate layouts
- **Offline Support**: Local drafts with cloud sync

### Success Metrics
| Metric | Target | Rationale |
|--------|--------|-----------|
| Document creation time | < 5 min | iPad-first UX for busy trainers |
| Course setup time | < 15 min | Template-based quick start |
| Approval SLA | < 24 hours | Regulatory expectation |
| Version retrieval | < 100ms | Critical for compliance |
| Offline draft sync | < 5 sec | Seamless collaborative experience |

---

## Core Concepts

### 1. Document Lifecycle

```
┌─────────────┐
│   DRAFT     │ (Authoring, local edits)
└──────┬──────┘
       │ Submit for review
       ▼
┌─────────────────────┐
│  UNDER_REVIEW       │ (Stakeholder feedback, e-signatures pending)
└──────┬──────────────┘
       │ Approved / Rejected
       ├─────────────────────────┐
       ▼                         ▼
  ┌─────────────┐         ┌──────────────┐
  │  EFFECTIVE  │         │   REJECTED   │ (Return to DRAFT)
  │  (Published)│         └──────────────┘
  └─────────────┘
       │ Superseded by new version
       ▼
  ┌──────────────┐
  │  ARCHIVED    │ (Historical, audit only)
  └──────────────┘
```

**State Transitions:**
- DRAFT → UNDER_REVIEW (Submit action, creator role)
- UNDER_REVIEW → EFFECTIVE (Approval action, approver role)
- UNDER_REVIEW → REJECTED (Reject action, approver role)
- UNDER_REVIEW → DRAFT (Recall action, creator role before approval)
- EFFECTIVE → ARCHIVED (Manual archival or next version effective date reached)

### 2. Course Structure

```
Course
├── Metadata (name, code, type, duration)
├── Topics (ordered list of training units)
│   ├── Topic 1
│   │   ├── Documents (reference materials)
│   │   ├── Content (from TRAIN module: sessions, OJT)
│   │   └── Prerequisites (skills required)
│   ├── Topic 2
│   └── ...
├── Assessment (question paper linked)
├── Certificate Template
└── Access Control (subgroups, roles)
```

### 3. Approval Matrices

```json
{
  "approval_matrix_id": "uuid",
  "course_id": "uuid",
  "levels": [
    {
      "level": 1,
      "title": "Department Head Review",
      "approvers_role_id": "role_depthead",
      "requires_all": false,
      "requires_count": 1,
      "timeline_hours": 24
    },
    {
      "level": 2,
      "title": "Quality Assurance",
      "approvers_role_id": "role_qa",
      "requires_all": true,
      "timeline_hours": 48
    }
  ],
  "escalation_if_overdue": "notify_manager"
}
```

### 4. Version Control Strategy

**Document Versioning:**
- **Major version** (1.0, 2.0): Significant content changes, new workflows
- **Minor version** (1.1, 1.2): Corrections, clarifications
- **Revision number**: Auto-incremented on each approval

**Example:**
- `SOP-MANU-001 v1.0` (initial release)
- `SOP-MANU-001 v1.1` (typo fix, rapid re-release)
- `SOP-MANU-001 v2.0` (new process introduced)

---

## Data Model & Supabase Schema

### Core Tables

#### 1. **documents** — Master document record

```sql
CREATE TABLE documents (
    id UUID PRIMARY KEY,
    organization_id UUID NOT NULL,        -- Which org owns this?
    plant_id UUID,                        -- Facility-specific?
    
    -- Identifiers
    name TEXT NOT NULL,                   -- "SOP-MANUFACTURING-001"
    unique_code TEXT NOT NULL,            -- Unique across org
    version_no TEXT NOT NULL,             -- "1.0", "1.1", "2.0"
    description TEXT,
    document_type document_type,          -- enum: SOP, WI, FORM, REFERENCE
    
    -- Content & Storage
    storage_url TEXT,                     -- S3 path to PDF/Word
    file_name TEXT,
    file_size_bytes BIGINT,
    file_hash TEXT,                       -- SHA-256 for integrity
    mime_type TEXT,                       -- application/pdf
    
    -- Lifecycle
    effective_from DATE,
    effective_until DATE,
    next_review DATE,
    status workflow_state,                -- DRAFT, UNDER_REVIEW, EFFECTIVE, ARCHIVED
    
    -- Ownership & Approval
    department_id UUID,
    owner_id UUID REFERENCES employees,
    approved_at TIMESTAMPTZ,
    approved_by UUID REFERENCES employees,
    
    -- Metadata
    sop_number TEXT,
    revision_no INTEGER,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    created_by UUID
);
```

**Key Indexes:**
```sql
CREATE INDEX idx_documents_org ON documents(organization_id);
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_type ON documents(document_type);
CREATE INDEX idx_documents_plant ON documents(plant_id);
CREATE UNIQUE INDEX idx_documents_code ON documents(organization_id, unique_code);
```

#### 2. **document_versions** — Full version history

```sql
CREATE TABLE document_versions (
    id UUID PRIMARY KEY,
    document_id UUID NOT NULL REFERENCES documents,
    version_no TEXT NOT NULL,             -- "1.0", "1.1", etc.
    storage_url TEXT NOT NULL,            -- S3 path to this version
    file_hash TEXT,                       -- For integrity check
    file_size_bytes BIGINT,
    change_summary TEXT,                  -- "Fixed typos", "New workflow"
    is_current BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    approved_at TIMESTAMPTZ,
    approved_by UUID
);
```

**Purpose:** Immutable audit trail of all document versions. Users can download any historical version.

#### 3. **document_control** — Approval workflow tracking

```sql
CREATE TABLE document_control (
    id UUID PRIMARY KEY,
    document_id UUID NOT NULL REFERENCES documents,
    approval_matrix_id UUID,              -- Which approval workflow?
    current_level INTEGER,                -- Level 1, 2, 3...
    current_status workflow_state,        -- PENDING, APPROVED, REJECTED
    submitted_at TIMESTAMPTZ,
    submitted_by UUID REFERENCES employees,
    
    -- Current approvers
    assigned_to_role_ids UUID[],          -- Roles that can approve
    approver_id UUID REFERENCES employees,
    approved_at TIMESTAMPTZ,
    approval_comments TEXT,
    
    -- Escalation
    escalated BOOLEAN DEFAULT FALSE,
    escalation_reason TEXT,
    escalation_to_manager BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);
```

#### 4. **courses** — Course master record

```sql
CREATE TABLE courses (
    id UUID PRIMARY KEY,
    organization_id UUID NOT NULL,
    plant_id UUID,
    
    -- Course definition
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    course_type course_type,              -- ONE_TIME, PERIODIC, COMPETENCY
    training_types training_type[],       -- ["GMP", "SAFETY"]
    
    -- Configuration
    assessment_required BOOLEAN DEFAULT TRUE,
    pass_mark NUMERIC(5,2) DEFAULT 70.00,
    max_attempts INTEGER DEFAULT 3,
    self_study BOOLEAN DEFAULT FALSE,
    frequency_months INTEGER,             -- For periodic courses
    
    -- Approval
    approval_for_candidature approval_requirement,  -- NOT_REQUIRED, REQUIRED
    approval_group_id UUID REFERENCES groups,
    
    -- Certificate
    certificate_validity_months INTEGER,  -- 12, 24, etc.
    certificate_template_id UUID,         -- Link to certificate design
    
    -- Access
    course_open_for_all BOOLEAN DEFAULT TRUE,
    mandatory_subgroup_selection BOOLEAN,
    
    -- Compliance
    sop_number TEXT,
    effective_date DATE,
    
    -- Display
    thumbnail_url TEXT,
    estimated_duration_minutes INTEGER,
    
    -- Workflow
    status workflow_state DEFAULT 'draft',
    revision_no INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    created_by UUID,
    approved_at TIMESTAMPTZ,
    approved_by UUID
);
```

#### 5. **course_topics** — Course structure

```sql
CREATE TABLE course_topics (
    course_id UUID NOT NULL REFERENCES courses,
    topic_id UUID NOT NULL REFERENCES topics,
    order_index INTEGER NOT NULL,
    is_mandatory BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (course_id, topic_id)
);
```

#### 6. **topics** — Training topics (from TRAIN module)

```sql
CREATE TABLE topics (
    id UUID PRIMARY KEY,
    organization_id UUID NOT NULL,
    subject_id UUID REFERENCES subjects,  -- e.g., "Manufacturing", "Quality"
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    estimated_duration_minutes INTEGER,
    created_at TIMESTAMPTZ
);
```

#### 7. **course_documents** — Links courses to reference documents

```sql
CREATE TABLE course_documents (
    id UUID PRIMARY KEY,
    course_id UUID NOT NULL REFERENCES courses,
    topic_id UUID REFERENCES topics,
    document_id UUID NOT NULL REFERENCES documents,
    version_no TEXT NOT NULL,             -- Lock to specific version
    is_mandatory BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ
);
```

#### 8. **certificate_templates** — Certificate design

```sql
CREATE TABLE certificate_templates (
    id UUID PRIMARY KEY,
    organization_id UUID NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    
    -- Layout
    layout_json JSONB,                    -- Figma-like JSON structure
    logo_urls TEXT[],                     -- Company logos
    certificate_logo_url TEXT,            -- Certificate watermark
    font_family TEXT DEFAULT 'Inter',
    colors JSONB,                         -- Color palette
    
    -- Customization
    include_expiry BOOLEAN DEFAULT TRUE,
    include_qr_code BOOLEAN DEFAULT TRUE,
    include_signatory BOOLEAN DEFAULT TRUE,
    signature_count INTEGER DEFAULT 1,    -- 1 or 2 signatories
    
    status workflow_state DEFAULT 'draft',
    created_at TIMESTAMPTZ,
    created_by UUID
);
```

### Join Tables & Access Control

#### 9. **course_subgroup_access** — Control who can take a course

```sql
CREATE TABLE course_subgroup_access (
    course_id UUID NOT NULL REFERENCES courses,
    subgroup_id UUID NOT NULL REFERENCES subgroups,
    created_at TIMESTAMPTZ,
    PRIMARY KEY (course_id, subgroup_id)
);
```

#### 10. **document_approvals** — Record each approval action (audit trail)

```sql
CREATE TABLE document_approvals (
    id UUID PRIMARY KEY,
    document_id UUID NOT NULL REFERENCES documents,
    approval_level INTEGER,               -- 1, 2, 3...
    approver_id UUID NOT NULL REFERENCES employees,
    approval_status approval_status,      -- APPROVED, REJECTED, RECALLED
    approval_comments TEXT,
    approved_at TIMESTAMPTZ DEFAULT NOW(),
    signature_data JSONB,                 -- E-signature: certificate + hash
    ip_address INET,                      -- For 21 CFR Part 11 §11.300
    timestamp TIMESTAMPTZ DEFAULT NOW()
);
```

---

## API Architecture

### Authentication & Authorization

All endpoints require:
- **Authorization Header**: `Bearer <JWT_TOKEN>` (from ACCESS module)
- **Role Check**: Creator, Approver, or Viewer role
- **Scope Check**: Can user access this org/plant/department?

### Endpoint Design Pattern

```dart
// Follows RESTful + JSONAPI conventions
POST   /v1/documents              // Create new document
GET    /v1/documents              // List documents (paginated)
GET    /v1/documents/{id}         // Get document details
PATCH  /v1/documents/{id}         // Update draft document
DELETE /v1/documents/{id}         // Delete draft document
POST   /v1/documents/{id}/submit  // Submit for approval
POST   /v1/documents/{id}/approve // Approve document
POST   /v1/documents/{id}/reject  // Reject document
GET    /v1/documents/{id}/versions // List all versions
```

### 1. Create Document

**Endpoint:** `POST /v1/documents`

**Request:**
```json
{
  "name": "SOP-MANUFACTURING-001",
  "unique_code": "SOP-MANU-001",
  "description": "Standard Operating Procedure for tablet manufacturing",
  "document_type": "SOP",
  "department_id": "dept-uuid",
  "organization_id": "org-uuid",
  "plant_id": "plant-uuid",
  
  "file": {
    "content": "base64-encoded-pdf",
    "file_name": "SOP-MANU-001.pdf",
    "mime_type": "application/pdf"
  },
  
  "metadata": {
    "sop_number": "SOP/MANU/001",
    "effective_from": "2026-05-01",
    "effective_until": "2027-05-01",
    "next_review": "2026-11-01"
  }
}
```

**Response (201 Created):**
```json
{
  "id": "doc-uuid",
  "name": "SOP-MANUFACTURING-001",
  "unique_code": "SOP-MANU-001",
  "version_no": "1.0",
  "status": "draft",
  "storage_url": "s3://documents/org-uuid/doc-uuid/SOP-MANU-001-v1.0.pdf",
  "file_hash": "sha256:abc123...",
  "created_at": "2026-04-23T10:00:00Z",
  "created_by": "employee-uuid",
  "_links": {
    "self": { "href": "/v1/documents/doc-uuid" },
    "edit": { "href": "/v1/documents/doc-uuid" },
    "submit": { "href": "/v1/documents/doc-uuid/submit" },
    "versions": { "href": "/v1/documents/doc-uuid/versions" }
  }
}
```

**Apple Principles Applied:**
- ✅ Simplicity: Single POST with all metadata
- ✅ Integration: File upload + metadata in one call
- ✅ Attention to Detail: Includes `_links` for discoverable API
- ✅ User Experience: File hash for integrity verification

### 2. List Documents (Paginated)

**Endpoint:** `GET /v1/documents?limit=20&offset=0&status=effective&document_type=SOP`

**Query Parameters:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | int | 20 | Records per page (max 100) |
| `offset` | int | 0 | Pagination offset |
| `status` | enum | — | Filter: DRAFT, UNDER_REVIEW, EFFECTIVE, ARCHIVED |
| `document_type` | enum | — | Filter: SOP, WI, FORM, REFERENCE |
| `department_id` | uuid | — | Filter by department |
| `plant_id` | uuid | — | Filter by facility |
| `search` | string | — | Full-text search on name + code |

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "doc-uuid-1",
      "name": "SOP-MANUFACTURING-001",
      "unique_code": "SOP-MANU-001",
      "version_no": "1.0",
      "status": "effective",
      "document_type": "SOP",
      "effective_from": "2026-05-01",
      "department": {
        "id": "dept-uuid",
        "name": "Manufacturing"
      },
      "owner": {
        "id": "emp-uuid",
        "name": "John Trainer"
      },
      "approved_at": "2026-04-23T14:00:00Z",
      "approved_by": "approver-name",
      "_links": {
        "self": { "href": "/v1/documents/doc-uuid-1" }
      }
    }
  ],
  "meta": {
    "pagination": {
      "total": 156,
      "limit": 20,
      "offset": 0,
      "pages": 8,
      "current_page": 1
    }
  }
}
```

### 3. Submit Document for Approval

**Endpoint:** `POST /v1/documents/{id}/submit`

**Request:**
```json
{
  "submission_comments": "Ready for review. Updated process flows.",
  "approval_matrix_id": "matrix-uuid"
}
```

**Response (200 OK):**
```json
{
  "id": "doc-uuid",
  "status": "under_review",
  "current_approval_level": 1,
  "approval_pending": {
    "level": 1,
    "title": "Department Head Review",
    "assigned_to_role": "role_depthead",
    "approvers": [
      {
        "id": "emp-uuid-1",
        "name": "Manager A",
        "status": "pending"
      }
    ],
    "deadline": "2026-04-24T10:00:00Z",
    "timeline_hours": 24
  },
  "submission_comments": "Ready for review. Updated process flows.",
  "submitted_at": "2026-04-23T15:00:00Z",
  "submitted_by": "creator-name"
}
```

### 4. Approve Document

**Endpoint:** `POST /v1/documents/{id}/approve`

**Request:**
```json
{
  "approval_comments": "Approved. Process flows are correct.",
  "e_signature": {
    "certificate": "-----BEGIN CERTIFICATE-----\nMIIFjDCC...",
    "signature": "base64-signature-data",
    "timestamp": "2026-04-24T09:00:00Z"
  }
}
```

**Response (200 OK):**
```json
{
  "id": "doc-uuid",
  "status": "under_review",
  "current_approval_level": 2,
  "approval_history": [
    {
      "level": 1,
      "title": "Department Head Review",
      "approver": "Manager A",
      "status": "approved",
      "approved_at": "2026-04-24T09:00:00Z",
      "comments": "Approved. Process flows are correct."
    }
  ],
  "next_approval": {
    "level": 2,
    "title": "Quality Assurance",
    "assigned_to_role": "role_qa",
    "deadline": "2026-04-26T09:00:00Z"
  }
}
```

### 5. Get Document Details

**Endpoint:** `GET /v1/documents/{id}`

**Response (200 OK):**
```json
{
  "id": "doc-uuid",
  "name": "SOP-MANUFACTURING-001",
  "unique_code": "SOP-MANU-001",
  "version_no": "1.0",
  "description": "Standard Operating Procedure for tablet manufacturing",
  "document_type": "SOP",
  
  "storage": {
    "url": "s3://documents/org-uuid/doc-uuid/SOP-MANU-001-v1.0.pdf",
    "file_name": "SOP-MANU-001.pdf",
    "file_size_bytes": 2048576,
    "mime_type": "application/pdf",
    "file_hash": "sha256:abc123def456..."
  },
  
  "lifecycle": {
    "status": "effective",
    "effective_from": "2026-05-01",
    "effective_until": "2027-05-01",
    "next_review": "2026-11-01",
    "revision_no": 0
  },
  
  "ownership": {
    "department": {
      "id": "dept-uuid",
      "name": "Manufacturing"
    },
    "owner": {
      "id": "emp-uuid",
      "name": "John Trainer"
    },
    "approver": {
      "id": "approver-uuid",
      "name": "Quality Manager"
    }
  },
  
  "compliance": {
    "sop_number": "SOP/MANU/001",
    "audit_trail": [
      {
        "action": "created",
        "by": "creator-name",
        "at": "2026-04-23T10:00:00Z"
      },
      {
        "action": "submitted",
        "by": "creator-name",
        "at": "2026-04-23T15:00:00Z"
      },
      {
        "action": "approved",
        "by": "approver-name",
        "at": "2026-04-24T14:00:00Z",
        "e_signature": {
          "certificate_thumbprint": "...",
          "timestamp": "2026-04-24T14:00:00Z"
        }
      }
    ]
  },
  
  "_links": {
    "self": { "href": "/v1/documents/doc-uuid" },
    "versions": { "href": "/v1/documents/doc-uuid/versions" },
    "approval_history": { "href": "/v1/documents/doc-uuid/approvals" }
  }
}
```

### 6. Create Course

**Endpoint:** `POST /v1/courses`

**Request:**
```json
{
  "name": "GMP Fundamentals Training",
  "unique_code": "COURSE-GMP-001",
  "description": "Comprehensive GMP training for all manufacturing staff",
  "course_type": "mandatory",
  "training_types": ["GMP", "QUALITY"],
  
  "configuration": {
    "assessment_required": true,
    "pass_mark": 70.0,
    "max_attempts": 3,
    "self_study": false,
    "frequency_months": 24
  },
  
  "access_control": {
    "course_open_for_all": false,
    "allowed_subgroup_ids": ["subgroup-uuid-1", "subgroup-uuid-2"]
  },
  
  "topics": [
    {
      "topic_id": "topic-uuid-1",
      "order_index": 1,
      "is_mandatory": true
    },
    {
      "topic_id": "topic-uuid-2",
      "order_index": 2,
      "is_mandatory": true
    }
  ],
  
  "assessment": {
    "question_paper_id": "qpaper-uuid"
  },
  
  "certificate": {
    "template_id": "cert-template-uuid",
    "validity_months": 24
  },
  
  "metadata": {
    "sop_number": "COURSE/GMP/001",
    "effective_date": "2026-05-15",
    "estimated_duration_minutes": 480
  }
}
```

**Response (201 Created):**
```json
{
  "id": "course-uuid",
  "name": "GMP Fundamentals Training",
  "unique_code": "COURSE-GMP-001",
  "status": "draft",
  "version_no": "1.0",
  "created_at": "2026-04-23T11:00:00Z",
  "_links": {
    "self": { "href": "/v1/courses/course-uuid" },
    "edit": { "href": "/v1/courses/course-uuid" },
    "submit": { "href": "/v1/courses/course-uuid/submit" },
    "topics": { "href": "/v1/courses/course-uuid/topics" },
    "assessment": { "href": "/v1/courses/course-uuid/assessment" }
  }
}
```

### 7. List Courses

**Endpoint:** `GET /v1/courses?limit=20&status=effective`

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "course-uuid",
      "name": "GMP Fundamentals Training",
      "unique_code": "COURSE-GMP-001",
      "status": "effective",
      "course_type": "mandatory",
      "training_types": ["GMP", "QUALITY"],
      "duration_minutes": 480,
      "pass_mark": 70.0,
      "topics_count": 5,
      "assessment_required": true,
      "certificate_validity_months": 24,
      "_links": {
        "self": { "href": "/v1/courses/course-uuid" }
      }
    }
  ],
  "meta": {
    "pagination": { "total": 42, "limit": 20, "offset": 0 }
  }
}
```

### 8. Update Course (Draft Only)

**Endpoint:** `PATCH /v1/courses/{id}`

**Constraints:**
- Only DRAFT courses can be edited
- EFFECTIVE/ARCHIVED courses require a new version

**Request:**
```json
{
  "name": "GMP Fundamentals Training (Updated)",
  "description": "Updated description with new content",
  "topics": [
    { "topic_id": "topic-uuid-1", "order_index": 1, "is_mandatory": true },
    { "topic_id": "topic-uuid-2", "order_index": 2, "is_mandatory": false },
    { "topic_id": "topic-uuid-3", "order_index": 3, "is_mandatory": true }
  ]
}
```

**Response (200 OK):**
```json
{
  "id": "course-uuid",
  "name": "GMP Fundamentals Training (Updated)",
  "status": "draft",
  "updated_at": "2026-04-23T12:30:00Z",
  "topics": [...]
}
```

### 9. Submit Course for Approval

**Endpoint:** `POST /v1/courses/{id}/submit`

**Request:**
```json
{
  "submission_comments": "Ready for QA review. All topics completed.",
  "approval_matrix_id": "matrix-uuid"
}
```

**Response (200 OK):**
```json
{
  "id": "course-uuid",
  "status": "under_review",
  "submission_comments": "Ready for QA review",
  "current_approval_level": 1
}
```

### 10. Get Certificate Template

**Endpoint:** `GET /v1/certificate-templates/{id}`

**Response (200 OK):**
```json
{
  "id": "cert-template-uuid",
  "name": "GMP Training Certificate",
  "layout_json": {
    "background": {
      "color": "#FFFFFF",
      "image_url": "s3://..."
    },
    "elements": [
      {
        "type": "text",
        "content": "Certificate of Completion",
        "x": 50,
        "y": 100,
        "font_size": 36,
        "font_weight": "bold"
      },
      {
        "type": "placeholder",
        "placeholder": "employee_name",
        "x": 200,
        "y": 200
      },
      {
        "type": "qr_code",
        "x": 50,
        "y": 400
      }
    ]
  },
  "include_expiry": true,
  "include_qr_code": true,
  "colors": {
    "primary": "#0066CC",
    "accent": "#FF6600"
  }
}
```

### 11. Document Version History

**Endpoint:** `GET /v1/documents/{id}/versions`

**Response (200 OK):**
```json
{
  "data": [
    {
      "version_no": "1.0",
      "storage_url": "s3://...",
      "change_summary": "Initial version",
      "is_current": false,
      "created_at": "2026-04-20T10:00:00Z",
      "created_by": "author-name",
      "approved_at": "2026-04-20T14:00:00Z",
      "approved_by": "approver-name"
    },
    {
      "version_no": "1.1",
      "storage_url": "s3://...",
      "change_summary": "Fixed typo in section 3.2",
      "is_current": true,
      "created_at": "2026-04-23T10:00:00Z",
      "created_by": "author-name",
      "approved_at": "2026-04-23T14:00:00Z",
      "approved_by": "approver-name"
    }
  ]
}
```

---

## Business Logic & Workflows

### Workflow 1: Document Creation → Approval

```
Step 1: Author Uploads Document
  Input: PDF file + metadata
  Output: DRAFT document created
  Schema: INSERT INTO documents (status='draft', ...)

Step 2: Author Reviews & Submits
  Input: Final review complete
  Output: Status → UNDER_REVIEW, approval workflow triggered
  Schema: UPDATE documents SET status='under_review'
          INSERT INTO document_control (current_level=1, ...)

Step 3: Approver Reviews
  Input: Approver reads document
  Output: Decision (approve/reject/request changes)
  
  If APPROVE:
    - If more levels: Escalate to next approver
    - If final: Status → EFFECTIVE, archive previous version
    - Insert e-signature record with 21 CFR Part 11 hash
    
  If REJECT:
    - Status → DRAFT (back to author)
    - Include comments for improvement

Step 4: Publish
  When EFFECTIVE:
    - Notify all users who have access
    - Update next_review date
    - Archive previous versions
```

### Workflow 2: Course Creation with Topics

```
Step 1: Create Course
  Schema: INSERT INTO courses (status='draft', ...)

Step 2: Add Topics
  Schema: INSERT INTO course_topics (course_id, topic_id, order_index, ...)

Step 3: Link Assessment
  Schema: UPDATE courses SET assessment_id = ...

Step 4: Configure Certificate
  Schema: UPDATE courses SET certificate_template_id = ...

Step 5: Set Access Control
  Schema: INSERT INTO course_subgroup_access (course_id, subgroup_id, ...)

Step 6: Submit for Approval
  Schema: UPDATE courses SET status='under_review', ...
          INSERT INTO document_control (...)
```

### Workflow 3: Document Versioning

```
When document EFFECTIVE status is reached and needs an update:

Step 1: Create New Version
  - Retrieve current document (v1.0)
  - Create new draft (v1.1 or v2.0 based on change type)
  - Copy topics, assessment links, access control
  
Step 2: Update Content
  - Upload new file
  - Update metadata if needed
  
Step 3: Track Changes
  - change_summary = "Fixed typos in section 3"
  - revision_no += 1
  
Step 4: Approval
  - Submit new version through approval workflow
  - Previous version → ARCHIVED when new version → EFFECTIVE
  
Step 5: Query Previous Versions
  - Users can download any historical version
  - Audit trail shows full change history
```

### Business Rules

**Rule 1: Only Draft documents can be edited**
```sql
CONSTRAINT chk_edit_only_draft AS (
  status = 'draft'  -- Enforced at app layer
)
```

**Rule 2: Version transitions**
```
DRAFT → UNDER_REVIEW → EFFECTIVE → ARCHIVED
UNDER_REVIEW can loop back to DRAFT (reject)
```

**Rule 3: Course prerequisite chain**
```
Topic order matters
Topic 1 (mandatory) → Topic 2 (mandatory) → Topic 3 (optional)
TRAIN module enforces prerequisite logic
```

**Rule 4: Certificate expiration**
```
Certificate validity_months = 24
Expiration date = completed_at + (24 * 30 days)
Compliance module warns 30 days before expiry
```

---

## UI/UX Design

### Apple Design Principles Applied

**1. Simplicity**
- Single-page document creation form (no wizards)
- Inline editing (no modal dialogs)
- Clear status badges (not unclear flags)

**2. Focus**
- 80% of users: Create SOP → Submit → Done
- 20% power users: Advanced templates, bulk operations

**3. Integration**
- Document + Assessment linked in one interface
- Real-time search across all documents
- Offline draft with auto-sync

**4. Attention to Detail**
- File upload shows progress
- Approval pending → Show countdown timer
- Version diff highlighting

**5. UX First**
- < 100ms search response
- Toast notifications (not modals) for approvals
- Haptic feedback on approval actions (iPad)

### Screen Flows

#### Screen 1: Document List (Dashboard)

```
┌────────────────────────────────────────────────────┐
│ PharmaLearn › Documents                        [+] │
├────────────────────────────────────────────────────┤
│                                                    │
│  Search: [______________________]                 │
│                                                    │
│  Filter:  ☐ Drafts   ☐ Pending   ☐ Effective    │
│                                                    │
├────────────────────────────────────────────────────┤
│ SOP-MANU-001 (v1.0)                       EFFECTIVE │
│ Standard Operating Procedure...       📋 EDIT     │
│ Manufacturing Dept · Created 4 days ago            │
│ Expires: 1 May 2027                                │
│                                                    │
├────────────────────────────────────────────────────┤
│ SOP-QUALITY-002 (v1.1)              UNDER_REVIEW  │
│ Quality Control Process...                         │
│ Quality Dept · Pending: Manager Review (1 day)    │
│                                                    │
├────────────────────────────────────────────────────┤
│ FORM-001 (DRAFT)                                  │
│ Incident Report Form                  ✏️ DRAFT    │
│ Manufacturing · Started 2 hours ago                │
│                                                    │
└────────────────────────────────────────────────────┘
```

**Key UX Elements:**
- Status badges with colors (green=effective, yellow=pending, gray=draft)
- Quick actions (Edit, Approve, Download)
- Search with real-time results
- Filter chips (filterable, removable)

#### Screen 2: Document Editor

```
┌────────────────────────────────────────────────────┐
│ ← Back  Create SOP Document          Save | Submit │
├────────────────────────────────────────────────────┤
│                                                    │
│ Document Name                                      │
│ [SOP-Manufacturing-001____________]              │
│                                                    │
│ Unique Code                                        │
│ [SOP-MANU-001______]                             │
│                                                    │
│ Document Type                                      │
│ [▼ SOP               ]                           │
│                                                    │
│ Department                                         │
│ [▼ Manufacturing    ]                            │
│                                                    │
│ Upload PDF/Word Document                           │
│ ┌────────────────────────────────────┐           │
│ │ Drag file here or click to browse  │           │
│ │                                    │           │
│ │  SOP-MANU-001.pdf (2.3 MB)        │           │
│ │  Uploading... [████████░░░░] 70%   │           │
│ └────────────────────────────────────┘           │
│                                                    │
│ Effective Dates                                    │
│ From: [May 01, 2026]  Until: [May 01, 2027]     │
│                                                    │
│ Next Review Date                                   │
│ [November 01, 2026]                              │
│                                                    │
│ Description (optional)                             │
│ [Standard Operating Procedure for tablet         │
│  manufacturing including quality control,        │
│  packaging, and labeling procedures...         ]  │
│                                                    │
│ Related Documents (optional)                       │
│ + Add Document                                     │
│   [Cross-reference other SOPs]                    │
│                                                    │
│ Approver(s)                                        │
│ [+ Assign Approver]                              │
│   Manager (Assigned)                              │
│   QA Head (Auto-assigned)                         │
│                                                    │
└────────────────────────────────────────────────────┘
```

**Validation:**
- Real-time: name, code uniqueness
- On submit: All required fields present
- File: PDF/Word only, max 100 MB

#### Screen 3: Approval Workflow

```
┌────────────────────────────────────────────────────┐
│ SOP-MANU-001 (v1.1) › Approval Workflow            │
├────────────────────────────────────────────────────┤
│                                                    │
│ Document: SOP-Manufacturing-001                    │
│ Version: 1.1                                       │
│ Status: UNDER_REVIEW                              │
│ Submitted: 3 hours ago by John Trainer            │
│                                                    │
│ ──────────────────────────────────────────────    │
│                                                    │
│ ✓ Level 1: Department Head Review                │
│   Approved by: Manager A                          │
│   On: 3 hours ago                                 │
│   ➜ Approved. Looks good!                        │
│                                                    │
│ → Level 2: Quality Assurance (PENDING)           │
│   Assigned to: QA Head, QA Officer               │
│   Deadline: Tomorrow at 10 AM                      │
│                                                    │
│   [📄 View Document]                             │
│                                                    │
│   Feedback:                                        │
│   [Enter your approval decision...         ]      │
│                                                    │
│   ☐ Approved  ☐ Request Changes  ☐ Reject      │
│                                                    │
│   [Sign & Approve]  [Cancel]                     │
│                                                    │
│ ○ Level 3: Legal Review (Not yet started)        │
│   Assigned to: Legal Officer                      │
│                                                    │
│ ──────────────────────────────────────────────    │
│                                                    │
│ Audit Trail:                                       │
│ • Created by John Trainer - 2026-04-23 10:00 AM  │
│ • Submitted for approval - 2026-04-23 15:00 AM   │
│ • Level 1 Approved by Manager A - 2026-04-23 ... │
│                                                    │
└────────────────────────────────────────────────────┘
```

#### Screen 4: Course Builder

```
┌────────────────────────────────────────────────────┐
│ Create Course                                [Next]│
├────────────────────────────────────────────────────┤
│                                                    │
│ Step 1 of 4: Course Details                       │
│                                                    │
│ Course Name                                        │
│ [GMP Fundamentals Training_____________]         │
│                                                    │
│ Code                                               │
│ [COURSE-GMP-001_________]                        │
│                                                    │
│ Type                                               │
│ ◉ One-Time  ○ Periodic  ○ Competency             │
│                                                    │
│ Training Types                                     │
│ ☑ GMP        ☑ Safety   ☐ Quality  ☐ Compliance│
│                                                    │
│ Duration                                           │
│ [480______] minutes                              │
│                                                    │
│ Description                                        │
│ [Comprehensive training on Good Manufacturing    │
│  Practices...                                 ]   │
│                                                    │
│ ────────────────────────────────────────────    │
│ [← Back]                        [Save Draft]     │
│                                                    │
└────────────────────────────────────────────────────┘
```

### Reusable Flutter Components

**1. DocumentStatusBadge**
```dart
enum DocumentStatus { draft, underReview, effective, archived }

class DocumentStatusBadge extends StatelessWidget {
  final DocumentStatus status;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
```

**2. DocumentUploadWidget**
```dart
class DocumentUploadWidget extends StatefulWidget {
  final Function(File file) onFileSelected;
  
  @override
  _DocumentUploadWidgetState createState() => _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends State<DocumentUploadWidget> {
  bool isUploading = false;
  double uploadProgress = 0;
  
  @override
  Widget build(BuildContext context) {
    return DragTarget<List<File>>(
      onAccept: (files) => _uploadFile(files.first),
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (isUploading)
                LinearProgressIndicator(value: uploadProgress)
              else
                Text('Drag file here or click to browse'),
            ],
          ),
        );
      },
    );
  }
}
```

**3. ApprovalFlowWidget**
```dart
class ApprovalFlowWidget extends StatelessWidget {
  final List<ApprovalLevel> levels;
  final int currentLevel;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(levels.length, (index) {
        final level = levels[index];
        return ApprovalLevelTile(
          level: level,
          isCurrent: index == currentLevel,
          isCompleted: index < currentLevel,
        );
      }),
    );
  }
}
```

---

## Real-World Reference: Veeva Vault

### How Veeva Vault Informs Our Design

**Veeva Vault** is the #1 document management system in pharma (used by Pfizer, Moderna, J&J, GSK, etc.).

#### 1. Vault's Document Lifecycle Model

```
Vault States:      Our Implementation:
─────────────      ──────────────────
Draft       →      DRAFT
In Review   →      UNDER_REVIEW
Effective   →      EFFECTIVE
Superseded  →      ARCHIVED
Obsolete    →      ARCHIVED
```

**We adopt Vault's approach:**
- Clear state transitions (users never confused about status)
- Immutable historical versions
- E-signature on every approval
- Automatic archival when superseded

#### 2. Vault's Approval Matrices

```
Vault Configuration:
  Rule: If document_type = "SOP"
    AND department = "Manufacturing"
    Then require approvals:
      - Level 1: Manufacturing Manager (1 approver from group)
      - Level 2: Quality Head (all approvers in group must approve)
      - Level 3: Regulatory (if sop_number starts with "REG-")

Our Implementation:
  approval_matrices table
  ├── levels (ordered array)
  ├── approvers_role_id (who can approve?)
  ├── requires_all (1 of N vs all must approve)
  ├── timeline_hours (SLA)
  └── escalation_rule (notify manager if overdue)
```

#### 3. Vault's Compliance Features We Adopt

| Feature | Vault Pattern | Our Implementation |
|---------|---------------|-------------------|
| **Version Control** | Major.Minor.Revision | v1.0, v1.1, v2.0 |
| **E-Signatures** | PKI certificates + timestamps | 21 CFR Part 11 §11.200 |
| **Audit Trail** | Immutable log per document | audit_trail JSONB |
| **Hash Chaining** | Each version has SHA-256 | file_hash field |
| **Change Tracking** | Changed fields logged | change_summary field |

#### 4. Vault's User Experience Lessons

| Vault UX | Our Adoption |
|----------|--------------|
| Search is fast (< 100ms) | PostgreSQL full-text search + indexes |
| Bulk operations | Multi-select + batch approve |
| Notifications | Real-time via Supabase Realtime |
| Mobile-friendly | Flutter responsive design |
| Integration APIs | PostgREST automatic CRUD + custom RPC |

---

## Vyuh Framework Integration

### Using Vyuh for Enterprise Patterns

**Vyuh** is a modern framework for building enterprise apps with type-safe data models. We use these packages:

#### 1. **vyuh_entity_system** (v1.17.0)

**Use Case:** Auto-generate Document and Course CRUD operations

```dart
// Define Entity
final documentEntity = EntityDefinition(
  id: 'document',
  label: 'Document',
  properties: [
    StringProperty(
      id: 'name',
      label: 'Document Name',
      required: true,
    ),
    StringProperty(
      id: 'unique_code',
      label: 'Unique Code',
      required: true,
      validation: RegexValidator(pattern: r'^[A-Z0-9-]+$'),
    ),
    EnumProperty(
      id: 'document_type',
      label: 'Type',
      values: ['SOP', 'WI', 'FORM', 'REFERENCE'],
    ),
    EnumProperty(
      id: 'status',
      label: 'Status',
      values: ['draft', 'under_review', 'effective', 'archived'],
    ),
    DateProperty(
      id: 'effective_from',
      label: 'Effective From',
    ),
    FileProperty(
      id: 'file',
      label: 'PDF/Word Document',
      accept: ['.pdf', '.docx'],
      maxSize: 100 * 1024 * 1024,
    ),
  ],
);

// Auto-generated:
// - SQLite schema (offline)
// - API endpoints (GET, POST, PATCH, DELETE)
// - CRUD UI screens
// - Validation logic
```

**Benefit:** Instead of writing 50 lines of boilerplate, we get:
- ✅ Automatic CRUD endpoints
- ✅ Type-safe validation
- ✅ Automatic UI generation
- ✅ Offline caching

#### 2. **vyuh_property_system** (v1.3.0)

**Use Case:** Type-safe properties with custom validation

```dart
// Custom property for Approval Matrix
class ApprovalMatrixProperty extends Property {
  @override
  String get label => 'Approval Workflow';
  
  @override
  Widget buildInput(BuildContext context, dynamic value) {
    return ApprovalMatrixBuilder(
      initialMatrix: value,
      onChanged: (matrix) {
        // Validate that each level has at least one approver
        // Validate timeline_hours is reasonable
      },
    );
  }
}

// Usage in Entity
final courseEntity = EntityDefinition(
  properties: [
    ApprovalMatrixProperty(id: 'approval_matrix'),
  ],
);
```

#### 3. **vyuh_workflow_engine** (v1.3.2)

**Use Case:** Document approval workflow (BPMN pattern)

```dart
final approvalWorkflow = WorkflowDefinition(
  id: 'document_approval',
  label: 'Document Approval Flow',
  
  steps: [
    TaskNode(
      id: 'author_review',
      label: 'Author Reviews Document',
      assignedTo: RoleExpression('document_creator'),
      inputs: ['document_id'],
      action: 'document/review',
    ),
    
    GatewayNode(
      id: 'approved_check',
      label: 'Ready for Approval?',
      condition: 'document.status == "under_review"',
    ),
    
    TaskNode(
      id: 'level1_approval',
      label: 'Level 1 Approval (Manager)',
      assignedTo: RoleExpression('department_manager'),
      action: 'document/approve_level1',
      dueDate: 'now + 24h',
      escalation: 'notify_escalation_manager',
    ),
    
    TaskNode(
      id: 'level2_approval',
      label: 'Level 2 Approval (QA)',
      assignedTo: RoleExpression('qa_head'),
      action: 'document/approve_level2',
      dueDate: 'now + 48h',
    ),
    
    TaskNode(
      id: 'publish',
      label: 'Publish Document',
      assignedTo: RoleExpression('system'),
      action: 'document/publish',
      trigger: 'automatic_on_final_approval',
    ),
  ],
);

// Execution
final workflowInstance = WorkflowEngine.start(
  workflow: approvalWorkflow,
  context: {'document_id': doc_uuid},
);

// Listen to approval status changes
workflowInstance.statusStream.listen((status) {
  if (status == 'level1_approval') {
    // Send notification to approver
    notificationService.send(
      to: approver_ids,
      title: 'Document Approval Required',
      body: 'Please review SOP-MANU-001',
    );
  }
});
```

#### 4. **vyuh_form_editor** (v1.3.1)

**Use Case:** Dynamic course assessment forms

```dart
// Build assessment form dynamically
final assessmentForm = FormDefinition(
  id: 'gmp_assessment_001',
  title: 'GMP Fundamentals Assessment',
  fields: [
    TextField(
      id: 'q1',
      label: 'Q1: What does GMP stand for?',
      type: 'multiple_choice',
      options: ['Good Manufacturing Practices', 'General Management Procedures', ...],
      points: 1,
    ),
    TextField(
      id: 'q2',
      label: 'Q2: Describe the document control process',
      type: 'short_answer',
      points: 3,
      validation: TextLengthValidator(minLength: 50),
    ),
  ],
);

// Auto-generates Flutter UI with:
// - Question rendering
// - Answer collection
// - Validation
// - Score calculation
```

#### 5. **vyuh_rule_engine** (v1.1.3)

**Use Case:** Business rules for course eligibility, prerequisites

```dart
// Rule: Can employee take course?
final courseEligibilityRule = Rule(
  id: 'course_eligibility',
  name: 'Course Eligibility Check',
  conditions: [
    'employee.role_id in course.allowed_roles',
    'employee.subgroup_id in course.allowed_subgroups',
    'employee.department_id = course.department_id OR course.open_to_all',
    'employee.active_status = true',
    'prerequisite_course_status = "completed" OR prerequisite_waived',
  ],
  action: 'allow_course_access',
  otherwise: 'deny_with_reason',
);

// Evaluate rule
final canAccess = ruleEngine.evaluate(
  rule: courseEligibilityRule,
  context: {
    'employee': employeeData,
    'course': courseData,
    'prerequisite_course_status': 'completed',
  },
);

if (!canAccess) {
  print('Reason: ${canAccess.reason}');  // "Missing prerequisite: Advanced GMP"
}
```

---

## Compliance & Audit

### 21 CFR Part 11 Compliance

**Section 11.200: E-Signature Standards**

Our implementation:

```sql
-- e_signature_base.sql
CREATE TABLE IF NOT EXISTS e_signatures (
    id UUID PRIMARY KEY,
    signed_by_id UUID NOT NULL REFERENCES employees,
    document_id UUID NOT NULL REFERENCES documents,
    
    -- Certificate
    certificate_thumbprint TEXT NOT NULL,  -- SHA-256 of cert
    certificate_issuer TEXT,
    certificate_valid_from TIMESTAMPTZ,
    certificate_valid_until TIMESTAMPTZ,
    
    -- Signature Data
    signature_value BYTEA NOT NULL,        -- Digital signature bytes
    signature_algorithm TEXT,              -- SHA256withRSA, etc.
    
    -- Timestamp (critical for Part 11)
    signed_timestamp TIMESTAMPTZ NOT NULL, -- Official timestamp
    timestamp_authority TEXT,              -- TSA that verified time
    
    -- Context (11.300: Meaning & Intent)
    signed_action TEXT,                    -- 'approved', 'rejected', 'submitted'
    signing_reason TEXT,                   -- Why signed (audit context)
    signed_document_hash TEXT,             -- Hash of document at time of sign
    
    -- Audit trail (11.400: Audit trails)
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_e_signatures_doc ON e_signatures(document_id);
CREATE INDEX idx_e_signatures_emp ON e_signatures(signed_by_id);
```

**Section 11.300: Meaning & Intent**

Our approach:

```dart
// When approving, capture context:
Future<void> approveDocument(String docId, String approverPassword) async {
  final approval = DocumentApproval(
    documentId: docId,
    approverId: currentEmployee.id,
    approvalComments: "Approved. Process flows are correct.",
    
    // Capture meaning & intent
    signingReason: "Approval of manufacturing SOP v1.1",
    signedAction: "approved",
    
    // Context
    timestamp: DateTime.now(),
    ipAddress: await getClientIp(),
    userAgent: getUserAgent(),
  );
  
  // Sign with PKI certificate
  final eSignature = await pkiService.sign(
    data: jsonEncode(approval.toJson()),
    password: approverPassword,
  );
  
  // Store immutable record
  await db.documentApprovals.insert(approval);
}
```

**Section 11.400: Audit Trails**

Our implementation (immutable append-only):

```sql
-- Audit trail cannot be deleted
CREATE TABLE IF NOT EXISTS audit_trail (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type TEXT NOT NULL,            -- 'document', 'course', etc.
    entity_id UUID NOT NULL,
    action TEXT NOT NULL,                 -- 'created', 'updated', 'approved'
    changed_by_id UUID NOT NULL,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    old_values JSONB,                     -- Previous state
    new_values JSONB,                     -- New state
    ip_address INET,
    
    -- Hash chain (optional but recommended)
    previous_record_hash TEXT,
    this_record_hash TEXT GENERATED ALWAYS AS (
        encode(sha256(convert_to(row_to_json(*), 'utf8')), 'hex')
    ) STORED
);

-- Delete protection
ALTER TABLE audit_trail ENABLE ROW LEVEL SECURITY;

CREATE POLICY audit_trail_no_delete ON audit_trail
    AS (operation = DELETE)
    USING (FALSE);  -- No deletes allowed

-- Only insert
CREATE POLICY audit_trail_insert ON audit_trail
    AS (operation = INSERT)
    USING (TRUE);
```

### Data Integrity Verification

```sql
-- File hash verification on download
CREATE OR REPLACE FUNCTION verify_document_integrity(
    p_document_id UUID,
    p_downloaded_file_hash TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_stored_hash TEXT;
BEGIN
    SELECT file_hash INTO v_stored_hash
    FROM documents
    WHERE id = p_document_id;
    
    IF v_stored_hash IS NULL THEN
        RAISE EXCEPTION 'Document not found';
    END IF;
    
    RETURN (v_stored_hash = p_downloaded_file_hash);
END;
$$ LANGUAGE plpgsql;

-- Usage in API
GET /v1/documents/{id}/verify-integrity
{
  "file_hash": "sha256:abc123..."
}

Response:
{
  "is_valid": true,
  "stored_hash": "sha256:abc123...",
  "verification_timestamp": "2026-04-23T14:00:00Z"
}
```

---

## Implementation Checklist

### Phase 1: Data Model & API (Weeks 1-3)

- [ ] Create Supabase schema migrations
  - [ ] documents table with versioning
  - [ ] document_control for workflow tracking
  - [ ] e_signatures table for 21 CFR Part 11
  - [ ] audit_trail immutable log
- [ ] Set up Row-Level Security (RLS) policies
  - [ ] Users can only see documents in their org/plant
  - [ ] Only approvers can approve their level
- [ ] Implement PostgREST API layer
  - [ ] CRUD endpoints for documents
  - [ ] Approval workflow endpoints
  - [ ] Version history endpoints
- [ ] Create API tests (50+ test cases)

### Phase 2: Flutter UI (Weeks 4-5)

- [ ] Implement DocumentListScreen
- [ ] Implement DocumentEditorScreen
- [ ] Implement ApprovalFlowScreen
- [ ] Implement CourseBuilderScreen
- [ ] Implement CertificateTemplateBuilder
- [ ] Offline sync with SyncService

### Phase 3: Workflows & Business Logic (Weeks 6-7)

- [ ] Implement document approval workflow (Vyuh WorkflowEngine)
- [ ] Implement email notifications (approval pending, approved, rejected)
- [ ] Implement course eligibility rules (Vyuh RuleEngine)
- [ ] Implement version history & change tracking
- [ ] Implement e-signature integration

### Phase 4: Testing & Compliance (Week 8)

- [ ] Unit tests for business logic
- [ ] Integration tests for workflows
- [ ] 21 CFR Part 11 compliance validation
- [ ] Audit trail verification
- [ ] Load testing (1000+ documents)

---

## Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Document creation (p95) | < 5 seconds | — |
| Approval response (p95) | < 100ms | — |
| Search (p95) | < 100ms | — |
| Version retrieval | < 500ms | — |
| Offline sync | < 5 seconds | — |
| Approval SLA adherence | > 95% | — |
| Audit trail completeness | 100% | — |

---

## References

- Veeva Vault Document Lifecycle: https://www.veeva.com/
- 21 CFR Part 11: https://www.ecfr.gov/ead/title-21/chapter-I/part-11
- EU Annex 11: GAMP 5 Guidelines
- Vyuh Framework: https://pub.vyuh.tech
- PostgREST: https://postgrest.org
- Flutter: https://flutter.dev

---

**Document Author:** Architecture Team  
**Last Updated:** 2026-04-23  
**Next Review:** 2026-05-23
