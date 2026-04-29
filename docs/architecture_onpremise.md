# PharmaLearn LMS — On-Premise Architecture

> **Version:** 3.0 | **Date:** April 2026  
> **Deployment:** On-Premise / Air-Gapped  
> **Compliance:** 21 CFR Part 11 · EU Annex 11 · GAMP 5 · ISO 27001

---

## Executive Summary

PharmaLearn LMS is designed for pharmaceutical and life sciences organizations requiring **validated, compliant training management** with full on-premise deployment capability. This document describes the architecture for air-gapped, self-hosted deployments.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Deployment Topology](#2-deployment-topology)
3. [Technology Stack](#3-technology-stack)
4. [Component Architecture](#4-component-architecture)
5. [Database Architecture](#5-database-architecture)
6. [API Architecture](#6-api-architecture)
7. [Security Architecture](#7-security-architecture)
8. [High Availability & DR](#8-high-availability--dr)
9. [Integration Points](#9-integration-points)
10. [Infrastructure Requirements](#10-infrastructure-requirements)
11. [Deployment Guide](#11-deployment-guide)

---

## 1. System Overview

### 1.1 Architecture Principles

| Principle | Implementation |
|-----------|----------------|
| **Compliance-First** | Immutable audit trails, e-signatures, 21 CFR Part 11 |
| **Air-Gap Ready** | No external dependencies in production |
| **Multi-Tenant** | Organization → Plant → Department hierarchy |
| **High Availability** | Active-passive with automatic failover |
| **Data Integrity** | SHA-256 hash chains, cryptographic verification |

### 1.2 System Modules

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        PHARMALEARN LMS MODULES                               │
├─────────────────┬─────────────────┬─────────────────┬───────────────────────┤
│     ACCESS      │     CREATE      │      TRAIN      │       CERTIFY         │
│  ─────────────  │  ─────────────  │  ─────────────  │  ─────────────────    │
│  • Auth/SSO     │  • Courses      │  • Sessions     │  • Assessments        │
│  • Users/Roles  │  • Documents    │  • Attendance   │  • Grading            │
│  • Permissions  │  • Content      │  • OJT/Induction│  • Certificates       │
│  • E-Signatures │  • Question Bank│  • Scheduling   │  • Competencies       │
├─────────────────┴─────────────────┴─────────────────┴───────────────────────┤
│                         SUPPORTING SERVICES                                  │
├─────────────────┬─────────────────┬─────────────────┬───────────────────────┤
│    WORKFLOW     │    REPORTS      │   NOTIFICATIONS │       HEALTH          │
│  ─────────────  │  ─────────────  │  ─────────────  │  ─────────────────    │
│  • Approvals    │  • Compliance   │  • Email        │  • Monitoring         │
│  • Escalations  │  • Analytics    │  • In-App       │  • Diagnostics        │
│  • Delegations  │  • KPIs         │  • Reminders    │  • Audit              │
└─────────────────┴─────────────────┴─────────────────┴───────────────────────┘
```

---

## 2. Deployment Topology

### 2.1 Standard On-Premise Deployment

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              DMZ / EDGE ZONE                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│    ┌─────────────────┐         ┌─────────────────┐                              │
│    │  Load Balancer  │         │    WAF/Firewall │                              │
│    │   (HAProxy)     │◄───────►│    (ModSecurity)│                              │
│    └────────┬────────┘         └─────────────────┘                              │
│             │                                                                   │
│             │ HTTPS (443)                                                       │
│             ▼                                                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           APPLICATION ZONE                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│    │  App Server 1   │    │  App Server 2   │    │  App Server N   │            │
│    │  ─────────────  │    │  ─────────────  │    │  ─────────────  │            │
│    │  Dart VM        │    │  Dart VM        │    │  Dart VM        │            │
│    │  Relic HTTP     │    │  Relic HTTP     │    │  Relic HTTP     │            │
│    │  API Server     │    │  API Server     │    │  API Server     │            │
│    └────────┬────────┘    └────────┬────────┘    └────────┬────────┘            │
│             │                      │                      │                     │
│             └──────────────────────┼──────────────────────┘                     │
│                                    │                                            │
│                                    ▼                                            │
│    ┌─────────────────────────────────────────────────────────────┐              │
│    │                    Connection Pool (PgBouncer)              │              │
│    └─────────────────────────────────┬───────────────────────────┘              │
│                                      │                                          │
├──────────────────────────────────────┼──────────────────────────────────────────┤
│                              DATA ZONE                                           │
├──────────────────────────────────────┼──────────────────────────────────────────┤
│                                      │                                          │
│    ┌─────────────────┐    ┌──────────▼──────────┐    ┌─────────────────┐        │
│    │  PostgreSQL     │◄──►│  PostgreSQL         │    │   File Storage  │        │
│    │  Standby        │    │  Primary            │    │   (MinIO/NFS)   │        │
│    │  (Streaming Rep)│    │  ─────────────────  │    │  ─────────────  │        │
│    │                 │    │  282 Tables         │    │  • Documents    │        │
│    │                 │    │  70 Enums           │    │  • SCORM        │        │
│    │                 │    │  753 Foreign Keys   │    │  • Certificates │        │
│    └─────────────────┘    └─────────────────────┘    └─────────────────┘        │
│                                                                                 │
│    ┌─────────────────────┐                                                      │
│    │  Backup Storage     │                                                      │
│    │  (Encrypted)        │                                                      │
│    └─────────────────────┘                                                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Air-Gapped Deployment

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         AIR-GAPPED ENVIRONMENT                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         INTERNAL NETWORK                                 │   │
│   │                                                                         │   │
│   │    ┌───────────────┐                      ┌───────────────┐             │   │
│   │    │ Internal LB   │                      │ LDAP/AD       │             │   │
│   │    │ (Keepalived)  │                      │ Integration   │             │   │
│   │    └───────┬───────┘                      └───────────────┘             │   │
│   │            │                                                            │   │
│   │            ▼                                                            │   │
│   │    ┌───────────────────────────────────────────────────────────┐        │   │
│   │    │              APPLICATION CLUSTER                          │        │   │
│   │    │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐       │        │   │
│   │    │  │ Node 1  │  │ Node 2  │  │ Node 3  │  │ Node N  │       │        │   │
│   │    │  │ (Active)│  │(Standby)│  │(Standby)│  │(Standby)│       │        │   │
│   │    │  └─────────┘  └─────────┘  └─────────┘  └─────────┘       │        │   │
│   │    └───────────────────────────────────────────────────────────┘        │   │
│   │                              │                                          │   │
│   │                              ▼                                          │   │
│   │    ┌───────────────────────────────────────────────────────────┐        │   │
│   │    │              DATABASE CLUSTER                             │        │   │
│   │    │  ┌─────────────────┐     ┌─────────────────┐              │        │   │
│   │    │  │ PostgreSQL      │────►│ PostgreSQL      │              │        │   │
│   │    │  │ Primary         │     │ Replica         │              │        │   │
│   │    │  │ (Patroni HA)    │     │ (Streaming)     │              │        │   │
│   │    │  └─────────────────┘     └─────────────────┘              │        │   │
│   │    └───────────────────────────────────────────────────────────┘        │   │
│   │                                                                         │   │
│   │    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐          │   │
│   │    │ Time Server   │    │ Syslog Server │    │ SMTP Relay    │          │   │
│   │    │ (NTP)         │    │ (Audit)       │    │ (Internal)    │          │   │
│   │    └───────────────┘    └───────────────┘    └───────────────┘          │   │
│   │                                                                         │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                      OFFLINE UPDATE ZONE                                 │   │
│   │                                                                         │   │
│   │    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐          │   │
│   │    │ Update Server │    │ Package Repo  │    │ Container     │          │   │
│   │    │ (Manual USB)  │    │ (Local Mirror)│    │ Registry      │          │   │
│   │    └───────────────┘    └───────────────┘    └───────────────┘          │   │
│   │                                                                         │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Technology Stack

### 3.1 Core Technologies

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **Runtime** | Dart VM | 3.8+ | Application runtime |
| **HTTP Framework** | Relic HTTP | 1.2.0 | REST API server |
| **Database** | PostgreSQL | 15+ | Primary data store |
| **Database Client** | Supabase Dart | 2.5.0 | PostgreSQL client |
| **Authentication** | dart_jsonwebtoken | 2.12.1 | JWT tokens |
| **File Storage** | MinIO / NFS | - | Document storage |
| **Load Balancer** | HAProxy / Nginx | - | Traffic distribution |
| **Connection Pool** | PgBouncer | 1.x | DB connection pooling |

> **Note:** Redis is NOT currently used in the API layer. Session management uses PostgreSQL-backed storage via Supabase.

### 3.2 Supporting Libraries

| Library | Version | Purpose |
|---------|---------|---------|
| `crypto` | 3.0.3 | SHA-256 hashing |
| `archive` | 3.4.0 | SCORM package handling |
| `xml` | 6.5.0 | SCORM manifest parsing |
| `uuid` | 4.x | UUID generation |
| `logger` | 2.3.0 | Structured logging |
| `intl` | 0.19.0 | i18n support |

### 3.3 On-Premise Specific

| Component | Technology | Purpose |
|-----------|------------|---------|
| **HA Clustering** | Patroni | PostgreSQL HA |
| **Service Discovery** | Consul / etcd | Service registry |
| **Monitoring** | Prometheus + Grafana | Metrics & dashboards |
| **Log Aggregation** | ELK / Loki | Centralized logging |
| **Backup** | pgBackRest | Database backups |
| **Secrets** | HashiCorp Vault | Credential management |

---

## 4. Component Architecture

### 4.1 Application Layer

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          PHARMALEARN API SERVER                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│    ┌─────────────────────────────────────────────────────────────────────┐      │
│    │                         RELIC HTTP SERVER                           │      │
│    │                         (Port 8080)                                 │      │
│    └─────────────────────────────────────────────────────────────────────┘      │
│                                    │                                            │
│                                    ▼                                            │
│    ┌─────────────────────────────────────────────────────────────────────┐      │
│    │                         MIDDLEWARE PIPELINE                         │      │
│    │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │      │
│    │  │ CORS    │→│ Auth    │→│ Rate    │→│ Audit   │→│ Tenant  │        │      │
│    │  │ Handler │ │ JWT     │ │ Limiter │ │ Logger  │ │ Context │        │      │
│    │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘        │      │
│    └─────────────────────────────────────────────────────────────────────┘      │
│                                    │                                            │
│                                    ▼                                            │
│    ┌─────────────────────────────────────────────────────────────────────┐      │
│    │                         ROUTE MODULES                               │      │
│    │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │      │
│    │  │ ACCESS  │ │ CREATE  │ │ TRAIN   │ │ CERTIFY │ │ REPORTS │        │      │
│    │  │ 42 APIs │ │ 49 APIs │ │ 42 APIs │ │ 31 APIs │ │ 8 APIs  │        │      │
│    │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘        │      │
│    │  ┌─────────┐ ┌─────────┐                                            │      │
│    │  │WORKFLOW │ │ HEALTH  │                                            │      │
│    │  │ 9 APIs  │ │ 3 APIs  │                                            │      │
│    │  └─────────┘ └─────────┘                                            │      │
│    └─────────────────────────────────────────────────────────────────────┘      │
│                                    │                                            │
│                                    ▼                                            │
│    ┌─────────────────────────────────────────────────────────────────────┐      │
│    │                         SERVICES LAYER                              │      │
│    │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐        │      │
│    │  │ Supabase   │ │ E-Signature│ │ Workflow   │ │ Notification│       │      │
│    │  │ Client     │ │ Service    │ │ Engine     │ │ Service    │        │      │
│    │  └────────────┘ └────────────┘ └────────────┘ └────────────┘        │      │
│    └─────────────────────────────────────────────────────────────────────┘      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Module Structure

```
apps/api_server/pharma_learn/api/lib/
├── routes/
│   ├── access/           # 42 handlers - Auth, Users, Roles, Permissions
│   │   ├── auth/
│   │   ├── employees/
│   │   ├── roles/
│   │   ├── permissions/
│   │   ├── esignatures/
│   │   └── routes.dart
│   │
│   ├── create/           # 49 handlers - Courses, Documents, Content
│   │   ├── courses/
│   │   ├── documents/
│   │   ├── question_banks/
│   │   ├── topics/
│   │   └── routes.dart
│   │
│   ├── train/            # 42 handlers - Sessions, Attendance, OJT
│   │   ├── sessions/
│   │   ├── attendance/
│   │   ├── batches/
│   │   ├── induction/
│   │   └── routes.dart
│   │
│   ├── certify/          # 31 handlers - Assessments, Certificates
│   │   ├── assessments/
│   │   ├── results/
│   │   ├── certificates/
│   │   └── routes.dart
│   │
│   ├── reports/          # 8 handlers - Compliance Reports
│   │   ├── compliance/
│   │   └── routes.dart
│   │
│   ├── workflow/         # 9 handlers - Approvals, Escalations
│   │   ├── approvals/
│   │   └── routes.dart
│   │
│   └── health/           # 3 handlers - Health Checks
│       └── routes.dart
│
├── lifecycle_monitor/    # 7 handlers - Background Jobs
└── workflow_engine/      # 4 handlers - Workflow Processing
```

---

## 5. Database Architecture

### 5.1 Schema Overview

| Metric | Value |
|--------|-------|
| **Total Tables** | 282 |
| **Custom Enums** | 70 |
| **Foreign Keys** | 753 |
| **Materialized Views** | 1 |

### 5.2 Schema Modules

```
supabase/schemas/
├── 00_extensions/        # PostgreSQL extensions (uuid, pgcrypto, pg_trgm)
├── 01_types/             # 70 enum types + composite types
├── 02_core/              # Audit trails, e-signatures, workflow (13 tables)
├── 03_organization/      # Multi-tenant hierarchy (3 tables)
├── 03_config/            # System configuration (12 tables)
├── 04_identity/          # Users, roles, permissions (22 tables)
├── 05_documents/         # Document control (8 tables)
├── 06_courses/           # Course structure (17 tables)
├── 07_training/          # Training delivery (39 tables)
├── 08_assessment/        # Assessments & results (16 tables)
├── 09_compliance/        # Records & certificates (30 tables)
├── 10_quality/           # Deviations, CAPA, CC (13 tables)
├── 11_audit/             # Security audit (4 tables)
├── 12_notifications/     # Notifications (10 tables)
├── 13_analytics/         # Reports & KPIs (14 tables)
├── 14_workflow/          # Workflow engine (20 tables)
├── 15_cron/              # Scheduled jobs (4 tables)
├── 16_infrastructure/    # Files, integrations (21 tables)
├── 17_extensions/        # Optional features (42 tables)
└── 99_policies/          # RLS policies
```

### 5.3 High Availability Setup

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        POSTGRESQL HA CLUSTER                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│    ┌─────────────────────────────────────────────────────────────┐              │
│    │                        PATRONI CLUSTER                      │              │
│    │                                                             │              │
│    │    ┌─────────────────┐         ┌─────────────────┐          │              │
│    │    │  PostgreSQL     │         │  PostgreSQL     │          │              │
│    │    │  PRIMARY        │────────►│  REPLICA        │          │              │
│    │    │  ─────────────  │ Sync    │  ─────────────  │          │              │
│    │    │  Read/Write     │ Repl    │  Read-Only      │          │              │
│    │    │                 │         │  Hot Standby    │          │              │
│    │    └────────┬────────┘         └────────┬────────┘          │              │
│    │             │                           │                   │              │
│    │             └───────────┬───────────────┘                   │              │
│    │                         │                                   │              │
│    │                         ▼                                   │              │
│    │    ┌─────────────────────────────────────────────┐          │              │
│    │    │              ETCD CLUSTER                   │          │              │
│    │    │  (Leader Election & Configuration)          │          │              │
│    │    │  ┌─────────┐  ┌─────────┐  ┌─────────┐      │          │              │
│    │    │  │ Node 1  │  │ Node 2  │  │ Node 3  │      │          │              │
│    │    │  └─────────┘  └─────────┘  └─────────┘      │          │              │
│    │    └─────────────────────────────────────────────┘          │              │
│    │                                                             │              │
│    └─────────────────────────────────────────────────────────────┘              │
│                                                                                 │
│    ┌─────────────────────────────────────────────────────────────┐              │
│    │                     PGBOUNCER POOL                          │              │
│    │  ┌───────────────────────────────────────────────────────┐  │              │
│    │  │ Transaction Pooling │ Max Connections: 100            │  │              │
│    │  │ Pool Mode: transaction │ Default Pool Size: 20        │  │              │
│    │  └───────────────────────────────────────────────────────┘  │              │
│    └─────────────────────────────────────────────────────────────┘              │
│                                                                                 │
│    ┌─────────────────────────────────────────────────────────────┐              │
│    │                     PGBACKREST                              │              │
│    │  ┌───────────────────────────────────────────────────────┐  │              │
│    │  │ Full Backup: Weekly │ Incremental: Daily              │  │              │
│    │  │ WAL Archive: Continuous │ Retention: 30 days          │  │              │
│    │  └───────────────────────────────────────────────────────┘  │              │
│    └─────────────────────────────────────────────────────────────┘              │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. API Architecture

### 6.1 API Statistics

| Module | Handlers | Endpoints |
|--------|----------|-----------|
| ACCESS | 42 | ~120 |
| CREATE | 49 | ~150 |
| TRAIN | 42 | ~130 |
| CERTIFY | 31 | ~95 |
| REPORTS | 8 | ~25 |
| WORKFLOW | 9 | ~30 |
| HEALTH | 3 | ~10 |
| **Total** | **184** | **~560** |

### 6.2 API URL Structure

```
Base URL: https://{host}/api/v1

ACCESS Module:
├── /auth/login                    POST   - User login
├── /auth/logout                   POST   - User logout
├── /auth/refresh                  POST   - Refresh token
├── /employees                     GET    - List employees
├── /employees/{id}                GET    - Get employee
├── /employees                     POST   - Create employee
├── /roles                         GET    - List roles
├── /roles/{id}/permissions        GET    - Role permissions
├── /esignatures                   POST   - Create e-signature
└── /esignatures/verify            POST   - Verify signature

CREATE Module:
├── /courses                       GET    - List courses
├── /courses/{id}                  GET    - Get course
├── /courses                       POST   - Create course
├── /documents                     GET    - List documents
├── /documents/{id}/versions       GET    - Document versions
├── /question-banks                GET    - List question banks
├── /question-banks/{id}/questions GET    - Bank questions
└── /topics                        GET    - List topics

TRAIN Module:
├── /sessions                      GET    - List sessions
├── /sessions/{id}                 GET    - Get session
├── /sessions/{id}/attendance      POST   - Record attendance
├── /batches                       GET    - List batches
├── /batches/{id}/trainees         GET    - Batch trainees
├── /induction                     GET    - Induction programs
└── /ojt                           GET    - OJT assignments

CERTIFY Module:
├── /assessments                   GET    - List assessments
├── /assessments/{id}/start        POST   - Start assessment
├── /assessments/{id}/submit       POST   - Submit assessment
├── /results                       GET    - Assessment results
├── /certificates                  GET    - List certificates
└── /certificates/{id}/verify      GET    - Verify certificate

REPORTS Module:
├── /reports/compliance            GET    - Compliance report
├── /reports/training-matrix       GET    - Training matrix
├── /reports/overdue               GET    - Overdue training
└── /reports/certificates          GET    - Certificate report

WORKFLOW Module:
├── /approvals                     GET    - Pending approvals
├── /approvals/{id}/approve        POST   - Approve item
├── /approvals/{id}/reject         POST   - Reject item
└── /escalations                   GET    - Active escalations

HEALTH Module:
├── /health                        GET    - Health check
├── /health/ready                  GET    - Readiness check
└── /health/live                   GET    - Liveness check
```

### 6.3 Request/Response Format

```dart
// Standard Request Headers
{
  "Authorization": "Bearer <jwt_token>",
  "X-Organization-Id": "<uuid>",
  "X-Plant-Id": "<uuid>",           // optional
  "X-Request-Id": "<uuid>",         // correlation ID
  "Content-Type": "application/json"
}

// Standard Response Envelope
{
  "success": true,
  "data": { ... },
  "meta": {
    "page": 1,
    "pageSize": 20,
    "total": 150,
    "totalPages": 8
  },
  "requestId": "<uuid>"
}

// Error Response
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": [
      { "field": "email", "message": "Invalid email format" }
    ]
  },
  "requestId": "<uuid>"
}
```

---

## 7. Security Architecture

### 7.1 Authentication Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         AUTHENTICATION FLOW                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│    ┌─────────┐         ┌─────────────┐         ┌─────────────┐                  │
│    │ Client  │         │ API Server  │         │ PostgreSQL  │                  │
│    └────┬────┘         └──────┬──────┘         └──────┬──────┘                  │
│         │                     │                       │                         │
│         │ 1. Login Request    │                       │                         │
│         │ (email, password)   │                       │                         │
│         │────────────────────►│                       │                         │
│         │                     │                       │                         │
│         │                     │ 2. Validate User      │                         │
│         │                     │────────────────────►  │                         │
│         │                     │                       │                         │
│         │                     │ 3. User + Roles       │                         │
│         │                     │◄────────────────────  │                         │
│         │                     │                       │                         │
│         │                     │ 4. Verify Password    │                         │
│         │                     │    (bcrypt)           │                         │
│         │                     │                       │                         │
│         │                     │ 5. Generate JWT       │                         │
│         │                     │    (RS256, 15min)     │                         │
│         │                     │                       │                         │
│         │                     │ 6. Create Session     │                         │
│         │                     │────────────────────►  │                         │
│         │                     │                       │                         │
│         │                     │ 7. Log Login Event    │                         │
│         │                     │────────────────────►  │                         │
│         │                     │                       │                         │
│         │ 8. JWT + Refresh    │                       │                         │
│         │◄────────────────────│                       │                         │
│         │                     │                       │                         │
│                                                                                 │
│    JWT Payload:                                                                 │
│    {                                                                            │
│      "sub": "<employee_id>",                                                    │
│      "org": "<organization_id>",                                                │
│      "roles": ["admin", "trainer"],                                             │
│      "permissions": ["course.create", "session.manage"],                        │
│      "iat": 1714400000,                                                         │
│      "exp": 1714400900  // 15 minutes                                           │
│    }                                                                            │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 E-Signature Flow (21 CFR Part 11)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      E-SIGNATURE WORKFLOW                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│    1. INITIATE SIGNATURE                                                        │
│    ─────────────────────                                                        │
│    User → Request signature for entity (e.g., approve training record)          │
│                                                                                 │
│    2. RE-AUTHENTICATION                                                         │
│    ───────────────────                                                          │
│    • Prompt for password (mandatory)                                            │
│    • Optional: MFA verification                                                 │
│    • Optional: Biometric verification                                           │
│                                                                                 │
│    3. MEANING SELECTION                                                         │
│    ──────────────────                                                           │
│    Select signature meaning:                                                    │
│    • "authored" - Created the content                                           │
│    • "reviewed" - Reviewed the content                                          │
│    • "approved" - Approved for use                                              │
│    • "acknowledged" - Acknowledged receipt                                      │
│                                                                                 │
│    4. REASON CAPTURE (if required)                                              │
│    ─────────────────────────────────                                            │
│    • Standard reason from dropdown                                              │
│    • Or custom reason text (min 10 chars)                                       │
│                                                                                 │
│    5. SIGNATURE CREATION                                                        │
│    ─────────────────────                                                        │
│    ┌───────────────────────────────────────────────────────────┐                │
│    │ Hash Chain Creation:                                      │                │
│    │                                                           │                │
│    │ previous_hash = last_signature.hash_chain                 │                │
│    │                                                           │                │
│    │ signature_data = {                                        │                │
│    │   employee_id,                                            │                │
│    │   entity_type,                                            │                │
│    │   entity_id,                                              │                │
│    │   meaning,                                                │                │
│    │   reason,                                                 │                │
│    │   timestamp,                                              │                │
│    │   previous_hash                                           │                │
│    │ }                                                         │                │
│    │                                                           │                │
│    │ hash_chain = SHA256(JSON.stringify(signature_data))       │                │
│    └───────────────────────────────────────────────────────────┘                │
│                                                                                 │
│    6. AUDIT TRAIL                                                               │
│    ──────────────                                                               │
│    • Insert into electronic_signatures (immutable)                              │
│    • Insert into audit_trails                                                   │
│    • Trigger integrity verification                                             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 7.3 Security Controls

| Control | Implementation |
|---------|----------------|
| **Authentication** | JWT (RS256), 15-min expiry, refresh tokens |
| **Authorization** | RBAC + row-level security (RLS) |
| **Password** | bcrypt, complexity rules, history |
| **Session** | Server-side sessions, concurrent login control |
| **Encryption** | TLS 1.3 in transit, AES-256 at rest |
| **Audit** | Immutable audit_trails table |
| **E-Signatures** | SHA-256 hash chains, re-auth required |
| **Data Integrity** | Hash verification, foreign key constraints |

---

## 8. High Availability & DR

### 8.1 HA Architecture

| Component | Strategy | RPO | RTO |
|-----------|----------|-----|-----|
| **API Servers** | Active-Active behind LB | 0 | < 30s |
| **PostgreSQL** | Primary + Sync Replica | 0 | < 60s |
| **File Storage** | Replicated NFS/MinIO | < 1h | < 5m |

### 8.2 Backup Strategy

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         BACKUP ARCHITECTURE                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│    POSTGRESQL BACKUPS (pgBackRest)                                              │
│    ───────────────────────────────                                              │
│    ┌─────────────────────────────────────────────────────────────┐              │
│    │ Full Backup      │ Every Sunday 02:00 AM        │ 4 retained│              │
│    │ Incremental      │ Daily 02:00 AM               │ 7 retained│              │
│    │ WAL Archive      │ Continuous                   │ 30 days   │              │
│    │ Point-in-Time    │ Any point in last 30 days   │           │              │
│    └─────────────────────────────────────────────────────────────┘              │
│                                                                                 │
│    FILE STORAGE BACKUPS                                                         │
│    ───────────────────                                                          │
│    ┌─────────────────────────────────────────────────────────────┐              │
│    │ Documents        │ Daily incremental            │ 90 days   │              │
│    │ SCORM Packages   │ Daily incremental            │ 90 days   │              │
│    │ Certificates     │ Daily + versioned            │ Permanent │              │
│    └─────────────────────────────────────────────────────────────┘              │
│                                                                                 │
│    BACKUP VERIFICATION                                                          │
│    ───────────────────                                                          │
│    • Weekly restore test to standby environment                                 │
│    • Monthly DR drill with full recovery                                        │
│    • Checksum verification on every backup                                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 8.3 Disaster Recovery

| Scenario | Response | Recovery Time |
|----------|----------|---------------|
| **Single Server Failure** | Automatic failover | < 1 minute |
| **Database Corruption** | Point-in-time recovery | < 30 minutes |
| **Site Failure** | DR site activation | < 4 hours |
| **Ransomware** | Offline backup restore | < 8 hours |

---

## 9. Integration Points

### 9.1 Supported Integrations

| Integration | Protocol | Purpose |
|-------------|----------|---------|
| **LDAP/Active Directory** | LDAPS | User authentication |
| **SAML 2.0** | HTTPS | SSO federation |
| **SMTP** | SMTP/TLS | Email notifications |
| **Syslog** | UDP/TCP | Log forwarding |
| **SCORM 1.2/2004** | HTTP | Content packages |
| **xAPI (TinCan)** | REST | Learning records |
| **HR Systems** | REST/SOAP | Employee sync |
| **ERP** | REST | Training cost sync |

### 9.2 Integration Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        INTEGRATION ARCHITECTURE                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│    ┌─────────────────────────────────────────────────────────────────────┐      │
│    │                     PHARMALEARN API SERVER                          │      │
│    └──────────────────────────────┬──────────────────────────────────────┘      │
│                                   │                                             │
│         ┌─────────────────────────┼─────────────────────────┐                   │
│         │                         │                         │                   │
│         ▼                         ▼                         ▼                   │
│    ┌─────────┐              ┌─────────┐              ┌─────────┐                │
│    │ LDAP    │              │  SMTP   │              │  SYSLOG │                │
│    │ Adapter │              │ Adapter │              │ Adapter │                │
│    └────┬────┘              └────┬────┘              └────┬────┘                │
│         │                        │                        │                     │
│         ▼                        ▼                        ▼                     │
│    ┌─────────┐              ┌─────────┐              ┌─────────┐                │
│    │  AD/    │              │  Mail   │              │  SIEM   │                │
│    │  LDAP   │              │ Server  │              │ System  │                │
│    └─────────┘              └─────────┘              └─────────┘                │
│                                                                                 │
│         ┌─────────────────────────┼─────────────────────────┐                   │
│         │                         │                         │                   │
│         ▼                         ▼                         ▼                   │
│    ┌─────────┐              ┌─────────┐              ┌─────────┐                │
│    │  HR     │              │  ERP    │              │ Content │                │
│    │ Adapter │              │ Adapter │              │ Adapter │                │
│    └────┬────┘              └────┬────┘              └────┬────┘                │
│         │                        │                        │                     │
│         ▼                        ▼                        ▼                     │
│    ┌─────────┐              ┌─────────┐              ┌─────────┐                │
│    │ SAP HR  │              │ SAP ERP │              │  LRS    │                │
│    │ Workday │              │ Oracle  │              │ (xAPI)  │                │
│    └─────────┘              └─────────┘              └─────────┘                │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Infrastructure Requirements

### 10.1 Hardware Requirements

| Component | Minimum | Recommended | High Availability |
|-----------|---------|-------------|-------------------|
| **API Servers** | 2 × (4 CPU, 16GB RAM, 100GB SSD) | 3 × (8 CPU, 32GB RAM, 200GB SSD) | 4 × (8 CPU, 32GB RAM, 200GB SSD) |
| **Database** | 1 × (8 CPU, 32GB RAM, 500GB SSD) | 2 × (16 CPU, 64GB RAM, 1TB NVMe) | 3 × (16 CPU, 64GB RAM, 1TB NVMe) |
| **Load Balancer** | 1 × (2 CPU, 4GB RAM) | 2 × (4 CPU, 8GB RAM) | 2 × (4 CPU, 8GB RAM) |
| **File Storage** | 1TB | 5TB | 10TB (replicated) |

### 10.2 Network Requirements

| Requirement | Specification |
|-------------|---------------|
| **Bandwidth** | 1 Gbps minimum, 10 Gbps recommended |
| **Latency** | < 5ms between app and database |
| **Firewall** | Stateful inspection, IPS/IDS |
| **DNS** | Internal DNS for service discovery |
| **NTP** | Synchronized time source (critical for audit) |

### 10.3 Software Requirements

| Software | Version | Notes |
|----------|---------|-------|
| **OS** | RHEL 8/9, Ubuntu 22.04 LTS | Hardened configuration |
| **Dart SDK** | 3.8+ | Compiled AOT |
| **PostgreSQL** | 15+ | With extensions |
| **HAProxy** | 2.6+ | Or Nginx |
| **Container Runtime** | Docker 24+ / Podman | Optional |

---

## 11. Deployment Guide

### 11.1 Pre-Deployment Checklist

- [ ] Hardware provisioned and configured
- [ ] Network segmentation completed
- [ ] SSL/TLS certificates obtained
- [ ] LDAP/AD integration tested
- [ ] SMTP relay configured
- [ ] Backup storage provisioned
- [ ] Monitoring infrastructure ready
- [ ] Security hardening completed

### 11.2 Deployment Steps

```bash
# 1. Database Setup
cd supabase/
psql -h <db_host> -U postgres -f schemas/00_extensions/01_uuid.sql
psql -h <db_host> -U postgres -f schemas/00_extensions/02_pgcrypto.sql
# ... apply all schema files in order

# 2. Application Deployment
cd apps/api_server/
dart compile exe lib/main.dart -o pharmalearn_api
./pharmalearn_api --port=8080 --config=/etc/pharmalearn/config.yaml

# 3. Load Balancer Configuration
# HAProxy example
frontend pharmalearn_fe
    bind *:443 ssl crt /etc/ssl/pharmalearn.pem
    default_backend pharmalearn_be

backend pharmalearn_be
    balance roundrobin
    server app1 192.168.1.10:8080 check
    server app2 192.168.1.11:8080 check
    server app3 192.168.1.12:8080 check

# 4. Health Verification
curl -k https://localhost/api/v1/health
# Expected: {"status":"healthy","version":"3.0.0"}
```

### 11.3 Post-Deployment Validation

| Check | Command | Expected |
|-------|---------|----------|
| API Health | `curl /api/v1/health` | `{"status":"healthy"}` |
| DB Connection | `curl /api/v1/health/ready` | `{"database":"connected"}` |
| Auth Flow | Login with test user | JWT returned |
| Audit Trail | Create record | Audit entry created |
| E-Signature | Sign document | Hash chain valid |

---

## Appendix A: Compliance Mapping

### 21 CFR Part 11 Compliance

| Requirement | Implementation |
|-------------|----------------|
| **§11.10(a)** Validation | IQ/OQ/PQ documentation |
| **§11.10(b)** Copies | PDF/CSV export with audit trail |
| **§11.10(c)** Protection | RLS, encryption, backup |
| **§11.10(d)** Access Control | RBAC, session timeout |
| **§11.10(e)** Audit Trail | Immutable audit_trails table |
| **§11.50** Signature Manifestation | Display name, date, meaning |
| **§11.70** Signature Linking | Hash chain to record |
| **§11.100** Identification | Unique employee codes |
| **§11.200** E-Signature Components | Password + meaning |

---

## Appendix B: Support Contacts

| Issue | Contact | SLA |
|-------|---------|-----|
| **Critical (P1)** | 24/7 Hotline | 1 hour response |
| **High (P2)** | Support Portal | 4 hours response |
| **Medium (P3)** | Email | 1 business day |
| **Low (P4)** | Email | 3 business days |

---

*Document generated: April 2026*
