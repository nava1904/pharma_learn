# PharmaLearn LMS — Enterprise Architecture Plan

> **Version:** 3.0  
> **Date:** 2026-04-23  
> **Classification:** Enterprise Architecture Document  
> **Target:** 50,000+ concurrent users, FDA 21 CFR Part 11 validated  
> **Compliance:** 21 CFR Part 11 · EU Annex 11 · WHO GMP · ICH Q10  
> **Philosophy:** Apple-level quality, reliability, and user experience

---

## Executive Summary

This document defines the complete system architecture for PharmaLearn LMS — a **world-class, enterprise-grade, regulatory-compliant** Learning Management System for pharmaceutical and life sciences organizations.

The architecture is organized around **4 Core Modules**:

| Module | Purpose | API Namespace |
|--------|---------|---------------|
| **CREATE** | Content authoring, document management, course design | `/api/v1/create/*` |
| **ACCESS** | Identity, authentication, authorization, session management | `/api/v1/access/*` |
| **TRAIN** | Training delivery, sessions, attendance, OJT, induction | `/api/v1/train/*` |
| **CERTIFY** | Assessment, certification, compliance, competency tracking | `/api/v1/certify/*` |

### Technology Stack (Enterprise-Grade)

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Database** | PostgreSQL 15+ | Source of truth, ACID compliance |
| **Cache** | Redis Cluster | Session, API cache, pub/sub |
| **Message Queue** | Apache Kafka | Event streaming, audit backbone |
| **Search** | Elasticsearch | Full-text search, audit queries |
| **Identity** | Keycloak | SSO, MFA, RBAC |
| **Workflow** | Temporal | Durable workflow orchestration |
| **Storage** | S3 / MinIO | Files, videos, certificates |
| **API Gateway** | Kong | Rate limiting, auth, routing |
| **Observability** | Prometheus + Grafana + Jaeger + ELK | Metrics, tracing, logging |
| **Secrets** | HashiCorp Vault | Credential management |
| **Container** | Kubernetes (EKS/GKE) | Auto-scaling, orchestration |
| **CI/CD** | GitHub Actions | Automated deployment |

---

## Table of Contents

1. [Architecture Philosophy](#1-architecture-philosophy)
2. [Technology Stack Details](#2-technology-stack-details)
3. [System Context Diagram](#3-system-context-diagram)
4. [Module Architecture](#4-module-architecture)
   - [4.1 CREATE Module](#41-create-module)
   - [4.2 ACCESS Module](#42-access-module)
   - [4.3 TRAIN Module](#43-train-module)
   - [4.4 CERTIFY Module](#44-certify-module)
5. [API Architecture](#5-api-architecture)
6. [Real-Time Integration Architecture](#6-real-time-integration-architecture)
7. [Data Architecture](#7-data-architecture)
8. [Redis Integration](#8-redis-integration)
9. [Kafka Integration](#9-kafka-integration)
10. [Elasticsearch Integration](#10-elasticsearch-integration)
11. [Workflow Engine (Temporal)](#11-workflow-engine-temporal)
12. [Security Architecture](#12-security-architecture)
13. [Observability Stack](#13-observability-stack)
14. [Infrastructure & Deployment](#14-infrastructure--deployment)
15. [Capacity Planning](#15-capacity-planning)
16. [URS Compliance Verification](#16-urs-compliance-verification)
17. [Implementation Roadmap](#17-implementation-roadmap)
18. [Appendix: Complete Table Mapping](#appendix-complete-table-mapping)

---

## 1. Architecture Philosophy

### 1.1 The Five Pillars (Apple-Level Principles)

| Principle | Implementation | Why It Matters |
|-----------|----------------|----------------|
| **RELIABLE** | No silent failures, retries everywhere, circuit breakers | Pharma can't afford downtime during audits |
| **TRACEABLE** | Every action logged, hash-chained, immutable | FDA requires complete audit trail |
| **FAST** | <100ms API response, <50ms cache hits | User experience = adoption |
| **CLEAN** | Domain-driven design, clear boundaries | Maintainability over 10+ years |
| **SECURE** | Zero-trust, encryption everywhere, MFA | Regulatory requirement |

### 1.2 Design Principles

| Principle | Implementation |
|-----------|----------------|
| **Regulatory-First** | Every transaction is auditable, hash-chained, and e-signature capable |
| **Real-Time by Default** | Redis pub/sub + Kafka for all state changes; webhooks for integrations |
| **Multi-Tenant Isolation** | Row-Level Security (RLS) on every table; organization_id on all records |
| **API-First Design** | RESTful APIs + gRPC for internal services |
| **Immutability for Compliance** | Audit trails, revisions, and signatures are append-only (Kafka) |
| **Event-Driven Architecture** | Domain events published to Kafka for async processing |
| **Horizontal Scalability** | Kubernetes auto-scaling; Redis caching; read replicas |
| **Zero-Trust Security** | JWT validation at gateway; RLS at database; Vault for secrets |

### 1.3 Architecture Decision Records

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ARCHITECTURE DECISION MATRIX                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Decision: Event-Driven Architecture with Kafka                             │
│  ├── Why: Decoupled services, audit trail backbone, replayability          │
│  ├── Trade-off: Eventual consistency vs immediate consistency              │
│  └── Mitigation: Saga pattern for critical workflows (Temporal)            │
│                                                                             │
│  Decision: PostgreSQL as Source of Truth                                    │
│  ├── Why: ACID, compliance-friendly, mature ecosystem                      │
│  ├── Trade-off: Vertical scaling limits                                    │
│  └── Mitigation: Read replicas + Redis caching + partitioning              │
│                                                                             │
│  Decision: Redis for Caching + Session + Pub/Sub                            │
│  ├── Why: Sub-millisecond reads, session store, real-time events          │
│  ├── Trade-off: Additional infrastructure complexity                       │
│  └── Mitigation: Managed Redis (AWS ElastiCache / Upstash)                 │
│                                                                             │
│  Decision: Kafka for Event Streaming & Audit                                │
│  ├── Why: Durability, ordering, 7-year retention for compliance            │
│  ├── Trade-off: Operational complexity                                     │
│  └── Mitigation: Managed Kafka (Confluent Cloud / AWS MSK)                 │
│                                                                             │
│  Decision: Keycloak for Identity & SSO                                      │
│  ├── Why: Enterprise SSO (SAML/OIDC), MFA, FDA-validated deployments       │
│  ├── Trade-off: Heavier than simple auth                                   │
│  └── Mitigation: Managed or containerized deployment                       │
│                                                                             │
│  Decision: Temporal for Workflow Orchestration                              │
│  ├── Why: Durable workflows, versioning, debugging, long-running           │
│  ├── Trade-off: Learning curve                                             │
│  └── Mitigation: Encapsulate in workflow service                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Technology Stack Details

### 2.1 Complete Stack Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ENTERPRISE TECHNOLOGY STACK                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LAYER 1: CLIENT APPLICATIONS                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Web App       │  Mobile App    │  Admin Portal  │  API Clients    │   │
│  │  (Next.js 14)  │  (Flutter)     │  (React Admin) │  (SDK)          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  LAYER 2: EDGE & CDN                                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Cloudflare / AWS CloudFront                                        │   │
│  │  • WAF  • DDoS Protection  • Edge Caching  • SSL/TLS 1.3           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  LAYER 3: API GATEWAY                                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Kong Gateway                                                        │   │
│  │  • Rate Limiting  • JWT Auth  • Routing  • Request Transform        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  LAYER 4: APPLICATION SERVICES (Kubernetes)                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │
│  │  │ CREATE   │ │ ACCESS   │ │ TRAIN    │ │ CERTIFY  │ │ WORKFLOW │ │   │
│  │  │ Service  │ │ Service  │ │ Service  │ │ Service  │ │ Service  │ │   │
│  │  │ (Node.js)│ │ (Node.js)│ │ (Node.js)│ │ (Node.js)│ │(Temporal)│ │   │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ │   │
│  │       │            │            │            │            │        │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐             │   │
│  │  │ NOTIF    │ │ AUDIT    │ │ SEARCH   │ │ REPORT   │             │   │
│  │  │ Service  │ │ Consumer │ │ Indexer  │ │ Service  │             │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘             │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  LAYER 5: DATA & MESSAGING                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │
│  │  │PostgreSQL│ │  Redis   │ │  Kafka   │ │Elasticsrch│ │   S3     │ │   │
│  │  │ Primary  │ │ Cluster  │ │ Cluster  │ │ Cluster  │ │ Storage  │ │   │
│  │  │ +Replica │ │ (Cache)  │ │ (Events) │ │ (Search) │ │ (Files)  │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│  LAYER 6: INFRASTRUCTURE & SECURITY                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │
│  │  │Prometheus│ │ Grafana  │ │  Jaeger  │ │   ELK    │ │  Vault   │ │   │
│  │  │(Metrics) │ │(Dashboard│ │(Tracing) │ │ (Logs)   │ │(Secrets) │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │   │
│  │                                                                     │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐                           │   │
│  │  │ Keycloak │ │Kubernetes│ │ GitHub   │                           │   │
│  │  │   (IdP)  │ │  (K8s)   │ │ Actions  │                           │   │
│  │  └──────────┘ └──────────┘ └──────────┘                           │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Specifications

| Layer | Component | Tool | Purpose | Justification |
|-------|-----------|------|---------|---------------|
| **Identity** | Authentication | Keycloak | SSO, MFA, RBAC | Open source, enterprise-grade, FDA-validated deployments |
| **Identity** | SSO Integration | Keycloak + SAML/OIDC | Azure AD, Okta | Native protocol support |
| **Database** | Primary Store | PostgreSQL 15+ | Source of truth | ACID, audit-friendly, mature |
| **Database** | Read Replicas | PostgreSQL | Scale reads | Offload reporting queries |
| **Cache** | Application Cache | Redis Cluster | Session, API cache | Sub-ms latency, pub/sub |
| **Cache** | CDN Cache | Cloudflare | Static assets | Global edge network |
| **Messaging** | Event Bus | Apache Kafka | Event streaming | Durable, ordered, replayable |
| **Messaging** | Task Queue | BullMQ (Redis) | Background jobs | Simple, reliable, observable |
| **Search** | Full-Text Search | Elasticsearch | Course/SOP search | Fast, scalable, faceted |
| **Storage** | Object Storage | S3 / MinIO | Files, videos | Scalable, versioned |
| **Workflow** | Orchestration | Temporal | Approval flows | Durable, observable, versioned |
| **Gateway** | API Gateway | Kong | Rate limiting, auth | Enterprise features |
| **Observability** | Metrics | Prometheus | System metrics | Industry standard |
| **Observability** | Dashboards | Grafana | Visualization | Flexible, alerting |
| **Observability** | Tracing | Jaeger | Distributed tracing | Request flow visibility |
| **Observability** | Logging | ELK Stack | Log aggregation | Search, analysis |
| **Security** | Secrets | HashiCorp Vault | Credentials | Dynamic secrets, audit |
| **Security** | WAF | Cloudflare WAF | Attack protection | DDoS, injection |
| **Infra** | Container | Docker | Packaging | Consistent deployment |
| **Infra** | Orchestration | Kubernetes | Scaling | Auto-healing, scaling |
| **Infra** | CI/CD | GitHub Actions | Automation | Native integration |

---

## 3. System Context Diagram

```
                                    ┌─────────────────────┐
                                    │   External Systems  │
                                    │  ┌───────────────┐  │
                                    │  │     HRMS      │  │
                                    │  │   (Workday)   │  │
                                    │  └───────┬───────┘  │
                                    │  ┌───────┴───────┐  │
                                    │  │   ERP/QMS     │  │
                                    │  │  (SAP/Veeva)  │  │
                                    │  └───────┬───────┘  │
                                    │  ┌───────┴───────┐  │
                                    │  │   SSO/IdP     │  │
                                    │  │(Azure AD/Okta)│  │
                                    │  └───────┬───────┘  │
                                    │  ┌───────┴───────┐  │
                                    │  │   Biometric   │  │
                                    │  │   Devices     │  │
                                    │  └───────────────┘  │
                                    └─────────┬───────────┘
                                              │
                                              ▼
┌───────────────┐                 ┌───────────────────────┐                 ┌───────────────┐
│               │                 │                       │                 │               │
│   Training    │◄───────────────►│    PHARMALEARN LMS    │◄───────────────►│   Quality     │
│   Managers    │                 │                       │                 │   Assurance   │
│               │                 │  ┌─────┬─────┬─────┐  │                 │               │
└───────────────┘                 │  │ C   │  A  │  T  │  │                 └───────────────┘
                                  │  │ R   │  C  │  R  │  │
┌───────────────┐                 │  │ E   │  C  │  A  │  │                 ┌───────────────┐
│               │                 │  │ A   │  E  │  I  │  │                 │               │
│   Employees   │◄───────────────►│  │ T   │  S  │  N  │  │◄───────────────►│   Regulatory  │
│   (Trainees)  │                 │  │ E   │  S  │  │  │  │                 │   Auditors    │
│               │                 │  └─────┴─────┼─────┤  │                 │               │
└───────────────┘                 │              │CERTI│  │                 └───────────────┘
                                  │              │ FY  │  │
┌───────────────┐                 │              └─────┘  │                 ┌───────────────┐
│               │                 │                       │                 │               │
│   Trainers    │◄───────────────►│ ┌─────────────────┐   │◄───────────────►│   IT Admin    │
│               │                 │ │  Infrastructure │   │                 │               │
└───────────────┘                 │ │  PostgreSQL     │   │                 └───────────────┘
                                  │ │  Redis · Kafka  │   │
                                  │ │  Elasticsearch  │   │
                                  │ │  S3 · Keycloak  │   │
                                  │ └─────────────────┘   │
                                  └───────────────────────┘
                                  │              │ FY  │  │
┌───────────────┐                 │              └─────┘  │                 ┌───────────────┐
│               │                 │                       │                 │               │
│   Trainers    │◄───────────────►│   Supabase Backend    │◄───────────────►│   IT Admin    │
│               │                 │                       │                 │               │
└───────────────┘                 └───────────────────────┘                 └───────────────┘
```

---

## 4. Module Architecture

### 3.1 CREATE Module

**Purpose**: Content creation, document lifecycle, course authoring, question bank management

#### 3.1.1 Capabilities

| Capability | Description | Tables |
|------------|-------------|--------|
| **Document Management** | SOP/WI/Policy creation with version control | `documents`, `document_versions`, `document_categories` |
| **Course Authoring** | Multi-format course design (video, SCORM, xAPI, slides) | `courses`, `course_versions`, `course_topics` |
| **Content Library** | Reusable assets with metadata | `content_assets`, `lessons`, `lesson_content` |
| **Question Banks** | Categorized question repository | `question_banks`, `questions`, `question_options` |
| **Assessment Design** | Configurable question papers | `question_papers`, `question_paper_questions`, `question_paper_sections` |
| **Curriculum Design** | GTPs, learning paths, induction programs | `group_training_plans`, `learning_paths`, `induction_programs` |
| **Knowledge Base** | Searchable KB with versioning | `kb_articles`, `kb_article_versions`, `kb_categories` |
| **Feedback Templates** | Configurable feedback forms | `feedback_templates`, `satisfaction_scales` |
| **Survey Builder** | Pulse/NPS/engagement surveys | `surveys`, `survey_questions` |

#### 3.1.2 CREATE Module — Domain Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            CREATE MODULE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐    │
│  │  DOCUMENTS       │     │  COURSES         │     │  ASSESSMENTS     │    │
│  ├──────────────────┤     ├──────────────────┤     ├──────────────────┤    │
│  │ • documents      │     │ • courses        │     │ • question_banks │    │
│  │ • doc_versions   │     │ • course_versions│     │ • questions      │    │
│  │ • doc_categories │     │ • course_topics  │     │ • question_papers│    │
│  │ • doc_reads      │────►│ • lessons        │────►│ • paper_sections │    │
│  │ • doc_acks       │     │ • lesson_content │     │ • paper_questions│    │
│  └──────────────────┘     └──────────────────┘     └──────────────────┘    │
│           │                        │                        │               │
│           ▼                        ▼                        ▼               │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐    │
│  │  CONTENT ASSETS  │     │  CURRICULA       │     │  KNOWLEDGE BASE  │    │
│  ├──────────────────┤     ├──────────────────┤     ├──────────────────┤    │
│  │ • content_assets │     │ • gtp_masters    │     │ • kb_categories  │    │
│  │ • scorm_packages │     │ • gtp_courses    │     │ • kb_articles    │    │
│  │ • xapi_statements│     │ • learning_paths │     │ • kb_versions    │    │
│  │ • file_storage   │     │ • path_steps     │     │ • kb_feedback    │    │
│  └──────────────────┘     │ • induction_progs│     └──────────────────┘    │
│                           └──────────────────┘                              │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  SUPPORTING: trainers, venues, trainer_courses, feedback_templates  │  │
│  │              subjects, topics, course_categories, surveys           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 3.1.3 CREATE Module — API Endpoints

```yaml
/api/v1/create:
  /documents:
    GET:     List documents (paginated, filtered)
    POST:    Create new document
    /{id}:
      GET:     Get document with current version
      PATCH:   Update document metadata
      DELETE:  Soft delete (with reason)
    /{id}/versions:
      GET:     List all versions
      POST:    Create new version (triggers workflow)
    /{id}/publish:
      POST:    Publish version (requires e-signature)
    /{id}/retire:
      POST:    Retire document (requires approval)
  
  /courses:
    GET:     List courses
    POST:    Create course
    /{id}:
      GET:     Get course with curriculum
      PATCH:   Update course
    /{id}/versions:
      POST:    Create new version
    /{id}/lessons:
      GET/POST: Manage lessons
    /{id}/approve:
      POST:    Submit for approval (e-signature)
  
  /content:
    GET:     List content assets
    POST:    Upload new content (video/SCORM/xAPI)
    /{id}:
      GET:     Get asset with signed URL
      DELETE:  Delete unused asset
    /scorm/{id}/launch:
      GET:     Get SCORM launch parameters
  
  /question-banks:
    GET/POST: List/create banks
    /{id}/questions:
      GET/POST/PUT: Manage questions
    /{id}/import:
      POST:    Bulk import from Excel/CSV
    /{id}/export:
      GET:     Export to Excel
  
  /question-papers:
    GET/POST: List/create papers
    /{id}:
      GET:     Get paper with questions
      PATCH:   Update paper config
    /{id}/sections:
      POST:    Add section
    /{id}/randomize:
      POST:    Generate randomized instance
  
  /curricula:
    /gtps:
      GET/POST: Manage Group Training Plans
    /learning-paths:
      GET/POST: Manage learning paths
    /induction:
      GET/POST: Manage induction programs
  
  /kb:
    /articles:
      GET/POST: List/create articles
      /{id}/versions:
        POST:    New version
    /search:
      GET:     Full-text search (tsvector)
  
  /surveys:
    GET/POST: List/create surveys
    /{id}/questions:
      GET/POST: Manage survey questions
```

#### 3.1.4 CREATE Module — Real-Time Events

| Event | Payload | Subscribers |
|-------|---------|-------------|
| `document.version.created` | `{document_id, version_number, status}` | Workflow engine, Notifications |
| `document.published` | `{document_id, version_id, effective_date}` | Training matrix recalculation |
| `course.approved` | `{course_id, version_id, approved_by}` | GTP scheduler, Assignments |
| `question.created` | `{question_bank_id, question_id}` | Analytics, Search index |
| `content.uploaded` | `{asset_id, type, size}` | Transcoding pipeline |
| `kb.article.updated` | `{article_id, version_number}` | Search reindex |

---

### 3.2 ACCESS Module

**Purpose**: Identity management, authentication, authorization, session control, audit

#### 3.2.1 Capabilities

| Capability | Description | Tables |
|------------|-------------|--------|
| **User Management** | Employee profiles with org hierarchy | `employees`, `global_profiles` |
| **Role-Based Access** | Hierarchical roles with permissions | `roles`, `permissions`, `role_permissions`, `employee_roles` |
| **Group Management** | Groups and subgroups for training assignments | `groups`, `subgroups`, `employee_subgroups`, `group_subgroups` |
| **Authentication** | Password, SSO (SAML/OIDC), biometric | `sso_configurations`, `biometric_registrations` |
| **Session Management** | Session tracking with timeout | `user_sessions`, `session_chains` |
| **Delegation** | Approval delegation and OOO | `approval_delegations`, `out_of_office` |
| **Audit Trail** | Immutable, hash-chained audit log | `audit_trails`, `login_audit_trail` |
| **E-Signatures** | Part 11 compliant signatures | `electronic_signatures`, `signature_meanings` |

#### 3.2.2 ACCESS Module — Domain Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            ACCESS MODULE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐    │
│  │  ORGANIZATION    │     │  IDENTITY        │     │  AUTHORIZATION   │    │
│  ├──────────────────┤     ├──────────────────┤     ├──────────────────┤    │
│  │ • organizations  │────►│ • employees      │────►│ • roles          │    │
│  │ • plants         │     │ • global_profiles│     │ • role_categories│    │
│  │ • departments    │     │ • user_sessions  │     │ • permissions    │    │
│  │                  │     │ • session_chains │     │ • role_permissions    │
│  └──────────────────┘     └──────────────────┘     │ • employee_roles │    │
│                                    │               └──────────────────┘    │
│                                    ▼                        │               │
│  ┌──────────────────┐     ┌──────────────────┐             ▼               │
│  │  AUTHENTICATION  │     │  GROUPS          │     ┌──────────────────┐    │
│  ├──────────────────┤     ├──────────────────┤     │  AUDIT & ESIG    │    │
│  │ • sso_configs    │     │ • groups         │     ├──────────────────┤    │
│  │ • biometric_regs │     │ • subgroups      │     │ • audit_trails   │    │
│  │ • user_credentials    │ • employee_subs   │     │ • login_audit    │    │
│  │ • auth.users     │     │ • group_subgroups│     │ • e_signatures   │    │
│  └──────────────────┘     └──────────────────┘     │ • signature_means│    │
│                                                     │ • data_access_aud│    │
│  ┌──────────────────────────────────────────────┐  └──────────────────┘    │
│  │  DELEGATION: approval_delegations, ooo       │                          │
│  │  JOB: job_responsibilities, standard_reasons │                          │
│  └──────────────────────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 3.2.3 ACCESS Module — API Endpoints

```yaml
/api/v1/access:
  /auth:
    /login:
      POST:    Email/password login (returns JWT + refresh token)
    /logout:
      POST:    Invalidate session
    /refresh:
      POST:    Refresh access token
    /sso/{provider}:
      GET:     Initiate SSO flow
      /callback:
        POST:  SSO callback handler
    /biometric:
      /enroll:
        POST:  Register biometric template
      /verify:
        POST:  Verify biometric for e-signature
    /password:
      /change:
        POST:  Change password (requires old + new)
      /reset:
        POST:  Request password reset
      /reset/{token}:
        POST:  Complete reset with token
    /mfa:
      /setup:
        POST:  Setup MFA (TOTP)
      /verify:
        POST:  Verify MFA code
  
  /users:
    GET:     List employees (org-scoped)
    POST:    Create employee
    /{id}:
      GET:     Get employee profile
      PATCH:   Update employee
      DELETE:  Deactivate employee
    /{id}/roles:
      GET:     Get assigned roles
      POST:    Assign role
      DELETE:  Remove role
    /{id}/permissions:
      GET:     Get effective permissions (computed)
    /{id}/sessions:
      GET:     Active sessions
      DELETE:  Terminate all sessions
    /{id}/impersonate:
      POST:    Impersonate user (admin only, audited)
  
  /roles:
    GET:     List roles
    POST:    Create role
    /{id}:
      GET:     Get role with permissions
      PATCH:   Update role
    /{id}/permissions:
      POST:    Assign permissions
      DELETE:  Remove permissions
    /{id}/clone:
      POST:    Clone role
  
  /groups:
    GET/POST: List/create groups
    /{id}/subgroups:
      GET/POST: Manage subgroups
    /{id}/members:
      GET/POST: Manage members
  
  /delegations:
    GET:     List delegations
    POST:    Create delegation
    /{id}:
      DELETE:  Cancel delegation
  
  /audit:
    /trails:
      GET:     Query audit trails (with filters)
    /logins:
      GET:     Login history
    /access:
      GET:     Data access log
    /export:
      POST:    Export audit log (PDF/CSV)
  
  /esignature:
    /meanings:
      GET:     List signature meanings
    /sign:
      POST:    Create electronic signature
    /verify:
      POST:    Verify signature validity
    /{id}:
      GET:     Get signature details
```

#### 3.2.4 ACCESS Module — Real-Time Events

| Event | Payload | Subscribers |
|-------|---------|-------------|
| `user.session.created` | `{employee_id, session_id, ip}` | Session monitor |
| `user.session.expired` | `{session_id, reason}` | UI auto-logout |
| `user.role.assigned` | `{employee_id, role_id}` | Permission cache invalidation |
| `user.permissions.changed` | `{employee_id, changes[]}` | Real-time UI update |
| `audit.critical` | `{entity_type, action, details}` | Security dashboard |
| `esignature.created` | `{signature_id, entity_type, entity_id}` | Compliance monitor |

---

### 3.3 TRAIN Module

**Purpose**: Training delivery, scheduling, session management, attendance, OJT, induction

#### 3.3.1 Capabilities

| Capability | Description | Tables |
|------------|-------------|--------|
| **Training Planning** | GTP scheduling, calendar management | `training_schedules`, `gtp_masters`, `gtp_courses` |
| **Session Management** | Sessions, batches, invitations | `training_sessions`, `training_batches`, `batch_trainees` |
| **Attendance Tracking** | Biometric/QR/manual with summary | `session_attendance`, `daily_attendance_summary` |
| **Induction Programs** | New employee onboarding | `induction_programs`, `induction_modules`, `induction_enrollments`, `induction_progress` |
| **OJT Management** | On-the-job training with witnessing | `ojt_assignments`, `ojt_tasks`, `ojt_task_completion` |
| **Self-Learning** | Self-paced course enrollment | `self_learning_enrollments`, `self_learning_progress` |
| **Content Delivery** | Lesson progress tracking | `lesson_progress`, `content_view_tracking` |
| **Feedback Collection** | Post-training feedback | `training_feedback`, `trainer_feedback` |
| **Reschedule/Cancel** | Session modifications | `training_reschedules`, `training_cancellations` |

#### 3.3.2 TRAIN Module — Domain Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            TRAIN MODULE                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐    │
│  │  PLANNING        │     │  SCHEDULING      │     │  SESSIONS        │    │
│  ├──────────────────┤     ├──────────────────┤     ├──────────────────┤    │
│  │ • gtp_masters    │────►│ • training_scheds│────►│ • training_sess  │    │
│  │ • gtp_courses    │     │ • schedule_status│     │ • training_batch │    │
│  │ • gtp_versions   │     │                  │     │ • batch_trainees │    │
│  └──────────────────┘     └──────────────────┘     │ • invitations    │    │
│                                                     │ • nominations    │    │
│                                                     └──────────────────┘    │
│                                    │                        │               │
│                                    ▼                        ▼               │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐    │
│  │  INDUCTION       │     │  ATTENDANCE      │     │  DELIVERY        │    │
│  ├──────────────────┤     ├──────────────────┤     ├──────────────────┤    │
│  │ • induction_progs│     │ • session_attend │     │ • lesson_progress│    │
│  │ • induction_mods │     │ • daily_summary  │     │ • content_view   │    │
│  │ • induction_enrol│     │ • biometric_hash │     │ • xapi_statements│    │
│  │ • induction_prog │     │                  │     │ • scorm_cmi      │    │
│  └──────────────────┘     └──────────────────┘     └──────────────────┘    │
│           │                                                 │               │
│           ▼                                                 ▼               │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐    │
│  │  OJT             │     │  SELF-LEARNING   │     │  FEEDBACK        │    │
│  ├──────────────────┤     ├──────────────────┤     ├──────────────────┤    │
│  │ • ojt_assignments│     │ • self_learn_enr │     │ • training_fdbk  │    │
│  │ • ojt_tasks      │     │ • self_learn_prog│     │ • trainer_fdbk   │    │
│  │ • ojt_completion │     │                  │     │ • effectiveness  │    │
│  │ • witnessed_by   │     │                  │     │ • feedback_summ  │    │
│  └──────────────────┘     └──────────────────┘     └──────────────────┘    │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  MODIFICATIONS: training_reschedules, training_cancellations         │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 3.3.3 TRAIN Module — API Endpoints

```yaml
/api/v1/train:
  /gtps:
    GET:     List Group Training Plans
    POST:    Create GTP
    /{id}:
      GET:     Get GTP with courses
      PATCH:   Update GTP
    /{id}/courses:
      POST:    Add course to GTP
    /{id}/generate-schedule:
      POST:    Generate training schedule
    /{id}/activate:
      POST:    Activate GTP (requires approval)
  
  /schedules:
    GET:     List schedules (calendar view)
    POST:    Create schedule
    /{id}:
      GET:     Get schedule details
      PATCH:   Update schedule
    /{id}/sessions:
      POST:    Create session from schedule
  
  /sessions:
    GET:     List sessions (with filters)
    POST:    Create session
    /{id}:
      GET:     Get session with attendance
      PATCH:   Update session
    /{id}/batches:
      POST:    Create batch
      GET:     List batches
    /{id}/invite:
      POST:    Send invitations
    /{id}/start:
      POST:    Start session
    /{id}/end:
      POST:    End session
    /{id}/reschedule:
      POST:    Reschedule (requires reason)
    /{id}/cancel:
      POST:    Cancel session (requires reason + approval)
  
  /batches:
    /{id}:
      GET:     Get batch with trainees
    /{id}/trainees:
      POST:    Add trainees
      DELETE:  Remove trainee
  
  /attendance:
    /check-in:
      POST:    Record check-in (biometric/QR/manual)
    /check-out:
      POST:    Record check-out
    /session/{id}:
      GET:     Get session attendance
      PATCH:   Update attendance (admin override)
    /summary:
      GET:     Attendance summary report
  
  /induction:
    /programs:
      GET:     List induction programs
    /enrollments:
      GET:     My induction enrollments
      POST:    Enroll employee (auto or manual)
    /{enrollment_id}/modules/{module_id}:
      POST:    Complete module
    /{enrollment_id}/complete:
      POST:    Complete induction
  
  /ojt:
    /assignments:
      GET:     List OJT assignments
      POST:    Create OJT assignment
    /{id}/tasks:
      GET:     List OJT tasks
    /{id}/tasks/{task_id}/complete:
      POST:    Complete task (with witness signature)
    /{id}/signoff:
      POST:    Supervisor sign-off
  
  /self-learning:
    /catalog:
      GET:     Available self-learning courses
    /enroll:
      POST:    Request enrollment
    /enrollments:
      GET:     My enrollments
    /{id}/progress:
      GET:     Get progress
      POST:    Update progress
    /{id}/complete:
      POST:    Mark complete
  
  /content:
    /lessons/{id}/start:
      POST:    Start lesson (creates progress)
    /lessons/{id}/progress:
      PATCH:   Update lesson progress
    /lessons/{id}/complete:
      POST:    Complete lesson
    /scorm/{id}/initialize:
      POST:    Initialize SCORM session
    /scorm/{id}/commit:
      POST:    Commit SCORM data
    /xapi/statements:
      POST:    Record xAPI statement(s)
  
  /feedback:
    /submit:
      POST:    Submit training feedback
    /session/{id}:
      GET:     Get session feedback summary
    /effectiveness/{session_id}:
      GET:     Get Kirkpatrick evaluation
      POST:    Record effectiveness evaluation
```

#### 3.3.4 TRAIN Module — Real-Time Events

| Event | Payload | Subscribers |
|-------|---------|-------------|
| `session.started` | `{session_id, trainer_id, start_time}` | Attendee notifications |
| `session.ended` | `{session_id, attendance_summary}` | Certificate generation |
| `attendance.checkin` | `{session_id, employee_id, method}` | Live dashboard |
| `attendance.checkout` | `{session_id, employee_id, duration}` | Compliance tracker |
| `lesson.progress.updated` | `{employee_id, lesson_id, percent}` | Progress dashboard |
| `ojt.task.completed` | `{assignment_id, task_id, witnessed_by}` | Supervisor notification |
| `induction.completed` | `{enrollment_id, employee_id}` | HR notification, Badge award |

---

### 3.4 CERTIFY Module

**Purpose**: Assessment execution, grading, certification, compliance tracking, competency management

#### 3.4.1 Capabilities

| Capability | Description | Tables |
|------------|-------------|--------|
| **Assessment Delivery** | Proctored/unproctored assessments | `assessment_attempts`, `assessment_responses`, `assessment_proctoring` |
| **Auto-Grading** | MCQ/TF/blanks auto-grading | `assessment_results`, `grading_queue` |
| **Manual Grading** | Descriptive answer grading | `grading_queue`, `grader_assignments` |
| **Result Appeals** | Appeal and review process | `result_appeals` |
| **Training Records** | Immutable compliance records | `training_records`, `training_record_items` |
| **Certification** | Certificate generation with QR | `certificates`, `certificate_templates`, `certificate_signatures` |
| **Competency Tracking** | Role vs employee competencies | `competencies`, `role_competencies`, `employee_competencies`, `competency_gaps` |
| **Training Matrix** | Role-course mandatory mapping | `training_matrix`, `training_matrix_items` |
| **Waivers & Exemptions** | Training requirement exceptions | `training_waivers`, `training_exemptions`, `waiver_approvals` |
| **Assignments** | Training assignments with deadlines | `training_assignments`, `employee_assignments` |
| **Compliance Reports** | Regulatory compliance reporting | `compliance_reports`, `report_definitions` |

#### 3.4.2 CERTIFY Module — Domain Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CERTIFY MODULE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐    │
│  │  ASSESSMENT      │     │  GRADING         │     │  RESULTS         │    │
│  ├──────────────────┤     ├──────────────────┤     ├──────────────────┤    │
│  │ • assess_attempts│────►│ • assess_respons │────►│ • assess_results │    │
│  │ • assess_proctor │     │ • grading_queue  │     │ • result_appeals │    │
│  │ • activity_log   │     │ • grader_assign  │     │ • pass_status    │    │
│  └──────────────────┘     └──────────────────┘     └──────────────────┘    │
│                                                             │               │
│                                                             ▼               │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐    │
│  │  TRAINING RECORDS│     │  CERTIFICATES    │     │  ASSIGNMENTS     │    │
│  ├──────────────────┤     ├──────────────────┤     ├──────────────────┤    │
│  │ • training_recs  │────►│ • certificates   │     │ • train_assignmt │    │
│  │ • record_items   │     │ • cert_templates │     │ • emp_assignments│    │
│  │ • tr_type        │     │ • cert_signatures│     │ • assignment_stat│    │
│  │                  │     │ • cert_verify    │     │                  │    │
│  └──────────────────┘     └──────────────────┘     └──────────────────┘    │
│           ▲                                                 │               │
│           │                                                 ▼               │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐    │
│  │  TRAINING MATRIX │     │  WAIVERS         │     │  COMPETENCIES    │    │
│  ├──────────────────┤     ├──────────────────┤     ├──────────────────┤    │
│  │ • training_matrix│     │ • train_waivers  │     │ • competencies   │    │
│  │ • matrix_items   │     │ • train_exempt   │     │ • role_competen  │    │
│  │ • recurrence     │     │ • waiver_approves│     │ • emp_competenc  │    │
│  │ • is_mandatory   │     │ • exempt_emp     │     │ • competency_gaps│    │
│  └──────────────────┘     └──────────────────┘     └──────────────────┘    │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  REPORTING: compliance_reports, report_definitions, scheduled_reports│  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 3.4.3 CERTIFY Module — API Endpoints

```yaml
/api/v1/certify:
  /assessments:
    /available:
      GET:     Available assessments for current user
    /start:
      POST:    Start assessment attempt
    /attempts/{id}:
      GET:     Get attempt status
      POST:    Submit responses
      /submit:
        POST:  Submit attempt
      /activity:
        POST:  Log proctoring activity
    /results:
      GET:     My assessment results
      /{id}:
        GET:     Get detailed result
    /appeals:
      POST:    Submit appeal
      /{id}:
        GET:     Get appeal status
        /review:
          POST:  Review appeal (grader)
  
  /grading:
    /queue:
      GET:     Get grading queue (for graders)
    /assign:
      POST:    Assign responses to grader
    /grade:
      POST:    Submit grade for response
    /batch-grade:
      POST:    Batch grade multiple responses
  
  /records:
    GET:     List training records
    /{id}:
      GET:     Get training record details
    /export:
      POST:    Export records (PDF/CSV)
    /employee/{id}:
      GET:     Get employee's training history
    /verify:
      POST:    Verify training record authenticity
  
  /certificates:
    GET:     List certificates
    /{id}:
      GET:     Get certificate details
      /download:
        GET:   Download certificate PDF
      /verify:
        GET:   Verify certificate (public)
    /generate:
      POST:    Generate certificate (manual)
    /revoke:
      POST:    Revoke certificate (requires two-person)
    /templates:
      GET/POST: Manage templates
  
  /competencies:
    GET:     List competencies
    POST:    Create competency
    /{id}:
      GET:     Get competency with role mappings
    /role/{role_id}:
      GET:     Get required competencies for role
      POST:    Map competency to role
    /employee/{id}:
      GET:     Get employee competency profile
      POST:    Update employee competency
    /gaps:
      GET:     Get competency gap report
      POST:    Calculate gaps
  
  /matrix:
    GET:     Get training matrix
    POST:    Create matrix entry
    /{id}:
      PATCH:   Update matrix entry
      DELETE:  Remove matrix entry
    /calculate:
      POST:    Calculate assignments from matrix
  
  /assignments:
    GET:     List assignments
    POST:    Create assignment
    /{id}:
      GET:     Get assignment details
      PATCH:   Update assignment
    /employee/{id}:
      GET:     Get employee assignments
    /overdue:
      GET:     Get overdue assignments
  
  /waivers:
    GET:     List waivers
    POST:    Request waiver
    /{id}:
      GET:     Get waiver details
      /approve:
        POST:  Approve waiver (requires e-signature)
      /reject:
        POST:  Reject waiver
  
  /exemptions:
    GET:     List exemptions
    POST:    Create exemption
    /{id}/employees:
      POST:    Add employees to exemption
  
  /compliance:
    /dashboard:
      GET:     Get compliance dashboard data
    /status:
      GET:     Get compliance status (org/plant/dept)
    /reports:
      GET:     List compliance reports
      POST:    Generate report
      /schedule:
        POST:  Schedule recurring report
    /audit-readiness:
      GET:     Get audit readiness report
```

#### 3.4.4 CERTIFY Module — Real-Time Events

| Event | Payload | Subscribers |
|-------|---------|-------------|
| `assessment.started` | `{attempt_id, employee_id, paper_id}` | Proctoring dashboard |
| `assessment.submitted` | `{attempt_id, auto_graded}` | Grading queue |
| `assessment.graded` | `{attempt_id, result_id, pass_status}` | Employee notification |
| `certificate.issued` | `{certificate_id, employee_id, course_id}` | Employee, Manager, HR |
| `certificate.revoked` | `{certificate_id, reason}` | Compliance team |
| `assignment.due_soon` | `{assignment_id, employee_id, days_remaining}` | Reminder service |
| `assignment.overdue` | `{assignment_id, employee_id}` | Escalation service |
| `competency.gap.identified` | `{employee_id, competency_id, gap_size}` | Training planner |
| `compliance.threshold.breach` | `{org_id, plant_id, percent}` | Executive dashboard |

---

## 5. API Architecture

### 4.1 API Design Principles

| Principle | Implementation |
|-----------|----------------|
| **RESTful Design** | Resource-oriented URLs, HTTP verbs, status codes |
| **Versioning** | URL path versioning (`/api/v1/`) |
| **Pagination** | Cursor-based with `limit` and `cursor` params |
| **Filtering** | Query params with operators (`?status=eq.active`) |
| **Sorting** | `order` param (`?order=created_at.desc`) |
| **Partial Response** | `select` param for field selection |
| **Error Format** | RFC 7807 Problem Details |
| **Rate Limiting** | Per-endpoint, per-organization limits |

### 4.2 API Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              API GATEWAY LAYER                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  Kong / Supabase Edge                                                   │ │
│  │  • Rate limiting (api_rate_limits table)                                │ │
│  │  • JWT validation                                                       │ │
│  │  • Request/Response logging                                             │ │
│  │  • CORS handling                                                        │ │
│  │  • Request transformation                                               │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│                              ROUTING LAYER                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  /api/v1/create/*  ────► PostgREST + Edge Functions                    │ │
│  │  /api/v1/access/*  ────► GoTrue + Edge Functions                       │ │
│  │  /api/v1/train/*   ────► PostgREST + Edge Functions                    │ │
│  │  /api/v1/certify/* ────► PostgREST + Edge Functions                    │ │
│  │                                                                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│                              SERVICE LAYER                                   │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌─────────────┐  │
│  │   PostgREST   │  │  Edge Funcs   │  │   GoTrue      │  │  Realtime   │  │
│  │   (Auto API)  │  │  (Workflows)  │  │   (Auth)      │  │  (WS)       │  │
│  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘  └──────┬──────┘  │
│          │                  │                  │                 │          │
├──────────┴──────────────────┴──────────────────┴─────────────────┴──────────┤
│                              DATA LAYER                                      │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                     PostgreSQL 15+ with RLS                             │ │
│  │  • 170+ tables across 4 modules                                         │ │
│  │  • Row-Level Security on every table                                    │ │
│  │  • Triggers for audit trails                                            │ │
│  │  • Functions for complex operations                                     │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Edge Functions Architecture

```typescript
// supabase/functions/structure
functions/
├── _shared/                    # Shared utilities
│   ├── db.ts                   # Database client
│   ├── auth.ts                 # Auth helpers
│   ├── esignature.ts           # E-signature verification
│   ├── audit.ts                # Audit trail helpers
│   └── webhook.ts              # Webhook dispatcher
│
├── auth-hook/                  # Auth event handlers
│   └── index.ts
│
├── create/                     # CREATE module functions
│   ├── publish-document/
│   ├── approve-course/
│   ├── transcode-content/
│   └── import-questions/
│
├── access/                     # ACCESS module functions
│   ├── esignature-verify/
│   ├── biometric-enroll/
│   ├── session-validate/
│   └── impersonate/
│
├── train/                      # TRAIN module functions
│   ├── start-session/
│   ├── end-session/
│   ├── check-in/
│   ├── scorm-handler/
│   └── xapi-handler/
│
├── certify/                    # CERTIFY module functions
│   ├── start-assessment/
│   ├── submit-assessment/
│   ├── auto-grade/
│   ├── generate-certificate/
│   ├── revoke-certificate/
│   └── calculate-compliance/
│
├── notifications/              # Cross-cutting
│   ├── send-notification/
│   ├── process-escalations/
│   └── digest-builder/
│
├── webhooks/                   # Outbound webhooks
│   ├── dispatch/
│   └── retry-failed/
│
└── integrations/               # External integrations
    ├── hrms-sync/
    ├── sso-callback/
    └── biometric-verify/
```

### 4.4 Request/Response Patterns

#### 4.4.1 Standard Success Response

```json
{
  "data": { /* resource or array */ },
  "meta": {
    "pagination": {
      "cursor": "eyJpZCI6IjEyMyJ9",
      "has_more": true,
      "total_count": 150
    },
    "request_id": "req_abc123xyz"
  }
}
```

#### 4.4.2 Error Response (RFC 7807)

```json
{
  "type": "https://pharmalearn.io/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "The request body contains invalid fields",
  "instance": "/api/v1/train/sessions/123",
  "errors": [
    {
      "field": "scheduled_start",
      "message": "must be a future date"
    }
  ],
  "request_id": "req_abc123xyz",
  "timestamp": "2026-04-23T10:30:00Z"
}
```

### 4.5 Rate Limiting Configuration

```sql
-- Example rate limit entries (from api_rate_limits table)
INSERT INTO api_rate_limits (endpoint_pattern, http_method, limit_per_minute, limit_per_hour, burst_limit, priority) VALUES
-- Critical endpoints (stricter limits)
('/api/v1/access/auth/login', 'POST', 10, 100, 5, 10),
('/api/v1/access/esignature/sign', 'POST', 20, 200, 10, 10),
('/api/v1/certify/certificates/generate', 'POST', 30, 500, 15, 20),

-- High-traffic endpoints
('/api/v1/train/attendance/check-in', 'POST', 120, 2000, 50, 30),
('/api/v1/train/content/lessons/*/progress', 'PATCH', 300, 10000, 100, 40),

-- Standard endpoints
('/api/v1/create/*', '*', 60, 1000, 30, 100),
('/api/v1/train/*', '*', 100, 2000, 50, 100),
('/api/v1/certify/*', '*', 80, 1500, 40, 100),

-- Bulk operations
('/api/v1/*/import', 'POST', 5, 50, 2, 50),
('/api/v1/*/export', 'POST', 10, 100, 5, 50);
```

---

## 6. Real-Time Integration Architecture

### 5.1 Supabase Realtime Channels

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         REALTIME ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                    REALTIME CHANNEL STRUCTURE                           ││
│  │                                                                         ││
│  │  org:{org_id}                    # Organization-wide events             ││
│  │  ├── plant:{plant_id}            # Plant-specific events                ││
│  │  │   ├── sessions                # Training session updates             ││
│  │  │   ├── attendance              # Live attendance feed                 ││
│  │  │   └── compliance              # Compliance status changes            ││
│  │  │                                                                      ││
│  │  user:{employee_id}              # User-specific events                 ││
│  │  ├── notifications               # Personal notifications               ││
│  │  ├── assignments                 # Assignment updates                   ││
│  │  ├── progress                    # Learning progress                    ││
│  │  └── approvals                   # Pending approval tasks               ││
│  │                                                                         ││
│  │  session:{session_id}            # Session-specific (training room)     ││
│  │  ├── attendance                  # Check-in/out events                  ││
│  │  ├── content                     # Content sync for live sessions       ││
│  │  └── chat                        # Session Q&A                          ││
│  │                                                                         ││
│  │  assessment:{attempt_id}         # Assessment-specific                  ││
│  │  ├── proctoring                  # Proctoring events                    ││
│  │  └── time                        # Timer sync                           ││
│  │                                                                         ││
│  │  admin:global                    # Admin-only global events             ││
│  │  ├── system                      # System health                        ││
│  │  ├── security                    # Security alerts                      ││
│  │  └── compliance                  # Critical compliance breaches         ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Database Triggers for Real-Time Events

```sql
-- Trigger to broadcast real-time events via pg_notify
CREATE OR REPLACE FUNCTION broadcast_realtime_event()
RETURNS TRIGGER AS $$
DECLARE
    channel TEXT;
    payload JSONB;
BEGIN
    -- Determine channel based on table
    CASE TG_TABLE_NAME
        WHEN 'session_attendance' THEN
            channel := format('org:%s:plant:%s:attendance', NEW.organization_id, NEW.plant_id);
            payload := jsonb_build_object(
                'event', 'attendance.' || TG_OP,
                'session_id', NEW.session_id,
                'employee_id', NEW.employee_id,
                'action', CASE WHEN NEW.check_out_at IS NOT NULL THEN 'checkout' ELSE 'checkin' END,
                'timestamp', NOW()
            );
        WHEN 'training_sessions' THEN
            channel := format('org:%s:sessions', NEW.organization_id);
            payload := jsonb_build_object(
                'event', 'session.' || LOWER(TG_OP),
                'session_id', NEW.id,
                'status', NEW.status,
                'timestamp', NOW()
            );
        WHEN 'user_notifications' THEN
            channel := format('user:%s:notifications', NEW.employee_id);
            payload := jsonb_build_object(
                'event', 'notification.new',
                'notification_id', NEW.id,
                'title', NEW.title,
                'timestamp', NOW()
            );
        WHEN 'pending_approvals' THEN
            channel := format('user:%s:approvals', NEW.current_approver_id);
            payload := jsonb_build_object(
                'event', 'approval.pending',
                'approval_id', NEW.id,
                'entity_type', NEW.entity_type,
                'timestamp', NOW()
            );
        ELSE
            RETURN NEW;
    END CASE;

    -- Publish to Realtime via pg_notify
    PERFORM pg_notify('realtime:' || channel, payload::TEXT);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 5.3 Webhook Delivery Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        WEBHOOK DELIVERY PIPELINE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────┐    ┌──────────────┐    ┌───────────────┐    ┌─────────────┐  │
│   │ Event   │───►│ events_outbox│───►│ Webhook       │───►│ webhook_    │  │
│   │ Trigger │    │ (table)      │    │ Dispatcher    │    │ deliveries  │  │
│   └─────────┘    └──────────────┘    │ (Edge Func)   │    └─────────────┘  │
│                                      └───────┬───────┘                      │
│                                              │                              │
│                                              ▼                              │
│                                      ┌───────────────┐                      │
│                                      │ webhook_      │                      │
│                                      │ subscriptions │                      │
│                                      │ (filter +     │                      │
│                                      │  match)       │                      │
│                                      └───────┬───────┘                      │
│                                              │                              │
│                        ┌─────────────────────┼─────────────────────┐        │
│                        ▼                     ▼                     ▼        │
│                 ┌───────────┐         ┌───────────┐         ┌───────────┐  │
│                 │ Target A  │         │ Target B  │         │ Target C  │  │
│                 │ (HRMS)    │         │ (QMS)     │         │ (Custom)  │  │
│                 └───────────┘         └───────────┘         └───────────┘  │
│                                                                             │
│   Retry Policy: Exponential backoff (2, 4, 8, 16, 32... up to 3600 sec)    │
│   Max Retries: 3 (configurable per webhook)                                 │
│   Auto-disable: After 10 consecutive failures                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.4 Event Catalog

| Domain | Event Type | Payload Schema | Subscribers |
|--------|------------|----------------|-------------|
| **CREATE** | `document.published` | `{document_id, version_id, effective_date}` | Training assignments, Notifications |
| | `course.approved` | `{course_id, version_id, approved_by}` | GTP scheduler |
| | `content.transcoded` | `{asset_id, formats[], thumbnail_url}` | Course builder |
| **ACCESS** | `user.created` | `{employee_id, org_id, roles[]}` | HRMS sync, Induction trigger |
| | `user.deactivated` | `{employee_id, reason}` | Session termination |
| | `session.timeout` | `{session_id, employee_id}` | Audit |
| **TRAIN** | `session.started` | `{session_id, trainer_id, attendees[]}` | Live dashboard |
| | `session.ended` | `{session_id, summary}` | Certificate generation |
| | `attendance.recorded` | `{session_id, employee_id, method}` | Compliance tracker |
| | `ojt.task.completed` | `{assignment_id, task_id, witnessed_by}` | Progress tracker |
| **CERTIFY** | `assessment.submitted` | `{attempt_id, score, pass_status}` | Notifications, Records |
| | `certificate.issued` | `{certificate_id, employee_id, course_id}` | Compliance dashboard |
| | `certificate.revoked` | `{certificate_id, reason, revoked_by[]}` | Audit, Notifications |
| | `compliance.alert` | `{org_id, plant_id, metric, threshold}` | Executive dashboard |

---

## 7. Data Architecture

### 6.1 Table Distribution by Module

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DATA ARCHITECTURE OVERVIEW                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                          CREATE MODULE (~35 tables)                    │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │ Documents    │ Courses       │ Content       │ Assessments  │ KB      │  │
│  │ 5 tables     │ 11 tables     │ 7 tables      │ 8 tables     │ 6 tables│  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                          ACCESS MODULE (~25 tables)                    │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │ Identity     │ Roles/Perms   │ Groups        │ Auth         │ Audit   │  │
│  │ 8 tables     │ 5 tables      │ 4 tables      │ 4 tables     │ 5 tables│  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                          TRAIN MODULE (~30 tables)                     │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │ GTPs/Sched   │ Sessions      │ Induction     │ OJT          │ Feedback│  │
│  │ 5 tables     │ 10 tables     │ 5 tables      │ 4 tables     │ 5 tables│  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         CERTIFY MODULE (~25 tables)                    │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │ Assessments  │ Records       │ Certificates  │ Competencies │ Matrix  │  │
│  │ 5 tables     │ 5 tables      │ 5 tables      │ 5 tables     │ 5 tables│  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     CROSS-CUTTING (~55 tables)                         │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │ Core         │ Config        │ Workflow      │ Notifications│ Infra   │  │
│  │ 10 tables    │ 10 tables     │ 8 tables      │ 7 tables     │ 10 tables│ │
│  │              │               │               │              │          │ │
│  │ Extensions   │ Analytics     │ Quality       │ Cron         │          │ │
│  │ 34 tables    │ 8 tables      │ 11 tables     │ 4 tables     │          │ │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│                           TOTAL: ~170 TABLES                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Key Data Flows

#### 6.2.1 Training Lifecycle Flow

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│    CREATE     │     │    TRAIN      │     │   CERTIFY     │     │   ACCESS      │
│               │     │               │     │               │     │               │
│   courses     │────►│ gtp_masters   │────►│ assess_       │────►│ training_     │
│   documents   │     │ training_     │     │   attempts    │     │   records     │
│   question_   │     │   schedules   │     │               │     │               │
│   banks       │     │ training_     │     │ assess_       │     │ certificates  │
│               │     │   sessions    │     │   results     │     │               │
│               │     │               │     │               │     │ competencies  │
│               │     │ attendance    │     │               │     │               │
└───────────────┘     └───────────────┘     └───────────────┘     └───────────────┘
         │                    │                    │                      │
         ▼                    ▼                    ▼                      ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │                         CROSS-CUTTING LAYER                              │
    │                                                                         │
    │  audit_trails  ◄──────────────────────────────────────────────────────► │
    │  electronic_signatures  ◄─────────────────────────────────────────────► │
    │  workflow_instances  ◄────────────────────────────────────────────────► │
    │  notification_queue  ◄────────────────────────────────────────────────► │
    │                                                                         │
    └─────────────────────────────────────────────────────────────────────────┘
```

#### 6.2.2 Compliance Flow

```
                              COMPLIANCE TRACKING FLOW
                              
 ┌─────────────────┐
 │ training_matrix │──────────────────────────────────────────────────────┐
 │ (role+course    │                                                      │
 │  requirements)  │                                                      ▼
 └────────┬────────┘                                          ┌───────────────────┐
          │                                                   │ employee_         │
          ▼                                                   │ assignments       │
 ┌─────────────────┐     ┌─────────────────┐                 └─────────┬─────────┘
 │ employee_roles  │────►│ CALCULATE       │                           │
 │ (current roles) │     │ REQUIREMENTS    │──────────────────────────►│
 └─────────────────┘     └─────────────────┘                           │
                                                                        ▼
 ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   │
 │ training_       │────►│ CHECK           │◄────│ training_       │◄──┘
 │ records         │     │ COMPLIANCE      │     │ assignments     │
 │ (completed)     │     │                 │     │ (required)      │
 └─────────────────┘     └────────┬────────┘     └─────────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ COMPLIANCE      │
                         │ DASHBOARD       │
                         │                 │
                         │ • % Complete    │
                         │ • Overdue count │
                         │ • Gap analysis  │
                         └─────────────────┘
```

### 6.3 Indexing Strategy

```sql
-- High-cardinality columns with frequent lookups
CREATE INDEX CONCURRENTLY idx_employees_org_active ON employees(organization_id, is_active);
CREATE INDEX CONCURRENTLY idx_employees_plant_dept ON employees(plant_id, department_id);

-- Training records for compliance queries
CREATE INDEX CONCURRENTLY idx_training_records_emp_status ON training_records(employee_id, pass_status);
CREATE INDEX CONCURRENTLY idx_training_records_course_date ON training_records(course_id, completed_at DESC);

-- Attendance for real-time dashboards
CREATE INDEX CONCURRENTLY idx_attendance_session_date ON session_attendance(session_id, check_in_at);

-- Audit trails for compliance queries
CREATE INDEX CONCURRENTLY idx_audit_entity ON audit_trails(entity_type, entity_id);
CREATE INDEX CONCURRENTLY idx_audit_performed ON audit_trails(performed_at DESC);
CREATE INDEX CONCURRENTLY idx_audit_hash_chain ON audit_trails(prev_hash) WHERE prev_hash IS NOT NULL;

-- Full-text search
CREATE INDEX CONCURRENTLY idx_kb_search ON kb_articles USING GIN(search_vector);
CREATE INDEX CONCURRENTLY idx_courses_search ON courses USING GIN(to_tsvector('english', course_name || ' ' || COALESCE(description, '')));

-- Workflow queries
CREATE INDEX CONCURRENTLY idx_pending_approvals_approver ON pending_approvals(current_approver_id, status);
CREATE INDEX CONCURRENTLY idx_workflow_instances_entity ON workflow_instances(related_entity_type, related_entity_id);
```

### 6.4 Partitioning Strategy

```sql
-- Audit trails partitioned by month for performance
CREATE TABLE audit_trails (
    id UUID DEFAULT uuid_generate_v4(),
    performed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- ... other columns
) PARTITION BY RANGE (performed_at);

-- Create partitions automatically via pg_cron
CREATE TABLE audit_trails_2026_04 PARTITION OF audit_trails
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
    
CREATE TABLE audit_trails_2026_05 PARTITION OF audit_trails
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- xAPI statements (high volume) partitioned by month
CREATE TABLE xapi_statements (
    id UUID DEFAULT uuid_generate_v4(),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- ... other columns
) PARTITION BY RANGE (timestamp);
```

---

## 8. Redis Integration

### 8.1 Redis Use Cases

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          REDIS USE CASES                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. SESSION MANAGEMENT                                                      │
│     ├── Store user sessions with automatic expiry                          │
│     ├── Session chain tracking for e-signatures                            │
│     └── Device fingerprint validation                                       │
│                                                                             │
│  2. API RESPONSE CACHING                                                    │
│     ├── Cache frequently accessed data (courses, employees)                │
│     ├── Permission cache per user                                          │
│     └── TTL: 5-30 minutes (configurable)                                   │
│                                                                             │
│  3. RATE LIMITING                                                           │
│     ├── Sliding window rate limiting per user/endpoint                     │
│     ├── IP-based rate limiting for anonymous endpoints                     │
│     └── Burst protection for critical endpoints                            │
│                                                                             │
│  4. REAL-TIME PRESENCE                                                      │
│     ├── Track online users per training session                            │
│     ├── Typing indicators in discussions                                   │
│     └── Online status for employees                                        │
│                                                                             │
│  5. DISTRIBUTED LOCKS                                                       │
│     ├── Certificate generation (prevent duplicates)                        │
│     ├── Report generation                                                  │
│     └── Integration sync jobs                                              │
│                                                                             │
│  6. PUB/SUB FOR REAL-TIME EVENTS                                            │
│     ├── Attendance events broadcast                                        │
│     ├── Notification delivery                                              │
│     └── Progress updates                                                   │
│                                                                             │
│  7. TASK QUEUES (BullMQ)                                                    │
│     ├── Email sending                                                      │
│     ├── Report generation                                                  │
│     └── Data sync jobs                                                     │
│                                                                             │
│  8. LEADERBOARDS (Gamification)                                             │
│     ├── Points leaderboards (ZSET)                                         │
│     └── Completion rankings                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 Redis Key Schema

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          REDIS KEY SCHEMA                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  SESSION MANAGEMENT                                                         │
│  ├── session:{jwt_id}                    → HASH (user session data)        │
│  ├── session_chain:{employee_id}         → LIST (signature chain)          │
│  └── active_sessions:{employee_id}       → SET (all active sessions)       │
│                                                                             │
│  CACHING (TTL: 5-30 min)                                                    │
│  ├── cache:org:{org_id}:courses          → STRING (JSON)                   │
│  ├── cache:org:{org_id}:employees        → STRING (JSON)                   │
│  ├── cache:employee:{emp_id}:permissions → SET (permission codes)          │
│  ├── cache:course:{course_id}            → STRING (JSON)                   │
│  └── cache:qb:{qb_id}:questions          → STRING (JSON)                   │
│                                                                             │
│  RATE LIMITING                                                              │
│  ├── ratelimit:{user_id}:{endpoint}      → STRING (counter)                │
│  └── ratelimit:ip:{ip_address}           → STRING (counter)                │
│                                                                             │
│  REAL-TIME                                                                  │
│  ├── presence:session:{session_id}       → SET (online user IDs)           │
│  ├── typing:thread:{thread_id}           → SET (typing user IDs)           │
│  └── online:org:{org_id}                 → SET (online user IDs)           │
│                                                                             │
│  DISTRIBUTED LOCKS                                                          │
│  ├── lock:certificate:{cert_id}          → STRING (1)                      │
│  ├── lock:report:{report_id}             → STRING (1)                      │
│  └── lock:sync:{integration_id}          → STRING (1)                      │
│                                                                             │
│  QUEUES (BullMQ)                                                            │
│  ├── bull:notifications:*                → BullMQ internal                 │
│  ├── bull:reports:*                      → BullMQ internal                 │
│  └── bull:sync:*                         → BullMQ internal                 │
│                                                                             │
│  ANALYTICS                                                                  │
│  ├── leaderboard:org:{org_id}:monthly    → ZSET (scores)                   │
│  ├── metrics:api:latency                 → STREAM (time-series)            │
│  └── counter:logins:daily:{date}         → HASH (by org)                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.3 Redis Implementation Examples

```typescript
// Redis client configuration
import Redis from 'ioredis';

const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: 6379,
  password: process.env.REDIS_PASSWORD,
  maxRetriesPerRequest: 3,
  retryDelayOnFailover: 100,
});

// 1. SESSION MANAGEMENT
interface UserSession {
  employeeId: string;
  organizationId: string;
  roles: string[];
  permissions: string[];
  lastActivity: number;
  deviceFingerprint: string;
}

// Store session (30 min TTL)
await redis.setex(`session:${jwtId}`, 1800, JSON.stringify(session));

// Get session
const session = JSON.parse(await redis.get(`session:${jwtId}`));

// 2. API RESPONSE CACHING
await redis.setex(`cache:org:${orgId}:courses`, 300, JSON.stringify(courses));
const cached = await redis.get(`cache:org:${orgId}:courses`);

// 3. RATE LIMITING (sliding window)
async function checkRateLimit(userId: string, endpoint: string, limit: number): Promise<boolean> {
  const key = `ratelimit:${userId}:${endpoint}`;
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, 60);
  return count <= limit;
}

// 4. DISTRIBUTED LOCK
async function acquireLock(resource: string, ttl: number): Promise<boolean> {
  const result = await redis.set(`lock:${resource}`, '1', 'NX', 'EX', ttl);
  return result === 'OK';
}

// 5. PUB/SUB
await redis.publish(`org:${orgId}:attendance`, JSON.stringify({
  type: 'checkin',
  sessionId,
  employeeId,
  timestamp: Date.now()
}));

// 6. LEADERBOARD
await redis.zincrby(`leaderboard:org:${orgId}:monthly`, points, `employee:${empId}`);
const top10 = await redis.zrevrange(`leaderboard:org:${orgId}:monthly`, 0, 9, 'WITHSCORES');
```

---

## 9. Kafka Integration

### 9.1 Kafka Topics

```yaml
# Kafka topic configuration
topics:
  # Domain events (source of truth for audit)
  - name: pharmalearn.events.create
    partitions: 12
    replication: 3
    retention: 7d
    compaction: false
    
  - name: pharmalearn.events.access
    partitions: 12
    replication: 3
    retention: 7d
    
  - name: pharmalearn.events.train
    partitions: 12
    replication: 3
    retention: 7d
    
  - name: pharmalearn.events.certify
    partitions: 12
    replication: 3
    retention: 7d

  # Audit log (immutable, LONG retention for compliance)
  - name: pharmalearn.audit.trail
    partitions: 24
    replication: 3
    retention: 2555d  # 7 YEARS (GxP requirement)
    compaction: false
    
  # Notifications (short-lived)
  - name: pharmalearn.notifications
    partitions: 6
    replication: 3
    retention: 1d
    
  # CDC (Change Data Capture)
  - name: pharmalearn.cdc.employees
    partitions: 6
    replication: 3
    compaction: true  # Keep latest state
    
  # Dead letter queue
  - name: pharmalearn.dlq
    partitions: 3
    replication: 3
    retention: 30d
```

### 9.2 Event Schema

```typescript
// Event schema (Avro/JSON Schema)
interface DomainEvent {
  // Metadata
  id: string;           // UUID
  timestamp: string;    // ISO 8601
  version: string;      // Schema version
  source: string;       // Service name
  correlationId: string;
  causationId?: string;
  
  // Authentication context (WHO did it)
  actor: {
    employeeId: string;
    organizationId: string;
    plantId?: string;
    roles: string[];
    sessionId: string;
    ipAddress: string;
  };
  
  // Event data (WHAT happened)
  type: string;         // e.g., "training.session.started"
  aggregate: {
    type: string;       // e.g., "TrainingSession"
    id: string;
  };
  payload: Record<string, unknown>;
  
  // Audit integrity (Part 11 compliance)
  integrity: {
    hash: string;       // SHA-256 of payload
    prevHash?: string;  // Chain to previous event
  };
}

// Example: Session Started Event
const sessionStartedEvent: DomainEvent = {
  id: "evt_abc123",
  timestamp: "2026-04-23T10:30:00Z",
  version: "1.0",
  source: "train-service",
  correlationId: "req_xyz789",
  actor: {
    employeeId: "emp_123",
    organizationId: "org_abc",
    plantId: "plant_001",
    roles: ["trainer"],
    sessionId: "sess_456",
    ipAddress: "192.168.1.100"
  },
  type: "training.session.started",
  aggregate: {
    type: "TrainingSession",
    id: "ts_789"
  },
  payload: {
    courseId: "course_101",
    batchId: "batch_555",
    attendeeCount: 25,
    scheduledDuration: 120
  },
  integrity: {
    hash: "sha256:abc123...",
    prevHash: "sha256:xyz789..."
  }
};
```

### 9.3 Kafka Consumer Topology

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        KAFKA CONSUMER TOPOLOGY                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TOPIC: pharmalearn.events.*                                                │
│  │                                                                          │
│  ├──► Consumer Group: audit-writer                                          │
│  │    └── Writes to: PostgreSQL (audit_trails table)                       │
│  │    └── Replicas: 3 (high availability)                                  │
│  │                                                                          │
│  ├──► Consumer Group: search-indexer                                        │
│  │    └── Writes to: Elasticsearch                                         │
│  │    └── Replicas: 2                                                      │
│  │                                                                          │
│  ├──► Consumer Group: notification-dispatcher                               │
│  │    └── Triggers: Email (SendGrid), SMS (Twilio), Push (FCM), In-App    │
│  │    └── Replicas: 3                                                      │
│  │                                                                          │
│  ├──► Consumer Group: analytics-aggregator                                  │
│  │    └── Writes to: kpi_snapshots, training_analytics tables             │
│  │    └── Replicas: 2                                                      │
│  │                                                                          │
│  ├──► Consumer Group: webhook-dispatcher                                    │
│  │    └── Triggers: External system webhooks (QMS, ERP, HRMS)              │
│  │    └── Replicas: 2                                                      │
│  │                                                                          │
│  └──► Consumer Group: compliance-monitor                                    │
│       └── Checks: Overdue assignments, SLA breaches, anomalies             │
│       └── Replicas: 1                                                      │
│                                                                             │
│  TOPIC: pharmalearn.audit.trail                                             │
│  │                                                                          │
│  └──► Consumer Group: long-term-archive                                     │
│       └── Writes to: S3 (Parquet format, 7-year retention)                 │
│       └── Replicas: 1                                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.4 Event Catalog

| Domain | Event Type | Payload | Consumers |
|--------|------------|---------|-----------|
| **CREATE** | `document.published` | `{document_id, version_id, effective_date}` | Audit, Training Matrix, Search |
| | `course.approved` | `{course_id, version_id, approved_by}` | Audit, GTP Scheduler, Search |
| | `content.uploaded` | `{asset_id, type, size}` | Audit, Transcoding Pipeline |
| **ACCESS** | `user.created` | `{employee_id, org_id, roles[]}` | Audit, HRMS Sync, Induction |
| | `user.deactivated` | `{employee_id, reason}` | Audit, Session Termination |
| | `session.timeout` | `{session_id, employee_id}` | Audit, Security Monitor |
| | `esignature.created` | `{signature_id, entity_type, entity_id}` | Audit, Compliance |
| **TRAIN** | `session.started` | `{session_id, trainer_id, attendees[]}` | Audit, Live Dashboard |
| | `session.ended` | `{session_id, summary}` | Audit, Certificate Gen |
| | `attendance.recorded` | `{session_id, employee_id, method}` | Audit, Compliance |
| | `ojt.task.completed` | `{assignment_id, task_id, witnessed_by}` | Audit, Progress |
| **CERTIFY** | `assessment.submitted` | `{attempt_id, score, pass_status}` | Audit, Notifications |
| | `certificate.issued` | `{certificate_id, employee_id, course_id}` | Audit, Compliance, QMS |
| | `certificate.revoked` | `{certificate_id, reason, revoked_by[]}` | Audit, Compliance |
| | `compliance.alert` | `{org_id, plant_id, metric, threshold}` | Executive Dashboard |

---

## 10. Elasticsearch Integration

### 10.1 Index Design

```json
// courses index
{
  "mappings": {
    "properties": {
      "id": { "type": "keyword" },
      "organization_id": { "type": "keyword" },
      "course_code": { "type": "keyword" },
      "course_name": { 
        "type": "text",
        "analyzer": "english",
        "fields": {
          "keyword": { "type": "keyword" },
          "autocomplete": { "type": "text", "analyzer": "autocomplete" }
        }
      },
      "description": { "type": "text", "analyzer": "english" },
      "category": { "type": "keyword" },
      "tags": { "type": "keyword" },
      "trainer_names": { "type": "text" },
      "status": { "type": "keyword" },
      "created_at": { "type": "date" },
      "suggest": { "type": "completion" }
    }
  },
  "settings": {
    "analysis": {
      "analyzer": {
        "autocomplete": {
          "type": "custom",
          "tokenizer": "autocomplete",
          "filter": ["lowercase"]
        }
      },
      "tokenizer": {
        "autocomplete": {
          "type": "edge_ngram",
          "min_gram": 2,
          "max_gram": 20
        }
      }
    }
  }
}

// audit_trails index (append-only, 7-year retention)
{
  "mappings": {
    "properties": {
      "id": { "type": "keyword" },
      "timestamp": { "type": "date" },
      "actor_id": { "type": "keyword" },
      "actor_name": { "type": "keyword" },
      "organization_id": { "type": "keyword" },
      "plant_id": { "type": "keyword" },
      "entity_type": { "type": "keyword" },
      "entity_id": { "type": "keyword" },
      "action": { "type": "keyword" },
      "changes": { "type": "object", "enabled": false },
      "ip_address": { "type": "ip" },
      "user_agent": { "type": "text" },
      "integrity_hash": { "type": "keyword" }
    }
  }
}
```

### 10.2 Search API Examples

```typescript
class SearchService {
  // Global search across all entities
  async globalSearch(query: string, orgId: string): Promise<SearchResults> {
    return this.esClient.search({
      index: ['courses', 'documents', 'kb_articles', 'employees'],
      body: {
        query: {
          bool: {
            must: [{
              multi_match: {
                query,
                fields: ['title^3', 'course_name^3', 'description^2', 'content', 'tags'],
                type: 'best_fields',
                fuzziness: 'AUTO'
              }
            }],
            filter: [
              { term: { organization_id: orgId } }
            ]
          }
        },
        highlight: {
          fields: { title: {}, description: {}, content: { fragment_size: 150 } }
        },
        aggs: {
          by_type: { terms: { field: '_index' } },
          by_category: { terms: { field: 'category' } }
        }
      }
    });
  }
  
  // Audit trail search (for compliance)
  async searchAuditTrails(params: AuditSearchParams): Promise<AuditResults> {
    return this.esClient.search({
      index: 'audit_trails',
      body: {
        query: {
          bool: {
            filter: [
              { term: { organization_id: params.orgId } },
              { range: { timestamp: { gte: params.from, lte: params.to } } },
              ...(params.actorId ? [{ term: { actor_id: params.actorId } }] : []),
              ...(params.entityType ? [{ term: { entity_type: params.entityType } }] : []),
              ...(params.action ? [{ term: { action: params.action } }] : [])
            ]
          }
        },
        sort: [{ timestamp: 'desc' }],
        size: params.limit || 100
      }
    });
  }
}
```

---

## 11. Workflow Engine (Temporal)

### 11.1 Why Temporal?

| Challenge | Temporal Solution |
|-----------|------------------|
| Long-running approvals (days/weeks) | Durable workflow state survives restarts |
| Complex multi-step workflows | Visual workflow definition, easy debugging |
| Timeout handling & escalation | Built-in timers, signals |
| Audit trail for workflows | Complete execution history |
| Version management | Workflow versioning for safe updates |

### 11.2 Workflow Definitions

```typescript
// Document Approval Workflow
import { proxyActivities, sleep, condition, defineSignal } from '@temporalio/workflow';

const { 
  createApprovalTask,
  notifyApprover,
  updateDocumentStatus,
  createAuditEntry,
  escalateToManager
} = proxyActivities<typeof activities>({
  startToCloseTimeout: '5 minutes',
  retry: { maximumAttempts: 3 }
});

// Signals for external input
export const approveSignal = defineSignal<[ApprovalInput]>('approve');
export const rejectSignal = defineSignal<[RejectionInput]>('reject');

export async function documentApprovalWorkflow(input: ApprovalInput): Promise<ApprovalResult> {
  const { documentId, authorId, approvalMatrix } = input;
  let currentStep = 0;
  let approved = false;
  let rejected = false;
  
  // Create approval instance in DB
  const approvalId = await createApprovalTask({
    entityType: 'document',
    entityId: documentId,
    initiatorId: authorId,
    matrix: approvalMatrix
  });
  
  // Process each approval step
  for (const step of approvalMatrix.steps) {
    currentStep = step.order;
    
    // Notify approver
    await notifyApprover({
      approverId: step.approverId,
      documentId,
      stepNumber: step.order,
      deadline: step.deadlineHours
    });
    
    // Wait for approval signal or timeout
    const deadlineMs = step.deadlineHours * 60 * 60 * 1000;
    
    if (await condition(() => approved || rejected, deadlineMs)) {
      if (rejected) {
        await updateDocumentStatus(documentId, 'rejected');
        return { status: 'rejected', failedStep: step.order };
      }
      // Approved, continue to next step
    } else {
      // Timeout - escalate
      if (step.escalationEnabled) {
        await escalateToManager({
          originalApproverId: step.approverId,
          documentId,
          stepNumber: step.order
        });
        
        // Wait for escalation
        if (!await condition(() => approved || rejected, step.escalationDeadlineHours * 60 * 60 * 1000)) {
          await updateDocumentStatus(documentId, 'approval_timeout');
          return { status: 'timeout', failedStep: step.order };
        }
      }
    }
  }
  
  // All steps approved
  await updateDocumentStatus(documentId, 'approved');
  await createAuditEntry({ action: 'workflow.completed', entityId: documentId });
  
  return { status: 'approved', approvalId };
}
```

### 11.3 Workflow Use Cases

| Workflow | Trigger | Steps | Timeout Action |
|----------|---------|-------|----------------|
| Document Approval | `document.submitted` | Review → QA → Final | Escalate to manager |
| Course Approval | `course.submitted` | SME → Training Head → QA | Escalate chain |
| Certificate Revocation | `certificate.revoke.requested` | Primary Approver → Secondary | Abort (two-person) |
| Waiver Request | `waiver.requested` | Manager → QA → Final | Escalate |
| User Onboarding | `employee.created` | Create → Assign Role → Induction → Verify | Reminder sequence |
| Training Session | `session.created` | Invite → Confirm → Conduct → Evaluate | Auto-cancel |

---

## 12. Security Architecture

### 12.1 Security Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SECURITY ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ LAYER 1: EDGE SECURITY                                                  ││
│  │ • WAF (Cloudflare / AWS WAF)                                            ││
│  │ • DDoS protection                                                       ││
│  │ • TLS 1.3 termination                                                   ││
│  │ • Rate limiting (Kong + Redis)                                          ││
│  │ • IP allowlisting (optional)                                            ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ LAYER 2: AUTHENTICATION (Keycloak)                                      ││
│  │ • JWT validation                                                        ││
│  │ • SSO (SAML 2.0 / OIDC) - Azure AD, Okta                               ││
│  │ • MFA (TOTP, SMS, biometric)                                           ││
│  │ • Session management (Redis)                                            ││
│  │ • Password policies (complexity, rotation, no-reuse)                    ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ LAYER 3: AUTHORIZATION                                                  ││
│  │ • Role-Based Access Control (RBAC)                                      ││
│  │ • Row-Level Security (PostgreSQL RLS)                                   ││
│  │ • Resource-level permissions                                            ││
│  │ • Hierarchical role levels                                              ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ LAYER 4: DATA SECURITY                                                  ││
│  │ • Encryption at rest (AES-256)                                          ││
│  │ • Encryption in transit (TLS 1.3)                                       ││
│  │ • Column-level encryption (pgcrypto for PII)                           ││
│  │ • Data masking in logs and exports                                      ││
│  │ • Immutable audit trails (hash-chained, Kafka)                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ LAYER 5: SECRET MANAGEMENT (HashiCorp Vault)                            ││
│  │ • Dynamic database credentials                                          ││
│  │ • API key rotation                                                      ││
│  │ • HMAC keys for e-signatures                                            ││
│  │ • Encryption keys                                                       ││
│  │ • Integration credentials                                               ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                     │                                       │
│                                     ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ LAYER 6: COMPLIANCE (21 CFR Part 11)                                    ││
│  │ • E-signatures with record binding                                      ││
│  │ • Audit trail integrity verification                                    ││
│  │ • Data retention policies (7 years)                                     ││
│  │ • Two-person certificate revocation                                     ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 12.2 HashiCorp Vault Secret Structure

```hcl
# Vault secrets structure
secret/
├── pharmalearn/
│   ├── database/
│   │   ├── postgres-primary    # Dynamic credentials
│   │   └── postgres-replica
│   ├── cache/
│   │   └── redis               # Redis password
│   ├── messaging/
│   │   └── kafka               # Kafka credentials
│   ├── storage/
│   │   └── s3                  # S3 access keys
│   ├── auth/
│   │   └── keycloak            # Keycloak admin
│   ├── integrations/
│   │   ├── sendgrid            # Email API key
│   │   ├── twilio              # SMS API key
│   │   └── hrms                # HRMS credentials
│   └── crypto/
│       ├── esignature-key      # HMAC for e-signatures
│       └── encryption-key      # AES for field encryption
```

---

## 13. Observability Stack

### 13.1 Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        OBSERVABILITY ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ METRICS (Prometheus)                                                    ││
│  │                                                                         ││
│  │ Application Metrics:                                                    ││
│  │ • api_request_duration_seconds{service, endpoint, method, status}      ││
│  │ • api_requests_total{service, endpoint, method, status}                ││
│  │ • db_query_duration_seconds{query_type}                                ││
│  │ • kafka_messages_produced_total{topic}                                 ││
│  │ • kafka_consumer_lag{topic, consumer_group}                            ││
│  │ • redis_cache_hits_total / redis_cache_misses_total                    ││
│  │                                                                         ││
│  │ Business Metrics:                                                       ││
│  │ • training_sessions_active_total{organization}                         ││
│  │ • assessments_in_progress_total{organization}                          ││
│  │ • certificates_issued_total{organization, course}                      ││
│  │ • compliance_percentage{organization, plant}                           ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ DISTRIBUTED TRACING (Jaeger)                                            ││
│  │                                                                         ││
│  │ • End-to-end request tracing across all services                       ││
│  │ • Span attributes: user_id, org_id, correlation_id                     ││
│  │ • Database query spans                                                  ││
│  │ • Kafka produce/consume spans                                           ││
│  │ • External API call spans                                               ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ LOGGING (ELK Stack)                                                     ││
│  │                                                                         ││
│  │ Structured JSON logs:                                                   ││
│  │ {                                                                       ││
│  │   "timestamp": "2026-04-23T10:30:00Z",                                 ││
│  │   "level": "info",                                                      ││
│  │   "service": "train-service",                                           ││
│  │   "trace_id": "abc123",                                                ││
│  │   "user_id": "emp_123",                                                ││
│  │   "org_id": "org_abc",                                                 ││
│  │   "message": "Session started",                                         ││
│  │   "context": { "session_id": "sess_456", "attendees": 25 }             ││
│  │ }                                                                       ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ DASHBOARDS (Grafana)                                                    ││
│  │                                                                         ││
│  │ • System Health Dashboard                                               ││
│  │ • API Performance Dashboard                                             ││
│  │ • Database Performance Dashboard                                        ││
│  │ • Kafka Consumer Lag Dashboard                                          ││
│  │ • Business Metrics Dashboard                                            ││
│  │ • Compliance Dashboard                                                  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ ALERTING                                                                ││
│  │                                                                         ││
│  │ Critical Alerts (PagerDuty):                                            ││
│  │ • API error rate > 5%                                                   ││
│  │ • Database connection pool exhausted                                    ││
│  │ • Kafka consumer lag > 10,000 messages                                 ││
│  │ • Certificate generation failures                                       ││
│  │                                                                         ││
│  │ Warning Alerts (Slack):                                                 ││
│  │ • API latency p99 > 500ms                                               ││
│  │ • Redis cache hit rate < 80%                                            ││
│  │ • Disk usage > 80%                                                      ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 14. Infrastructure & Deployment

### 14.1 Kubernetes Architecture

```yaml
# Namespace structure
namespaces:
  - pharmalearn-prod
  - pharmalearn-staging
  - pharmalearn-monitoring
  - pharmalearn-data

# Core service deployments
deployments:
  - name: create-service
    replicas: 3
    resources:
      requests: { cpu: "500m", memory: "512Mi" }
      limits: { cpu: "2000m", memory: "2Gi" }
    autoscaling:
      min: 3
      max: 10
      targetCPU: 70%
      
  - name: access-service
    replicas: 5
    autoscaling:
      min: 5
      max: 15
      targetCPU: 60%
      
  - name: train-service
    replicas: 3
    autoscaling:
      min: 3
      max: 10
      targetCPU: 70%
      
  - name: certify-service
    replicas: 3
    autoscaling:
      min: 3
      max: 8
      targetCPU: 70%

# Data services (StatefulSets)
statefulsets:
  - name: postgresql-primary
    replicas: 1
    storage: 1Ti
    
  - name: postgresql-replica
    replicas: 2
    storage: 1Ti
    
  - name: redis-cluster
    replicas: 6
    storage: 32Gi
    
  - name: elasticsearch
    replicas: 3
    storage: 500Gi
```

### 14.2 CI/CD Pipeline

```yaml
# .github/workflows/deploy.yml
name: Deploy PharmaLearn

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Unit Tests
        run: npm test
      - name: Run Integration Tests
        run: npm run test:integration
      - name: Run pgTAP Database Tests
        run: npm run test:db
      - name: Security Scan
        run: npm audit && trivy image scan

  deploy-staging:
    needs: test
    if: github.ref == 'refs/heads/staging'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Staging
        run: kubectl apply -f k8s/staging/

  deploy-production:
    needs: test
    if: github.ref == 'refs/heads/main'
    environment: production
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Production
        run: |
          kubectl apply -f k8s/production/
          kubectl rollout status deployment/
```

---

## 15. Capacity Planning

### 15.1 Target Metrics

| Metric | Target | How Achieved |
|--------|--------|--------------|
| **Concurrent Users** | 50,000+ | Kubernetes auto-scaling + Redis cache |
| **API Latency (p99)** | <200ms | Redis cache + read replicas |
| **API Latency (p50)** | <50ms | CDN + connection pooling |
| **Uptime SLA** | 99.95% | Multi-AZ, auto-failover |
| **Data Durability** | 99.999999999% | S3 + PostgreSQL WAL archiving |
| **RPO** | 5 minutes | WAL streaming + Kafka retention |
| **RTO** | 15 minutes | Hot standby + automated failover |

### 15.2 Infrastructure Sizing

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CAPACITY CALCULATION                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ASSUMPTIONS:                                                               │
│  • 50,000 total users across organization                                   │
│  • 10% concurrent at peak (5,000 users)                                     │
│  • Each user generates ~1 request/sec during active use                     │
│  • 20% write, 80% read ratio                                                │
│                                                                             │
│  CALCULATIONS:                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ Peak Requests/sec = 5,000 users × 1 req/sec = 5,000 RPS             │   │
│  │ Daily DB Writes = 5,000 × 0.2 × 86,400 = 86.4M rows/day            │   │
│  │ Daily Events (Kafka) = ~100M events/day                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  INFRASTRUCTURE SIZING:                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ Component          │ Size                     │ Replicas            │   │
│  │────────────────────┼──────────────────────────┼─────────────────────│   │
│  │ PostgreSQL Primary │ 8 vCPU, 32GB RAM, 1TB   │ 1                   │   │
│  │ PostgreSQL Replica │ 4 vCPU, 16GB RAM, 1TB   │ 2                   │   │
│  │ Redis Cluster      │ 4 vCPU, 32GB RAM        │ 6 nodes             │   │
│  │ Kafka Cluster      │ 4 vCPU, 16GB RAM, 500GB │ 3 brokers           │   │
│  │ Elasticsearch      │ 4 vCPU, 16GB RAM, 500GB │ 3 nodes             │   │
│  │ API Services       │ 2 vCPU, 4GB RAM         │ 10-50 (auto)        │   │
│  │ Temporal           │ 2 vCPU, 4GB RAM         │ 3 nodes             │   │
│  │ Keycloak           │ 2 vCPU, 4GB RAM         │ 3 nodes             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ESTIMATED MONTHLY COST (AWS):                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ PostgreSQL (RDS Multi-AZ)     : $2,500/month                        │   │
│  │ Redis (ElastiCache)           : $1,200/month                        │   │
│  │ Kafka (MSK)                   : $1,500/month                        │   │
│  │ Elasticsearch (OpenSearch)    : $1,000/month                        │   │
│  │ EKS + EC2 (API services)      : $3,000/month                        │   │
│  │ S3 + CloudFront               : $500/month                          │   │
│  │ Monitoring + Logging          : $300/month                          │   │
│  │ ─────────────────────────────────────────────                       │   │
│  │ TOTAL                         : ~$10,000/month                      │   │
│  │                                                                     │   │
│  │ Per-user cost: $0.20/user/month (50,000 users)                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 16. URS Compliance Verification

### 16.1 Complete URS Mapping

| URS Section | Requirement | Component | How Satisfied |
|-------------|-------------|-----------|---------------|
| **5.1.1** | User Management | Keycloak + PostgreSQL | `employees` table + Keycloak federation |
| **5.1.2** | Role-Based Access | Keycloak + RLS | `roles`, `permissions`, RLS policies |
| **5.1.3** | Training Needs | PostgreSQL | `training_matrix`, `curricula` |
| **5.1.4** | Course Management | PostgreSQL + S3 | `courses`, `lessons`, `content_assets` |
| **5.1.5** | Session Scheduling | PostgreSQL + Temporal | `training_sessions`, workflow |
| **5.1.6** | Attendance Tracking | PostgreSQL + Redis | `session_attendance`, real-time |
| **5.1.7** | Assessment Engine | PostgreSQL | `question_banks`, `assessment_attempts` |
| **5.1.8** | Certificate Generation | PostgreSQL + S3 | `certificates`, PDF generation |
| **5.1.9** | Auto-Assignment | PostgreSQL + Kafka | `training_matrix` → events → assignments |
| **5.3.1** | Workflow Automation | Temporal | Configurable approval flows |
| **5.3.2** | Escalation | Temporal + BullMQ | Escalation rules, scheduled jobs |
| **5.3.3** | Notifications | BullMQ + SendGrid | Multi-channel delivery |
| **5.4.1** | SSO Integration | Keycloak | SAML 2.0, OIDC |
| **5.6.1** | Audit Trail | Kafka + PostgreSQL | Hash-chained, immutable |
| **5.6.2** | Data Integrity | PostgreSQL + Checksums | Hash verification |
| **5.9.1** | Password Policy | Keycloak | Configurable policies |
| **5.9.2** | MFA | Keycloak | TOTP, SMS, biometric |
| **5.13.1** | E-Signature | PostgreSQL | Part 11 compliant |

### 16.2 21 CFR Part 11 Compliance Matrix

| CFR Section | Requirement | Implementation | ✓ |
|-------------|-------------|----------------|---|
| §11.10(a) | System Validation | pgTAP tests, IQ/OQ/PQ | ✅ |
| §11.10(b) | Accurate Copies | PDF export with hash | ✅ |
| §11.10(c) | Record Protection | Retention policies, backup | ✅ |
| §11.10(d) | Limited Access | Keycloak + RLS | ✅ |
| §11.10(e) | Audit Trail | Kafka → PostgreSQL (hash-chained) | ✅ |
| §11.10(f) | Operational Checks | Temporal workflows | ✅ |
| §11.10(g) | Authority Checks | Role levels, approval matrices | ✅ |
| §11.50 | Signature Manifestation | Name, title, meaning, timestamp | ✅ |
| §11.70 | Signature Linking | SHA-256 record_hash | ✅ |
| §11.200 | E-Signature Components | Password + biometric | ✅ |
| §11.300 | ID/Password Controls | Keycloak + Vault | ✅ |

---

## 17. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)
- [ ] Set up Kubernetes cluster (EKS/GKE)
- [ ] Deploy PostgreSQL with replication
- [ ] Deploy Redis cluster
- [ ] Deploy Kafka cluster
- [ ] Set up HashiCorp Vault
- [ ] Configure Keycloak
- [ ] Set up CI/CD pipeline

### Phase 2: Core Services (Weeks 5-8)
- [ ] Implement Access Service
- [ ] Implement Create Service
- [ ] Implement Train Service
- [ ] Implement Certify Service
- [ ] Set up API Gateway (Kong)

### Phase 3: Event Architecture (Weeks 9-10)
- [ ] Implement Kafka producers
- [ ] Implement Audit Consumer
- [ ] Implement Notification Consumer
- [ ] Implement Search Indexer
- [ ] Set up Temporal workflows

### Phase 4: Observability (Weeks 11-12)
- [ ] Deploy Prometheus + Grafana
- [ ] Deploy Jaeger
- [ ] Deploy ELK stack
- [ ] Create dashboards
- [ ] Configure alerting

### Phase 5: Hardening (Weeks 13-14)
- [ ] Security audit
- [ ] Load testing (50K users)
- [ ] Chaos engineering
- [ ] Compliance validation
- [ ] Documentation

### Phase 6: Go-Live (Week 15+)
- [ ] Staged rollout
- [ ] Monitoring & tuning
- [ ] IQ/OQ/PQ validation

---
            WHERE employee_id = current_employee_id()
        )
        OR has_permission('employees.read.all')
    );

-- Training records: employees see their own + managers see team
CREATE POLICY training_records_access ON training_records
    FOR SELECT
    USING (
        employee_id = current_employee_id()
        OR employee_id IN (SELECT id FROM employees WHERE manager_id = current_employee_id())
        OR has_permission('training_records.read.all')
    );

-- Audit trails: read-only for compliance officers
CREATE POLICY audit_trails_compliance ON audit_trails
    FOR SELECT
    USING (has_permission('audit.read'));

-- No update/delete on audit trails
CREATE POLICY audit_trails_immutable ON audit_trails
    FOR UPDATE USING (false);
    
CREATE POLICY audit_trails_no_delete ON audit_trails
    FOR DELETE USING (false);
```

### 7.3 E-Signature Security (21 CFR Part 11)

```typescript
// Edge function: esignature-verify/index.ts
import { createClient } from '@supabase/supabase-js';
import { createHash } from 'crypto';

interface SignatureRequest {
  entity_type: string;
  entity_id: string;
  meaning: string;
  reason: string;
  password: string;  // For re-authentication
  biometric_token?: string;
}

export async function handler(req: Request): Promise<Response> {
  const supabase = createClient(/* ... */);
  const user = await getAuthUser(req);
  const body: SignatureRequest = await req.json();

  // 1. Verify password (re-authentication)
  const { error: authError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password: body.password,
  });
  if (authError) {
    return Response.json({ error: 'Password verification failed' }, { status: 401 });
  }

  // 2. Verify biometric if required for this meaning
  const { data: meaning } = await supabase
    .from('signature_meanings')
    .select('requires_password_reauth, requires_biometric')
    .eq('meaning', body.meaning)
    .single();

  if (meaning?.requires_biometric && !body.biometric_token) {
    return Response.json({ error: 'Biometric verification required' }, { status: 400 });
  }

  // 3. Fetch entity snapshot for integrity hash
  const { data: entity } = await supabase
    .from(body.entity_type)
    .select('*')
    .eq('id', body.entity_id)
    .single();

  // 4. Create integrity hash
  const dataSnapshot = JSON.stringify(entity);
  const integrityHash = createHash('sha256')
    .update(dataSnapshot + body.meaning + body.reason + Date.now())
    .digest('hex');

  // 5. Get session chain reference
  const { data: sessionChain } = await supabase
    .from('session_chains')
    .select('id')
    .eq('employee_id', user.employee_id)
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  // 6. Get previous signature for chain
  const { data: prevSig } = await supabase
    .from('electronic_signatures')
    .select('id')
    .eq('employee_id', user.employee_id)
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  // 7. Create signature record
  const { data: signature, error } = await supabase
    .from('electronic_signatures')
    .insert({
      employee_id: user.employee_id,
      employee_name: user.name,
      employee_email: user.email,
      employee_title: user.title,
      employee_id_code: user.employee_code,
      meaning: body.meaning,
      meaning_display: meaning?.display_text,
      reason: body.reason,
      entity_type: body.entity_type,
      entity_id: body.entity_id,
      ip_address: req.headers.get('x-forwarded-for'),
      user_agent: req.headers.get('user-agent'),
      integrity_hash: integrityHash,
      record_hash: integrityHash,
      data_snapshot: entity,
      password_reauth_verified: true,
      biometric_verified: !!body.biometric_token,
      session_chain_id: sessionChain?.id,
      prev_signature_id: prevSig?.id,
      is_valid: true,
      organization_id: user.organization_id,
      plant_id: user.plant_id,
    })
    .select()
    .single();

  return Response.json({ signature });
}
```

---

## Appendix: Complete Table Mapping

### CREATE Module Tables

| Schema Folder | Table Name | Purpose |
|---------------|------------|---------|
| `05_documents` | `document_categories` | Document category hierarchy |
| | `documents` | Master document records (SOP/WI/Policy) |
| | `document_versions` | Immutable version snapshots |
| | `document_reads` | Read tracking with scroll depth |
| | `document_acknowledgements` | E-signed acknowledgements |
| `06_courses` | `course_categories` | Course categorization |
| | `subjects` | Subject areas within categories |
| | `topics` | Topics within subjects |
| | `courses` | Master course records |
| | `course_versions` | Course version snapshots |
| | `course_topics` | Course-topic mappings |
| | `trainers` | Internal/external trainers |
| | `trainer_courses` | Trainer qualifications |
| | `venues` | Training venue management |
| | `feedback_templates` | Feedback form templates |
| | `satisfaction_scales` | Rating scales |
| `08_assessment` | `question_bank_categories` | QB categorization |
| | `question_banks` | Question bank containers |
| | `questions` | Individual questions |
| | `question_options` | MCQ options |
| | `question_blanks` | Fill-in-blank answers |
| | `question_matching_pairs` | Matching question pairs |
| | `question_papers` | Assessment papers |
| | `question_paper_sections` | Paper sections |
| | `question_paper_questions` | Paper-question mapping |
| `17_extensions` | `content_assets` | Reusable content library |
| | `lessons` | Course lessons |
| | `lesson_content` | Lesson-asset mapping |
| | `scorm_packages` | SCORM package metadata |
| | `learning_paths` | Learning path definitions |
| | `learning_path_steps` | Path step sequence |
| | `course_prerequisites` | Prerequisite rules |
| | `kb_categories` | Knowledge base categories |
| | `kb_articles` | KB article content |
| | `kb_article_versions` | KB version history |
| | `surveys` | Survey definitions |
| | `survey_questions` | Survey questions |

### ACCESS Module Tables

| Schema Folder | Table Name | Purpose |
|---------------|------------|---------|
| `03_organization` | `organizations` | Tenant organizations |
| | `plants` | Manufacturing sites |
| | `departments` | Department hierarchy |
| `04_identity` | `role_categories` | Role category groupings |
| | `roles` | Role definitions with levels |
| | `permissions` | Permission definitions |
| | `role_permissions` | Role-permission mapping |
| | `global_profiles` | Industry role templates |
| | `employees` | Employee master records |
| | `employee_roles` | Employee role assignments |
| | `groups` | Functional groups |
| | `subgroups` | Subgroup definitions |
| | `group_subgroups` | Group-subgroup mapping |
| | `employee_subgroups` | Employee group memberships |
| | `job_responsibilities` | Role responsibility text |
| | `biometric_registrations` | Biometric templates |
| | `standard_reasons` | Standardized reason codes |
| | `user_sessions` | Active session tracking |
| | `session_chains` | Session chain for e-sig |
| | `user_credentials` | Password hash history |
| `02_core` | `audit_trails` | Immutable audit log |
| | `electronic_signatures` | Part 11 e-signatures |
| | `signature_meanings` | Signature meaning definitions |
| `11_audit` | `login_audit_trail` | Login/logout tracking |
| | `data_access_audit` | Data access logging |
| | `permission_change_audit` | Permission change history |
| | `system_config_audit` | Config change tracking |
| `16_infrastructure` | `sso_configurations` | SSO provider settings |
| | `api_keys` | API key management |

### TRAIN Module Tables

| Schema Folder | Table Name | Purpose |
|---------------|------------|---------|
| `07_training` | `group_training_plans` | GTP master records |
| | `gtp_courses` | GTP-course mapping |
| | `gtp_versions` | GTP version history |
| | `training_schedules` | Schedule definitions |
| | `training_sessions` | Session instances |
| | `training_batches` | Session batches |
| | `batch_trainees` | Batch-trainee mapping |
| | `training_invitations` | Session invitations |
| | `training_nominations` | Nomination requests |
| | `session_attendance` | Attendance records |
| | `daily_attendance_summary` | Attendance rollup |
| | `induction_programs` | Induction program defs |
| | `induction_modules` | Induction modules |
| | `induction_enrollments` | Employee induction |
| | `induction_progress` | Module progress |
| | `ojt_assignments` | OJT assignments |
| | `ojt_tasks` | OJT task definitions |
| | `ojt_task_completion` | Task completion records |
| | `self_learning_enrollments` | Self-learning enrollment |
| | `self_learning_progress` | Self-learning progress |
| | `training_feedback` | Session feedback |
| | `trainer_feedback` | Trainer ratings |
| | `training_effectiveness` | Kirkpatrick evaluation |
| | `training_reschedules` | Reschedule requests |
| | `training_cancellations` | Cancellation records |
| `17_extensions` | `lesson_progress` | Lesson completion |
| | `content_view_tracking` | Video/content tracking |
| | `xapi_statements` | xAPI LRS statements |

### CERTIFY Module Tables

| Schema Folder | Table Name | Purpose |
|---------------|------------|---------|
| `08_assessment` | `assessment_attempts` | Assessment attempts |
| | `assessment_responses` | Question responses |
| | `assessment_results` | Graded results |
| | `assessment_proctoring` | Proctoring data |
| | `assessment_activity_log` | Assessment activity |
| | `grading_queue` | Manual grading queue |
| | `result_appeals` | Appeal requests |
| `09_compliance` | `training_records` | Compliance records |
| | `training_record_items` | Record line items |
| | `certificates` | Issued certificates |
| | `certificate_templates` | Certificate templates |
| | `certificate_signatures` | Certificate signatories |
| | `certificate_verifications` | Verification log |
| | `training_assignments` | Assignment definitions |
| | `employee_assignments` | Employee assignments |
| | `training_matrix` | Role-course matrix |
| | `training_matrix_items` | Matrix line items |
| | `training_waivers` | Waiver requests |
| | `waiver_approvals` | Waiver approval history |
| | `training_exemptions` | Exemption definitions |
| | `exemption_employees` | Exemption-employee mapping |
| | `competencies` | Competency definitions |
| | `role_competencies` | Role competency requirements |
| | `employee_competencies` | Employee competency levels |
| | `competency_gaps` | Gap analysis results |
| | `competency_history` | Competency change history |
| `13_analytics` | `compliance_reports` | Generated compliance reports |
| | `training_analytics` | Training rollup metrics |
| | `employee_training_analytics` | Per-employee metrics |

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-20 | Architecture Team | Initial draft |
| 2.0 | 2026-04-22 | Architecture Team | 4-module restructure, real-time architecture |
| 3.0 | 2026-04-23 | Architecture Team | Enterprise stack (Redis, Kafka, Elasticsearch, Temporal, Keycloak), capacity planning, URS compliance |

---

*This architecture document is confidential and intended for PharmaLearn development team use only.*
