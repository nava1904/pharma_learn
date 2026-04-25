# Complete API Architecture Tools Reference
**PharmaLearn LMS — All Tools, Frameworks & Technologies Used**

> **Version:** 1.0  
> **Date:** 2026-04-24  
> **Scope:** Complete inventory of all tools across all architecture layers

---

## Table of Contents

1. [Frontend Tools (Flutter)](#1-frontend-tools-flutter)
2. [Backend Database Tools](#2-backend-database-tools)
3. [Backend Services & APIs](#3-backend-services--apis)
4. [Authentication & Security](#4-authentication--security)
5. [Real-Time & Messaging](#5-real-time--messaging)
6. [Storage & File Management](#6-storage--file-management)
7. [API Gateway & Infrastructure](#7-api-gateway--infrastructure)
8. [Background Jobs & Cron](#8-background-jobs--cron)
9. [Dart/Flutter Framework Packages](#9-dartflutter-framework-packages)
10. [Enterprise Frameworks (Vyuh)](#10-enterprise-frameworks-vyuh)
11. [Observability & Monitoring](#11-observability--monitoring)
12. [Compliance & Audit](#12-compliance--audit)
13. [Development & Testing Tools](#13-development--testing-tools)

---

## 1. Frontend Tools (Flutter)

### Core Framework
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **Flutter** | 3.19+ | Cross-platform UI framework | Single codebase for Web, iOS, Android, Desktop |
| **Dart** | 3.2+ | Programming language | Type-safe, JIT/AOT compiled, great for UI |
| **Flutter Web** | 3.19+ | Web platform target | PWA-capable, responsive design |
| **Flutter Android** | 3.19+ | Mobile platform target | Native performance, Material Design |
| **Flutter iOS** | 3.19+ | Mobile platform target | Native performance, Cupertino Design |
| **Flutter Desktop (Windows/Mac)** | 3.19+ | Desktop platform target | Full OS integration |

### State Management & Architecture
| Tool | Version | Purpose | Used For |
|------|---------|---------|----------|
| **flutter_riverpod** | 2.5.0+ | Reactive state management | Global app state, provider pattern |
| **flutter_bloc** | 8.1.0+ | Business Logic Component | Event-driven state (alternative to Riverpod) |
| **freezed** | 2.4.0+ | Code generation for immutable classes | Data models, entities |
| **json_serializable** | 6.7.0+ | JSON serialization code generation | API response mapping |

### Navigation & Routing
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **go_router** | 13.2.0+ | Declarative routing | URL-based navigation, deep linking |
| **auto_route** | Latest | Code-generated routing | Alternative, more type-safe |

### UI Components & Widgets
| Tool | Version | Purpose | Used For |
|------|---------|---------|----------|
| **flutter_form_builder** | 9.2.0+ | Dynamic form generation | Surveys, assessments, user forms |
| **data_table_2** | 2.5.0+ | Advanced data tables | Training schedules, attendance reports |
| **fl_chart** | 0.66.0+ | Charts & graphs | Dashboard analytics (attendance, pass rates) |
| **syncfusion_flutter_pdfviewer** | 25.1.0+ | PDF viewing | Document preview, certificate preview |
| **pdf** | 3.10.0+ | PDF generation | Certificate creation, report export |
| **printing** | 5.12.0+ | Print support | Physical certificate printing |
| **getwidget** | Latest | Pre-built widgets | UI components (optional) |
| **flutter_spinkit** | Latest | Loading indicators | Beautiful spinners during async operations |

### Local Storage & Offline Support
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **hive_flutter** | 1.1.0+ | NoSQL local database | Offline-first caching, fast read/write |
| **flutter_secure_storage** | 9.0.0+ | Encrypted key-value store | JWT tokens, API keys (secure) |
| **sqflite** | 2.3.0+ | SQLite database | Alternative local storage (lightweight) |
| **isar** | Latest | Local database (alternative) | Faster than Hive, type-safe |
| **shared_preferences** | 2.2.0+ | Simple key-value store | App preferences, user settings |

### Authentication & Biometrics
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **supabase_flutter** | 2.5.0+ | Supabase SDK | All Supabase services integration |
| **local_auth** | 2.2.0+ | Biometric authentication | Fingerprint, Face ID on mobile |
| **flutter_appauth** | Latest | OAuth 2.0 / OpenID Connect | SSO (Google, Azure AD integration) |
| **okta_flutter** | Latest | Okta authentication | Enterprise SSO (if using Okta) |

### Network & API Communication
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **dio** | 5.4.0+ | HTTP client with interceptors | API calls, auto-retry, timeout handling |
| **connectivity_plus** | 6.0.0+ | Network connectivity detection | Offline mode detection |
| **web_socket_channel** | Latest | WebSocket client | Real-time data subscriptions |

### Utilities & Common Libraries
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **intl** | 0.19.0+ | Internationalization (i18n) | Multi-language support |
| **logger** | 2.2.0+ | Structured logging | Debug logs with timestamps |
| **uuid** | 4.3.0+ | UUID generation | Unique IDs for offline entities |
| **package_info_plus** | 5.1.0+ | App version/info | Version checking, updates |
| **url_launcher** | 6.2.0+ | Launch URLs | Open links, email, phone |
| **share_plus** | 7.2.0+ | Share functionality | Share certificates, reports |
| **permission_handler** | 11.4.0+ | Handle permissions | Camera, microphone, location |
| **camera** | 0.11.0+ | Camera access | Document scanning, proctoring |

### Testing & Development
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **flutter_test** | SDK | Unit & widget testing | Built-in testing framework |
| **mockito** | 3.7.0+ | Mocking for tests | Mock API responses |
| **integration_test** | SDK | Integration testing | End-to-end testing |
| **flutter_lints** | 3.0.0+ | Linting | Code quality standards |

---

## 2. Backend Database Tools

### Primary Database
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **PostgreSQL** | 15+ | Relational database | ACID compliance, audit-friendly, mature |
| **pg_trgm** | Built-in | Full-text search | Document search optimization |
| **pgcrypto** | Built-in | Encryption functions | Password hashing, data encryption |
| **UUID** | Built-in | UUID generation | Unique identifiers |
| **PostGIS** | 3.4+ | Geospatial data | Location-based features (optional) |

### Database Optimization
| Tool | Purpose | Configuration |
|------|---------|----------------|
| **Connection Pooling (PgBouncer)** | Manage DB connections | 500-5000 concurrent connections |
| **pg_stat_statements** | Query performance monitoring | Identify slow queries |
| **EXPLAIN ANALYZE** | Query plan analysis | Optimize heavy queries |
| **Indexes** | Query speed | B-tree, Full-text search indexes |
| **Read Replicas** | Scale read queries | Reporting, analytics queries |

### Event Logging & Audit
| Tool | Purpose | Implementation |
|------|---------|-----------------|
| **PostgreSQL LISTEN/NOTIFY** | Event broadcasting | Module-to-module communication |
| **audit_trail table** | Immutable audit log | Every change logged |
| **event_log table** | Event-sourcing | Cross-module events |

---

## 3. Backend Services & APIs

### API Layer (PostgREST)
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **PostgREST** | 12+ | Auto-generated REST API | Zero code needed for CRUD operations |
| **Swagger/OpenAPI** | 3.0+ | API documentation | Auto-generated from PostgREST schema |
| **CORS** | Built-in | Cross-origin requests | Frontend can call from any domain |
| **RLS (Row-Level Security)** | Built-in | Row-level authorization | User can only see their own data |

### Backend Services (Choose One)
| Tool | Version | Use Case | Complexity |
|------|---------|----------|-----------|
| **Dart Frog** | Latest | Lightweight REST API | Low (for simple endpoints) |
| **Serverpod** | Latest | Full-featured backend | High (full ORM, code gen) |
| **Shelf** | Latest | Minimal backend framework | Very Low (middleware-based) |
| **Aqueduct** | Latest | ORM-based backend | Medium (database-first) |

### API Gateway
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **Kong** | 3.0+ | API Gateway | Rate limiting, auth, request routing |
| **NGINX** | Latest | Reverse proxy, load balancer | Request distribution, SSL termination |
| **Supabase Edge Functions** | Latest | Serverless functions | Custom API endpoints without servers |

---

## 4. Authentication & Security

### Authentication Service
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **Supabase GoTrue** | 2.0+ | Full auth service | JWT, session management, MFA |
| **PostgreSQL** | 15+ | User credentials storage | Secure password hashing |

### Authentication Methods
| Method | Tool | Purpose |
|--------|------|---------|
| **Password + MFA** | TOTP (Google Authenticator) | Employee login with 2FA |
| **OAuth 2.0 / SAML** | azure_flutter, flutter_appauth | Enterprise SSO (Azure AD, Google) |
| **Biometric** | local_auth | Fingerprint, Face ID on mobile |
| **API Key** | Custom implementation | Machine-to-machine auth |
| **JWT** | GoTrue | Stateless session tokens |

### Encryption & Security
| Tool | Purpose | Implementation |
|------|---------|-----------------|
| **bcrypt** | Password hashing | GoTrue handles this |
| **RSA/ECC** | E-signatures, certificates | For document signing |
| **AES-256** | Data encryption at rest | pgcrypto PostgreSQL extension |
| **SSL/TLS 1.3** | Data in transit encryption | Kong/NGINX termination |
| **HMAC-SHA256** | API signature verification | Request authentication |

---

## 5. Real-Time & Messaging

### Real-Time Subscriptions
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **Supabase Realtime** | Latest | WebSocket subscriptions | Real-time dashboard updates |
| **PostgREST** | 12+ | REST API for polling | Fallback for real-time |
| **WebSocket** | Native | Two-way communication | Live attendance tracking |

### Messaging & Events
| Tool | Version | Purpose | Use Case |
|------|---------|---------|----------|
| **Redis Pub/Sub** | 7+ | Message publishing | Event broadcasting between modules |
| **RabbitMQ** | 3.12+ | Message broker (alternative) | For high-volume event processing |
| **Apache Kafka** | 3.6+ | Event streaming (advanced) | For analytics, audit trails |
| **PostgreSQL LISTEN/NOTIFY** | 15+ | Native event system | Module-to-module communication |

---

## 6. Storage & File Management

### File Storage
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **Supabase Storage** | Latest | Cloud file storage | Managed S3-compatible storage |
| **MinIO** | Latest | S3-compatible storage | Self-hosted alternative |
| **AWS S3** | N/A | Cloud file storage | If using AWS |
| **Google Cloud Storage** | N/A | Cloud file storage | If using Google Cloud |

### File Types Handled
| File Type | Tool | Purpose |
|-----------|------|---------|
| **PDF** | pdf (Dart) + printing | Certificate generation, document viewing |
| **Images** | image (Dart) | Thumbnails, profile pictures |
| **Videos** | HLS streaming | Course videos |
| **Excel/CSV** | csv / excel | Bulk data import, report export |
| **Word Documents** | docx | Document templates |

---

## 7. API Gateway & Infrastructure

### Gateway & Routing
| Tool | Version | Purpose | Features |
|------|---------|---------|----------|
| **Kong** | 3.0+ | API Gateway | Rate limiting, auth, routing, logging |
| **NGINX** | Latest | Reverse proxy | Load balancing, SSL, caching |
| **HAProxy** | Latest | Load balancer | Request distribution |
| **Envoy** | Latest | Service proxy | Advanced traffic management |

### Infrastructure as Code
| Tool | Version | Purpose |
|------|---------|---------|
| **Docker** | Latest | Containerization | Consistent deployment |
| **Docker Compose** | Latest | Multi-container orchestration | Local development, small deployments |
| **Kubernetes** | 1.28+ | Container orchestration | Production deployment, auto-scaling |
| **Terraform** | Latest | Infrastructure as Code | Cloud resource provisioning |
| **Helm** | 3.13+ | Kubernetes package manager | Deploy complex applications |

---

## 8. Background Jobs & Cron

### Job Scheduling
| Tool | Version | Purpose | Use Cases |
|------|---------|---------|-----------|
| **pg_cron** | Latest | PostgreSQL cron extension | Daily compliance reports, certificate expiry alerts |
| **pg_net** | Latest | HTTP requests from PostgreSQL | Send webhooks to external systems |
| **BullMQ** | Latest | Redis-based job queue | Background task processing |
| **APScheduler** | Latest | Python scheduler (if using Python) | Complex scheduling logic |

### Job Types Executed
| Job | Schedule | Tool |
|-----|----------|------|
| **Certificate expiry reminder** | Weekly | pg_cron |
| **Compliance report generation** | Monthly | pg_cron |
| **Cleanup old event logs** | Daily | pg_cron |
| **Send notifications** | Real-time | BullMQ |
| **Batch user assignment** | On-demand | BullMQ |

---

## 9. Dart/Flutter Framework Packages

### Complete pubspec.yaml Dependencies

```yaml
# CORE FLUTTER
flutter:
  sdk: flutter
flutter_lints: ^3.0.0

# SUPABASE & BACKEND
supabase_flutter: ^2.5.0
supabase: ^1.11.0

# STATE MANAGEMENT
flutter_riverpod: ^2.5.0
flutter_bloc: ^8.1.0  # Alternative to Riverpod
riverpod_generator: ^2.3.0

# CODE GENERATION
freezed_annotation: ^2.4.0
json_annotation: ^4.8.0
build_runner: ^2.4.0
freezed: ^2.4.0
json_serializable: ^6.7.0

# NAVIGATION & ROUTING
go_router: ^13.2.0
auto_route: ^8.0.0

# LOCAL STORAGE & SECURITY
hive_flutter: ^1.1.0
hive: ^2.2.0
hive_generator: ^2.0.0
flutter_secure_storage: ^9.0.0
sqflite: ^2.3.0
isar: ^3.1.0
shared_preferences: ^2.2.0

# AUTHENTICATION & BIOMETRICS
local_auth: ^2.2.0
local_auth_ios: ^1.1.0
local_auth_android: ^1.0.0
flutter_appauth: ^6.1.0

# NETWORK & API
dio: ^5.4.0
connectivity_plus: ^6.0.0
web_socket_channel: ^2.4.0
http: ^1.1.0

# FORMS & INPUT
flutter_form_builder: ^9.2.0
form_builder_validators: ^10.4.0

# UI COMPONENTS
data_table_2: ^2.5.0
fl_chart: ^0.66.0
syncfusion_flutter_pdfviewer: ^25.1.0
getwidget: ^3.0.1
flutter_spinkit: ^5.2.0
animated_splash_screen: ^1.3.0
shimmer: ^3.0.0
badges: ^3.1.0
skeletons: ^0.0.20

# PDF & DOCUMENTS
pdf: ^3.10.0
printing: ^5.12.0
document_file_save_plus: ^0.1.0

# UTILITIES
intl: ^0.19.0
logger: ^2.2.0
uuid: ^4.3.0
package_info_plus: ^5.1.0
url_launcher: ^6.2.0
share_plus: ^7.2.0
permission_handler: ^11.4.0
camera: ^0.11.0
image_picker: ^1.0.0
image: ^4.1.0
path_provider: ^2.1.1

# TESTING
mockito: ^3.7.0
mocktail: ^1.0.0
```

---

## 10. Enterprise Frameworks (Vyuh)

### Vyuh Professional Packages

| Package | Version | Purpose | Use Case |
|---------|---------|---------|----------|
| **vyuh_entity_system** | 1.17.0 | Code-generated CRUD entities | Auto-generate Flutter forms from Dart classes |
| **vyuh_entity_system_ui** | 1.28.0 | Auto-generated entity UIs | Automatic CRUD UI generation |
| **vyuh_property_system** | 1.3.0 | Type-safe property validation | Form field validation rules |
| **vyuh_workflow_engine** | 1.3.2 | Workflow/process orchestration | Document approval flows, training workflows |
| **vyuh_form_editor** | 1.3.1 | Dynamic form builder | Assessment creation, survey forms |
| **vyuh_rule_engine** | 1.1.3 | Business rules engine | Eligibility checks, remedial logic |
| **vyuh_timelines** | 0.1.2 | Timeline visualization | Training timeline, certification timeline |
| **cdx_checklist** | 0.1.2 | Checklist management | Compliance checklist, OJT checklist |

### How Vyuh Packages Are Used

**Module Specific Usage:**

| Module | Vyuh Package | Example |
|--------|--------------|---------|
| **CREATE** | `entity_system`, `workflow_engine` | Auto-generate document form, approval workflow UI |
| **ACCESS** | `entity_system_ui`, `rule_engine` | Auto-generate role/permission UI, access control rules |
| **TRAIN** | `workflow_engine`, `rule_engine` | Training path workflow, eligibility rule evaluation |
| **CERTIFY** | `form_editor`, `rule_engine` | Dynamic assessment forms, remedial assignment logic |

---

## 11. Observability & Monitoring

### Logging Stack
| Tool | Version | Purpose | Why We Use It |
|------|---------|---------|---------------|
| **Elasticsearch** | 8.0+ | Log aggregation & search | Full-text search of logs |
| **Logstash** | 8.0+ | Log pipeline | Parse & enrich logs |
| **Kibana** | 8.0+ | Log visualization | Dashboards, alerting |
| **ELK Stack** | Latest | Logging ecosystem | Industry standard (optional) |

### Application Logging
| Tool | Purpose | Implementation |
|------|---------|-----------------|
| **Dart Logger** | Structured logging in backend | Timestamp, level, context |
| **Flutter Logger** | Structured logging in frontend | Device logs, analytics |
| **Sentry** | Error tracking | Crash reporting |
| **Firebase Crashlytics** | Mobile crash reporting | iOS/Android crash tracking |

### Metrics & Monitoring
| Tool | Version | Purpose | Metrics Tracked |
|------|---------|---------|-----------------|
| **Prometheus** | Latest | Metrics collection | Request latency, error rates, DB performance |
| **Grafana** | Latest | Metrics visualization | Custom dashboards, alerts |
| **Datadog** | Latest | APM & monitoring | Alternative all-in-one solution |
| **New Relic** | Latest | Application performance | Alternative APM tool |

### Health Checks
| Metric | Target | Tool |
|--------|--------|------|
| **App launch time** | < 2 seconds | Flutter DevTools |
| **API response time** | < 100ms (p95) | Prometheus |
| **Database query time** | < 50ms (p95) | pg_stat_statements |
| **Error rate** | < 0.1% | Sentry |
| **Uptime** | > 99.9% | Monitoring service |

---

## 12. Compliance & Audit

### Compliance Tools
| Tool | Purpose | Implementation |
|------|---------|-----------------|
| **audit_trail table** | 21 CFR Part 11 compliance | Immutable log of all changes |
| **e-signature (RSA)** | Digital signatures | Document approval tracking |
| **Hash chain** | Data integrity verification | Blockchain-like verification |
| **UUID + version tracking** | Document versioning | audit_trail + document_versions table |

### Compliance Checks
| Requirement | Tool | How Implemented |
|-------------|------|-----------------|
| **User attribution** | audit_trail + GoTrue JWT | Every change logged with user_id |
| **Immutability** | PostgreSQL (append-only) | No UPDATE/DELETE on audit trail |
| **Timestamp accuracy** | PostgreSQL TIMESTAMPTZ | Tamper-proof timestamps |
| **Access control** | RLS + GoTrue | Row-level permissions enforced |
| **Data encryption** | pgcrypto + SSL/TLS | Encryption at rest & in transit |

---

## 13. Development & Testing Tools

### Development Tools
| Tool | Version | Purpose | Used For |
|------|---------|---------|----------|
| **VS Code** | Latest | IDE | Primary editor |
| **Android Studio** | Latest | Android IDE | Android debugging |
| **Xcode** | 15+ | iOS IDE | iOS debugging |
| **DevTools** | Latest | Flutter debugger | Dart debugging, widget inspector |
| **Postman** | Latest | API testing | Manual API testing |
| **Insomnia** | Latest | REST client | Alternative API testing |
| **pgAdmin** | Latest | PostgreSQL UI | Database management, query testing |
| **DBeaver** | Latest | Database client | Advanced SQL queries |
| **Git & GitHub** | Latest | Version control | Source code management |

### Testing Frameworks
| Tool | Version | Purpose | Type |
|------|---------|---------|------|
| **flutter_test** | SDK | Widget testing | Unit tests |
| **integration_test** | SDK | End-to-end testing | E2E tests |
| **mockito** | 3.7.0+ | Mocking dependencies | Isolation testing |
| **mocktail** | 1.0.0+ | Type-safe mocking | Type-safe mocks |
| **patrol** | Latest | E2E testing (mobile) | Mobile app testing |

### Code Quality Tools
| Tool | Version | Purpose | Configuration |
|------|---------|---------|----------------|
| **flutter_lints** | 3.0.0+ | Linting | Enforces Dart best practices |
| **dart analyzer** | Latest | Static analysis | Code quality checks |
| **coverage** | Latest | Code coverage | Test coverage reporting |
| **SonarQube** | Latest | Code quality metrics | Enterprise code analysis (optional) |

---

## Architecture Diagram: Tools Interaction

```
┌─────────────────────────────────────────────────────────────────────┐
│                    COMPLETE TOOL ECOSYSTEM                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  CLIENT LAYER (Flutter + Dart)                              │  │
│  │  ├─ UI: Flutter 3.19+                                       │  │
│  │  ├─ State: Riverpod / Bloc                                  │  │
│  │  ├─ Storage: Hive + flutter_secure_storage                 │  │
│  │  ├─ Auth: local_auth + supabase_flutter                    │  │
│  │  └─ Network: dio + connectivity_plus                       │  │
│  └──────────────┬──────────────────────────────────────────────┘  │
│                 │                                                  │
│                 ▼                                                  │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  GATEWAY LAYER                                              │  │
│  │  ├─ Kong 3.0+ (rate limit, auth, routing)                  │  │
│  │  ├─ NGINX (load balance, SSL, cache)                       │  │
│  │  └─ Supabase Edge Functions                                │  │
│  └──────────────┬──────────────────────────────────────────────┘  │
│                 │                                                  │
│                 ▼                                                  │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  API LAYER                                                  │  │
│  │  ├─ PostgREST 12+ (auto REST API)                           │  │
│  │  ├─ Dart Frog / Serverpod (custom logic)                   │  │
│  │  ├─ Supabase GoTrue (auth)                                 │  │
│  │  └─ Supabase Realtime (WebSocket)                          │  │
│  └──────────────┬──────────────────────────────────────────────┘  │
│                 │                                                  │
│      ┌──────────┼──────────┬─────────────┐                       │
│      │          │          │             │                       │
│      ▼          ▼          ▼             ▼                       │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐                 │
│  │Database│ │Storage │ │ Real-  │ │Messaging │                 │
│  │        │ │        │ │Time    │ │          │                 │
│  │Postgre │ │MinIO   │ │Supabase│ │Redis/   │                 │
│  │SQL 15+ │ │/ S3    │ │RT      │ │Kafka    │                 │
│  └────────┘ └────────┘ └────────┘ └──────────┘                 │
│      │          │          │             │                       │
│      └──────────┼──────────┴─────────────┘                       │
│                 │                                                  │
│                 ▼                                                  │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  OBSERVABILITY LAYER                                        │  │
│  │  ├─ Logs: Elasticsearch + Logstash + Kibana                │  │
│  │  ├─ Metrics: Prometheus + Grafana                          │  │
│  │  ├─ Errors: Sentry / Firebase Crashlytics                 │  │
│  │  └─ Audit: PostgreSQL audit_trail table                   │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Tool Selection Matrix: Why Each Tool?

### Trade-offs Explained

| Category | Chosen | Alternative | Why Chosen |
|----------|--------|-------------|-----------|
| **Frontend** | Flutter | React Native | Write once, deploy everywhere; better performance |
| **Language** | Dart | Java/Kotlin, Swift | Same language frontend → backend; great for enterprise |
| **Database** | PostgreSQL | MongoDB, MySQL | ACID compliance required for pharma; better for complex queries |
| **State Mgmt** | Riverpod | GetX, Provider | Type-safe, testable, no context management |
| **Routing** | go_router | auto_route | Simpler, built-in Flutter support |
| **API Gateway** | Kong | Traefik, Ambassador | Mature, many enterprise features |
| **Realtime** | Supabase Realtime | Socket.io, Firebase | Built-in Supabase, low latency |
| **Backend** | Dart Frog | Node.js, Python | Stay in Dart ecosystem; maintain single language |
| **Storage** | MinIO | AWS S3, Google Cloud | Self-hosted option for on-premise; S3-compatible |

---

## Deployment Checklist: Required Tools

- [ ] **Docker** - Containerization
- [ ] **Docker Compose** - Local development
- [ ] **Kubernetes** - Production orchestration
- [ ] **Helm** - K8s package management
- [ ] **Terraform** - Infrastructure as code
- [ ] **GitHub Actions** - CI/CD pipeline
- [ ] **Prometheus** - Metrics collection
- [ ] **Grafana** - Metrics dashboards
- [ ] **ELK Stack** - Log aggregation
- [ ] **Sentry** - Error tracking

---

## Performance Targets & Tools Used

| Metric | Target | Tools Used |
|--------|--------|-----------|
| App launch | < 2 sec | Flutter code splitting, lazy loading |
| API response | < 100ms (p95) | PostgreSQL optimization, Redis cache |
| DB query | < 50ms (p95) | Indexes, connection pooling |
| Real-time update | < 500ms | Supabase Realtime, WebSocket |
| PDF generation | < 2 sec | pdf package, async processing |
| File upload | < 5 sec | MinIO, chunked upload |
| Certificate issuance | < 5 sec | Background jobs (pg_cron + BullMQ) |

---

## Cost Analysis

| Tool | Cost | Usage |
|------|------|-------|
| **PostgreSQL** | $0 (open-source) | Database |
| **Flutter** | $0 (open-source) | Frontend |
| **Dart** | $0 (open-source) | Backend |
| **Supabase** | $0 (self-hosted) or $100-1000/mo | Backend services |
| **MinIO** | $0 (open-source) | File storage |
| **Kong** | $0 (open-source) or $2000+/mo (Enterprise) | API Gateway |
| **Redis** | $0 (open-source) or $100-500/mo (managed) | Caching |
| **ELK Stack** | $0 (open-source) or $1000+/mo (managed) | Observability |
| **Vyuh Framework** | $500-5000/month | Enterprise packages |
| **Total (Self-Hosted)** | ~$2,000-5,000/month | All tools included |

---

## Integration Points: How Tools Talk

```
Flutter App (Dart)
    ├── HTTP (dio) → PostgREST API
    ├── WebSocket (Supabase Realtime) ← Real-time updates
    ├── Local Storage (Hive) ← Offline data
    └── Auth (supabase_flutter) → GoTrue

Kong Gateway
    ├── Route → PostgREST
    ├── Route → Dart Frog (custom endpoints)
    ├── Rate limit (Redis)
    └── Log to Elasticsearch

PostgreSQL
    ├── CRUD (PostgREST)
    ├── Events (LISTEN/NOTIFY)
    ├── Audit trail (append-only)
    ├── Jobs (pg_cron)
    └── Analytics (read replicas)

Supabase Realtime
    ├── Subscribe PostgreSQL changes
    ├── Broadcast events
    └── Deliver to connected clients

MinIO Storage
    ├── Store files
    ├── Generate URLs
    └── Integration with Flask/Django if needed

Redis (Optional)
    ├── Session cache
    ├── API response cache
    ├── Rate limit counters
    └── Pub/Sub messaging

Elasticsearch
    ├── Receive logs from Kong
    ├── Receive logs from applications
    └── Indexed search & visualization (Kibana)
```

---

## References

- **Flutter**: https://flutter.dev
- **Dart**: https://dart.dev
- **Supabase**: https://supabase.com
- **PostgreSQL**: https://www.postgresql.org
- **PostgREST**: https://postgrest.org
- **Kong**: https://konghq.com
- **Vyuh**: https://pub.vyuh.tech
- **Riverpod**: https://riverpod.dev
- **go_router**: https://pub.dev/packages/go_router

---

**Document Version:** 1.0  
**Last Updated:** 2026-04-24  
**Next Review:** 2026-05-24
