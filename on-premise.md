# PharmaLearn LMS — On-Premise Architecture Plan

> **Version:** 1.0  
> **Date:** 2026-04-23  
> **Stack:** Dart · Flutter · Supabase (Self-Hosted)  
> **Deployment:** On-Premise / Private Cloud  
> **Target:** 500-5,000 concurrent users  
> **Compliance:** 21 CFR Part 11 · EU Annex 11 · WHO GMP

---

## Executive Summary

This document defines a **simplified, on-premise architecture** for PharmaLearn LMS using a pure **Dart/Flutter + Supabase** stack. This architecture removes unnecessary enterprise complexity while maintaining full regulatory compliance.

### Why This Stack?

| Benefit | Description |
|---------|-------------|
| **Single Language** | Dart everywhere (frontend, backend, tooling) |
| **Cross-Platform** | Flutter for Web, iOS, Android, Desktop from one codebase |
| **Self-Hosted** | Supabase runs entirely on your infrastructure |
| **Regulatory Compliant** | Full audit trails, e-signatures, hash chaining |
| **Cost Effective** | ~$1,000-3,000/month infrastructure |

### 4 Core Modules

| Module | Purpose | Description |
|--------|---------|-------------|
| **CREATE** | Content Authoring | Documents, SOPs, courses, assessments |
| **ACCESS** | Identity & Auth | Users, roles, sessions, permissions |
| **TRAIN** | Training Delivery | Sessions, attendance, OJT, induction |
| **CERTIFY** | Certification | Assessments, competencies, certificates |

---

## Table of Contents

1. [Technology Stack](#1-technology-stack)
2. [Architecture Overview](#2-architecture-overview)
3. [Deployment Topology](#3-deployment-topology)
4. [Supabase Self-Hosted Setup](#4-supabase-self-hosted-setup)
5. [Flutter Application Architecture](#5-flutter-application-architecture)
6. [Dart Backend Services](#6-dart-backend-services)
7. [Database Architecture](#7-database-architecture)
8. [Authentication & Security](#8-authentication--security)
9. [Real-Time Features](#9-real-time-features)
10. [File Storage](#10-file-storage)
11. [Background Jobs](#11-background-jobs)
12. [Observability & Monitoring](#12-observability--monitoring)
13. [Compliance Architecture](#13-compliance-architecture)
14. [Infrastructure Requirements](#14-infrastructure-requirements)
15. [Implementation Roadmap](#15-implementation-roadmap)

---

## 1. Technology Stack

### Core Stack (Dart/Flutter + Supabase)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHARMALEARN ON-PREMISE STACK                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  FRONTEND (Flutter)                                                  │   │
│  │                                                                     │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐          │   │
│  │  │  Flutter  │ │  Flutter  │ │  Flutter  │ │  Flutter  │          │   │
│  │  │    Web    │ │  Android  │ │    iOS    │ │  Desktop  │          │   │
│  │  │           │ │           │ │           │ │ (Win/Mac) │          │   │
│  │  └───────────┘ └───────────┘ └───────────┘ └───────────┘          │   │
│  │                                                                     │   │
│  │  Packages:                                                          │   │
│  │  • supabase_flutter    • flutter_bloc      • go_router             │   │
│  │  • riverpod            • freezed           • dio                   │   │
│  │  • flutter_secure_storage                  • local_auth (biometric)│   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  BACKEND (Supabase Self-Hosted)                                     │   │
│  │                                                                     │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐          │   │
│  │  │ PostgreSQL│ │  PostgREST│ │  GoTrue   │ │  Realtime │          │   │
│  │  │    15+    │ │   (API)   │ │  (Auth)   │ │ (WebSocket)│          │   │
│  │  └───────────┘ └───────────┘ └───────────┘ └───────────┘          │   │
│  │                                                                     │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐          │   │
│  │  │  Storage  │ │   Kong    │ │  pg_cron  │ │ pg_graphql │          │   │
│  │  │  (S3/Min) │ │ (Gateway) │ │  (Jobs)   │ │ (GraphQL)  │          │   │
│  │  └───────────┘ └───────────┘ └───────────┘ └───────────┘          │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  DART BACKEND SERVICES (Optional - for complex logic)               │   │
│  │                                                                     │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐                        │   │
│  │  │  Serverpod│ │Dart Frog  │ │  Shelf    │  ← Pick one            │   │
│  │  │ (Full-feat)│ │(Lightweight)│ │ (Minimal) │                        │   │
│  │  └───────────┘ └───────────┘ └───────────┘                        │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Technology Matrix

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **Frontend** | Flutter | 3.19+ | Cross-platform UI |
| **State Management** | Riverpod / Bloc | Latest | Reactive state |
| **Routing** | go_router | 13+ | Declarative routing |
| **Database** | PostgreSQL | 15+ | Primary data store |
| **API** | PostgREST | 12+ | Auto-generated REST API |
| **Auth** | GoTrue | 2.0+ | Authentication service |
| **Realtime** | Supabase Realtime | Latest | WebSocket subscriptions |
| **Storage** | Supabase Storage | Latest | File management |
| **Gateway** | Kong | 3.0+ | API gateway, rate limiting |
| **Background Jobs** | pg_cron + pg_net | Latest | Scheduled tasks, webhooks |
| **Dart Backend** | Dart Frog / Serverpod | Latest | Custom business logic |
| **Caching** | Redis | 7+ | Session cache (optional) |

### Dart/Flutter Package Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Supabase
  supabase_flutter: ^2.5.0
  
  # State Management (choose one)
  flutter_riverpod: ^2.5.0
  # OR
  flutter_bloc: ^8.1.0
  
  # Navigation
  go_router: ^13.2.0
  
  # Data Classes
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  
  # Local Storage & Security
  flutter_secure_storage: ^9.0.0
  hive_flutter: ^1.1.0
  local_auth: ^2.2.0  # Biometric
  
  # Network
  dio: ^5.4.0
  connectivity_plus: ^6.0.0
  
  # PDF & Documents
  pdf: ^3.10.0
  printing: ^5.12.0
  syncfusion_flutter_pdfviewer: ^25.1.0
  
  # UI Components
  flutter_form_builder: ^9.2.0
  data_table_2: ^2.5.0
  fl_chart: ^0.66.0
  
  # Utilities
  intl: ^0.19.0
  logger: ^2.2.0
  uuid: ^4.3.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  flutter_lints: ^3.0.0
```

---

## 2. Architecture Overview

### Clean Architecture Pattern

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FLUTTER CLEAN ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PRESENTATION LAYER                                                  │   │
│  │                                                                     │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                   │   │
│  │  │   Screens   │ │   Widgets   │ │   Blocs/    │                   │   │
│  │  │   (Pages)   │ │ (Components)│ │  Providers  │                   │   │
│  │  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘                   │   │
│  │         │               │               │                           │   │
│  └─────────┼───────────────┼───────────────┼───────────────────────────┘   │
│            │               │               │                               │
│            ▼               ▼               ▼                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  DOMAIN LAYER                                                        │   │
│  │                                                                     │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                   │   │
│  │  │  Entities   │ │  Use Cases  │ │ Repositories│                   │   │
│  │  │  (Models)   │ │  (Business) │ │ (Interfaces)│                   │   │
│  │  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘                   │   │
│  │         │               │               │                           │   │
│  └─────────┼───────────────┼───────────────┼───────────────────────────┘   │
│            │               │               │                               │
│            ▼               ▼               ▼                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  DATA LAYER                                                          │   │
│  │                                                                     │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                   │   │
│  │  │  Supabase   │ │   Local     │ │   DTOs &    │                   │   │
│  │  │   Client    │ │   Storage   │ │   Mappers   │                   │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘                   │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Module Structure

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart
│
├── core/
│   ├── config/
│   │   ├── supabase_config.dart
│   │   └── app_config.dart
│   ├── constants/
│   ├── errors/
│   ├── utils/
│   └── widgets/                    # Shared widgets
│
├── features/
│   ├── create/                     # CREATE MODULE
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── bloc/
│   │       ├── pages/
│   │       └── widgets/
│   │
│   ├── access/                     # ACCESS MODULE
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── train/                      # TRAIN MODULE
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   └── certify/                    # CERTIFY MODULE
│       ├── data/
│       ├── domain/
│       └── presentation/
│
└── shared/
    ├── models/
    ├── services/
    └── providers/
```

---

## 3. Deployment Topology

### On-Premise Server Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ON-PREMISE DEPLOYMENT TOPOLOGY                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  DMZ (Demilitarized Zone)                                           │   │
│  │                                                                     │   │
│  │  ┌───────────────────────────────────────────────────────────────┐ │   │
│  │  │  NGINX / HAProxy                                               │ │   │
│  │  │  • SSL Termination                                             │ │   │
│  │  │  • Load Balancing                                              │ │   │
│  │  │  • Rate Limiting                                               │ │   │
│  │  │  • Static File Serving (Flutter Web)                          │ │   │
│  │  └───────────────────────────────────────────────────────────────┘ │   │
│  │                              │                                     │   │
│  └──────────────────────────────┼─────────────────────────────────────┘   │
│                                 │                                          │
│  ┌──────────────────────────────┼─────────────────────────────────────┐   │
│  │  APPLICATION ZONE            ▼                                      │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  SERVER 1: Supabase Stack (Docker Compose)                  │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐          │   │   │
│  │  │  │  Kong   │ │PostgREST│ │ GoTrue  │ │Realtime │          │   │   │
│  │  │  │  :8000  │ │  :3000  │ │  :9999  │ │  :4000  │          │   │   │
│  │  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘          │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐                      │   │   │
│  │  │  │ Storage │ │ Studio  │ │  Meta   │                      │   │   │
│  │  │  │  :5000  │ │  :3001  │ │  :8080  │                      │   │   │
│  │  │  └─────────┘ └─────────┘ └─────────┘                      │   │   │
│  │  │                                                             │   │   │
│  │  │  RAM: 16GB | CPU: 8 cores | Disk: 500GB SSD               │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  SERVER 2: Dart Backend (Optional - for complex logic)     │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────────────────────────────────────────────────┐   │   │   │
│  │  │  │  Dart Frog / Serverpod                              │   │   │   │
│  │  │  │  • E-Signature validation                           │   │   │   │
│  │  │  │  • PDF generation                                   │   │   │   │
│  │  │  │  • Complex calculations                             │   │   │   │
│  │  │  │  • SCORM processing                                 │   │   │   │
│  │  │  └─────────────────────────────────────────────────────┘   │   │   │
│  │  │                                                             │   │   │
│  │  │  RAM: 8GB | CPU: 4 cores | Disk: 100GB SSD                │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  DATA ZONE                                                          │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  SERVER 3: PostgreSQL Primary                               │   │   │
│  │  │                                                             │   │   │
│  │  │  • PostgreSQL 15 + pg_cron + pg_net + pgvector             │   │   │
│  │  │  • WAL archiving enabled                                   │   │   │
│  │  │  • Point-in-Time Recovery                                  │   │   │
│  │  │  • Daily encrypted backups                                 │   │   │
│  │  │                                                             │   │   │
│  │  │  RAM: 32GB | CPU: 8 cores | Disk: 1TB NVMe                │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  SERVER 4: PostgreSQL Replica (HA) + Redis                  │   │   │
│  │  │                                                             │   │   │
│  │  │  • Streaming replication from Primary                      │   │   │
│  │  │  • Read-only queries                                       │   │   │
│  │  │  • Redis 7 for session cache                               │   │   │
│  │  │                                                             │   │   │
│  │  │  RAM: 16GB | CPU: 4 cores | Disk: 1TB NVMe                │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STORAGE ZONE                                                       │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  NAS / MinIO Cluster                                        │   │   │
│  │  │                                                             │   │   │
│  │  │  • Document storage (SOPs, WIs, Policies)                  │   │   │
│  │  │  • Training videos                                         │   │   │
│  │  │  • Certificate PDFs                                        │   │   │
│  │  │  • SCORM packages                                          │   │   │
│  │  │                                                             │   │   │
│  │  │  Capacity: 5TB+ | RAID 10 | Encrypted at rest             │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Minimum vs Recommended Topology

| Setup | Servers | Users | Use Case |
|-------|---------|-------|----------|
| **Minimal** | 2 | < 500 | Small pharma, pilot |
| **Standard** | 4 | 500-2,000 | Medium pharma |
| **High Availability** | 6+ | 2,000-5,000 | Large pharma |

---

## 4. Supabase Self-Hosted Setup

### Docker Compose Configuration

```yaml
# docker-compose.yml for Supabase Self-Hosted
version: '3.8'

services:
  # Kong API Gateway
  kong:
    image: kong:3.4
    restart: always
    ports:
      - "8000:8000"   # HTTP
      - "8443:8443"   # HTTPS
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /kong/kong.yml
      KONG_DNS_ORDER: LAST,A,CNAME
      KONG_PLUGINS: request-transformer,cors,key-auth,acl,rate-limiting
    volumes:
      - ./kong/kong.yml:/kong/kong.yml:ro

  # PostgREST API
  rest:
    image: postgrest/postgrest:v12.0.2
    restart: always
    depends_on:
      db:
        condition: service_healthy
    environment:
      PGRST_DB_URI: postgres://authenticator:${POSTGRES_PASSWORD}@db:5432/postgres
      PGRST_DB_ANON_ROLE: anon
      PGRST_DB_SCHEMA: public,storage,graphql_public
      PGRST_JWT_SECRET: ${JWT_SECRET}
      PGRST_DB_USE_LEGACY_GUCS: "false"

  # GoTrue Auth
  auth:
    image: supabase/gotrue:v2.151.0
    restart: always
    depends_on:
      db:
        condition: service_healthy
    environment:
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_API_PORT: 9999
      GOTRUE_DB_DATABASE_URL: postgres://supabase_auth_admin:${POSTGRES_PASSWORD}@db:5432/postgres
      GOTRUE_SITE_URL: ${SITE_URL}
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      GOTRUE_JWT_EXP: 3600
      GOTRUE_JWT_DEFAULT_GROUP_NAME: authenticated
      
      # Email
      GOTRUE_SMTP_HOST: ${SMTP_HOST}
      GOTRUE_SMTP_PORT: ${SMTP_PORT}
      GOTRUE_SMTP_USER: ${SMTP_USER}
      GOTRUE_SMTP_PASS: ${SMTP_PASS}
      GOTRUE_SMTP_SENDER_NAME: PharmaLearn
      
      # Security
      GOTRUE_SECURITY_REFRESH_TOKEN_ROTATION_ENABLED: true
      GOTRUE_SECURITY_REFRESH_TOKEN_REUSE_INTERVAL: 10
      GOTRUE_PASSWORD_MIN_LENGTH: 12
      
      # MFA
      GOTRUE_MFA_ENABLED: true
      GOTRUE_MFA_CHALLENGE_AND_VERIFY_RATE_LIMIT: 15

  # Realtime
  realtime:
    image: supabase/realtime:v2.28.32
    restart: always
    depends_on:
      db:
        condition: service_healthy
    environment:
      PORT: 4000
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: supabase_admin
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: postgres
      DB_AFTER_CONNECT_QUERY: 'SET search_path TO _realtime'
      DB_ENC_KEY: ${DB_ENC_KEY}
      API_JWT_SECRET: ${JWT_SECRET}
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}

  # Storage
  storage:
    image: supabase/storage-api:v0.46.4
    restart: always
    depends_on:
      db:
        condition: service_healthy
    environment:
      ANON_KEY: ${ANON_KEY}
      SERVICE_KEY: ${SERVICE_ROLE_KEY}
      POSTGREST_URL: http://rest:3000
      PGRST_JWT_SECRET: ${JWT_SECRET}
      DATABASE_URL: postgres://supabase_storage_admin:${POSTGRES_PASSWORD}@db:5432/postgres
      FILE_SIZE_LIMIT: 52428800  # 50MB
      STORAGE_BACKEND: file
      FILE_STORAGE_BACKEND_PATH: /var/lib/storage
      GLOBAL_S3_BUCKET: pharmalearn
    volumes:
      - ./storage:/var/lib/storage

  # PostgreSQL Database
  db:
    image: supabase/postgres:15.1.1.41
    restart: always
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: postgres
      JWT_SECRET: ${JWT_SECRET}
      JWT_EXP: 3600
    volumes:
      - ./postgres/data:/var/lib/postgresql/data
      - ./postgres/init:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    command:
      - postgres
      - -c
      - wal_level=replica
      - -c
      - max_wal_senders=10
      - -c
      - max_replication_slots=10
      - -c
      - shared_preload_libraries=pg_cron,pg_net

  # Supabase Studio (Admin UI)
  studio:
    image: supabase/studio:20240326-5e5586d
    restart: always
    ports:
      - "3001:3000"
    environment:
      STUDIO_PG_META_URL: http://meta:8080
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      DEFAULT_ORGANIZATION_NAME: PharmaLearn
      DEFAULT_PROJECT_NAME: pharmalearn-lms
      SUPABASE_URL: http://kong:8000
      SUPABASE_PUBLIC_URL: ${SUPABASE_PUBLIC_URL}
      SUPABASE_ANON_KEY: ${ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}

  # Postgres Meta (for Studio)
  meta:
    image: supabase/postgres-meta:v0.80.0
    restart: always
    depends_on:
      db:
        condition: service_healthy
    environment:
      PG_META_PORT: 8080
      PG_META_DB_HOST: db
      PG_META_DB_PORT: 5432
      PG_META_DB_NAME: postgres
      PG_META_DB_USER: supabase_admin
      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD}

  # Redis (for session caching)
  redis:
    image: redis:7-alpine
    restart: always
    ports:
      - "6379:6379"
    volumes:
      - ./redis/data:/data
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}

volumes:
  postgres_data:
  storage_data:
  redis_data:

networks:
  default:
    name: pharmalearn-network
```

### Environment Variables (.env)

```bash
# .env file for Supabase Self-Hosted

# PostgreSQL
POSTGRES_PASSWORD=your-super-secret-password-min-32-chars

# JWT (Generate with: openssl rand -base64 32)
JWT_SECRET=your-jwt-secret-min-32-characters-long
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...  # Generate these
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Site
SITE_URL=https://pharmalearn.yourcompany.com
SUPABASE_PUBLIC_URL=https://api.pharmalearn.yourcompany.com

# SMTP (for emails)
SMTP_HOST=smtp.yourcompany.com
SMTP_PORT=587
SMTP_USER=pharmalearn@yourcompany.com
SMTP_PASS=your-smtp-password

# Encryption
DB_ENC_KEY=your-32-character-encryption-key
SECRET_KEY_BASE=your-secret-key-base-for-realtime

# Redis
REDIS_PASSWORD=your-redis-password
```

---

## 5. Flutter Application Architecture

### Supabase Client Configuration

```dart
// lib/core/config/supabase_config.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
      storageOptions: const StorageClientOptions(
        retryAttempts: 3,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;
  static RealtimeClient get realtime => client.realtime;
}
```

### Repository Pattern with Supabase

```dart
// lib/features/create/data/repositories/document_repository_impl.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/document.dart';
import '../../domain/repositories/document_repository.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final SupabaseClient _client;

  DocumentRepositoryImpl(this._client);

  @override
  Future<List<Document>> getDocuments({
    required String organizationId,
    String? categoryId,
    DocumentStatus? status,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client
        .from('documents')
        .select('''
          *,
          category:document_categories(*),
          current_version:document_versions!inner(*),
          owner:employees!documents_owner_id_fkey(*)
        ''')
        .eq('organization_id', organizationId);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (status != null) {
      query = query.eq('status', status.name);
    }

    final response = await query
        .order('updated_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => Document.fromJson(json))
        .toList();
  }

  @override
  Future<Document> getDocument(String id) async {
    final response = await _client
        .from('documents')
        .select('''
          *,
          category:document_categories(*),
          versions:document_versions(*),
          owner:employees!documents_owner_id_fkey(*),
          reviewers:document_reviewers(*, employee:employees(*)),
          approvers:document_approvers(*, employee:employees(*))
        ''')
        .eq('id', id)
        .single();

    return Document.fromJson(response);
  }

  @override
  Future<Document> createDocument(CreateDocumentRequest request) async {
    final response = await _client
        .from('documents')
        .insert({
          'document_number': request.documentNumber,
          'title': request.title,
          'document_type': request.documentType.name,
          'category_id': request.categoryId,
          'owner_id': request.ownerId,
          'organization_id': request.organizationId,
          'plant_id': request.plantId,
        })
        .select()
        .single();

    return Document.fromJson(response);
  }

  @override
  Future<void> createVersion(String documentId, CreateVersionRequest request) async {
    await _client.from('document_versions').insert({
      'document_id': documentId,
      'version_number': request.versionNumber,
      'content': request.content,
      'change_summary': request.changeSummary,
      'created_by': request.createdBy,
    });
  }

  @override
  Stream<List<Document>> watchDocuments(String organizationId) {
    return _client
        .from('documents')
        .stream(primaryKey: ['id'])
        .eq('organization_id', organizationId)
        .order('updated_at', ascending: false)
        .map((data) => data.map((json) => Document.fromJson(json)).toList());
  }
}
```

### State Management with Riverpod

```dart
// lib/features/create/presentation/providers/document_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/document.dart';
import '../../domain/repositories/document_repository.dart';
import '../../data/repositories/document_repository_impl.dart';
import '../../../../core/config/supabase_config.dart';

// Repository Provider
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepositoryImpl(SupabaseConfig.client);
});

// Documents List Provider
final documentsProvider = FutureProvider.family<List<Document>, DocumentFilter>(
  (ref, filter) async {
    final repository = ref.watch(documentRepositoryProvider);
    return repository.getDocuments(
      organizationId: filter.organizationId,
      categoryId: filter.categoryId,
      status: filter.status,
    );
  },
);

// Single Document Provider
final documentProvider = FutureProvider.family<Document, String>(
  (ref, id) async {
    final repository = ref.watch(documentRepositoryProvider);
    return repository.getDocument(id);
  },
);

// Real-time Documents Stream
final documentsStreamProvider = StreamProvider.family<List<Document>, String>(
  (ref, organizationId) {
    final repository = ref.watch(documentRepositoryProvider);
    return repository.watchDocuments(organizationId);
  },
);

// Document Actions Notifier
class DocumentNotifier extends StateNotifier<AsyncValue<Document?>> {
  final DocumentRepository _repository;

  DocumentNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> createDocument(CreateDocumentRequest request) async {
    state = const AsyncValue.loading();
    try {
      final document = await _repository.createDocument(request);
      state = AsyncValue.data(document);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> submitForReview(String documentId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.submitForReview(documentId);
      final document = await _repository.getDocument(documentId);
      state = AsyncValue.data(document);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final documentNotifierProvider =
    StateNotifierProvider<DocumentNotifier, AsyncValue<Document?>>((ref) {
  final repository = ref.watch(documentRepositoryProvider);
  return DocumentNotifier(repository);
});
```

### Entity Models with Freezed

```dart
// lib/features/create/domain/entities/document.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'document.freezed.dart';
part 'document.g.dart';

enum DocumentType { sop, wi, policy, form, specification }
enum DocumentStatus { draft, underReview, approved, effective, retired }

@freezed
class Document with _$Document {
  const factory Document({
    required String id,
    required String documentNumber,
    required String title,
    required DocumentType documentType,
    required DocumentStatus status,
    required String categoryId,
    required String ownerId,
    required String organizationId,
    String? plantId,
    DocumentCategory? category,
    Employee? owner,
    DocumentVersion? currentVersion,
    List<DocumentVersion>? versions,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Document;

  factory Document.fromJson(Map<String, dynamic> json) =>
      _$DocumentFromJson(json);
}

@freezed
class DocumentVersion with _$DocumentVersion {
  const factory DocumentVersion({
    required String id,
    required String documentId,
    required String versionNumber,
    required String content,
    String? changeSummary,
    required String createdBy,
    required DateTime createdAt,
    String? integrityHash,
    String? prevVersionHash,
  }) = _DocumentVersion;

  factory DocumentVersion.fromJson(Map<String, dynamic> json) =>
      _$DocumentVersionFromJson(json);
}

@freezed
class CreateDocumentRequest with _$CreateDocumentRequest {
  const factory CreateDocumentRequest({
    required String documentNumber,
    required String title,
    required DocumentType documentType,
    required String categoryId,
    required String ownerId,
    required String organizationId,
    String? plantId,
  }) = _CreateDocumentRequest;

  factory CreateDocumentRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateDocumentRequestFromJson(json);
}
```

---

## 6. Dart Backend Services

### Option 1: Dart Frog (Lightweight)

```dart
// routes/api/v1/esignature/sign.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:supabase/supabase.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final supabase = context.read<SupabaseClient>();
  final user = context.read<AuthUser>();
  
  final body = await context.request.json() as Map<String, dynamic>;
  final entityType = body['entity_type'] as String;
  final entityId = body['entity_id'] as String;
  final meaning = body['meaning'] as String;
  final reason = body['reason'] as String?;
  final password = body['password'] as String;

  // 1. Re-authenticate password
  final authResult = await supabase.auth.signInWithPassword(
    email: user.email!,
    password: password,
  );
  
  if (authResult.session == null) {
    return Response.json(
      body: {'error': 'Password verification failed'},
      statusCode: 401,
    );
  }

  // 2. Fetch entity for snapshot
  final entityData = await supabase
      .from(entityType)
      .select()
      .eq('id', entityId)
      .single();

  // 3. Calculate integrity hash
  final dataSnapshot = jsonEncode(entityData);
  final hashInput = '$dataSnapshot|$meaning|${reason ?? ""}|${DateTime.now().toIso8601String()}';
  final integrityHash = sha256.convert(utf8.encode(hashInput)).toString();

  // 4. Get employee details
  final employee = await supabase
      .from('employees')
      .select()
      .eq('user_id', user.id)
      .single();

  // 5. Get previous signature for chain
  final prevSig = await supabase
      .from('electronic_signatures')
      .select('id')
      .eq('employee_id', employee['id'])
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();

  // 6. Create signature record
  final signature = await supabase
      .from('electronic_signatures')
      .insert({
        'employee_id': employee['id'],
        'employee_name': employee['employee_name'],
        'employee_email': employee['email'],
        'employee_title': employee['job_title'],
        'employee_id_code': employee['employee_code'],
        'meaning': meaning,
        'reason': reason,
        'entity_type': entityType,
        'entity_id': entityId,
        'integrity_hash': integrityHash,
        'data_snapshot': entityData,
        'password_reauth_verified': true,
        'prev_signature_id': prevSig?['id'],
        'is_valid': true,
        'organization_id': employee['organization_id'],
        'plant_id': employee['plant_id'],
      })
      .select()
      .single();

  // 7. Emit audit event
  await supabase.from('audit_trails').insert({
    'table_name': entityType,
    'record_id': entityId,
    'action': 'ESIGN',
    'actor_id': employee['id'],
    'new_values': {'signature_id': signature['id'], 'meaning': meaning},
    'organization_id': employee['organization_id'],
  });

  return Response.json(body: {'signature': signature});
}
```

### Option 2: Serverpod (Full-Featured)

```dart
// lib/src/endpoints/training_endpoint.dart

import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

class TrainingEndpoint extends Endpoint {
  /// Start a training session with compliance tracking
  Future<TrainingSession> startSession(
    Session session,
    String assignmentId,
  ) async {
    final employee = await _getEmployee(session);
    
    // Get assignment
    final assignment = await TrainingAssignment.db.findById(
      session,
      int.parse(assignmentId),
    );
    
    if (assignment == null) {
      throw Exception('Assignment not found');
    }

    // Check prerequisites
    final prereqsMet = await _checkPrerequisites(
      session,
      employee.id!,
      assignment.courseId,
    );
    
    if (!prereqsMet) {
      throw Exception('Prerequisites not completed');
    }

    // Create session
    final trainingSession = TrainingSession(
      assignmentId: assignment.id!,
      employeeId: employee.id!,
      startTime: DateTime.now(),
      status: SessionStatus.inProgress,
      organizationId: employee.organizationId,
    );

    final created = await TrainingSession.db.insertRow(session, trainingSession);

    // Log to audit
    await _logAudit(
      session,
      'training_sessions',
      created.id.toString(),
      'START_SESSION',
      employee.id!,
      {'assignment_id': assignmentId},
    );

    return created;
  }

  /// Complete session and trigger assessment if required
  Future<TrainingSession> completeSession(
    Session session,
    String sessionId,
    int scrollPercentage,
    int timeSpentSeconds,
  ) async {
    final employee = await _getEmployee(session);
    
    final trainingSession = await TrainingSession.db.findById(
      session,
      int.parse(sessionId),
    );
    
    if (trainingSession == null || 
        trainingSession.employeeId != employee.id) {
      throw Exception('Session not found or unauthorized');
    }

    // Update session
    trainingSession
      ..endTime = DateTime.now()
      ..scrollPercentage = scrollPercentage
      ..timeSpentSeconds = timeSpentSeconds
      ..status = SessionStatus.completed;

    final updated = await TrainingSession.db.updateRow(session, trainingSession);

    // Check if assessment required
    final assignment = await TrainingAssignment.db.findById(
      session,
      trainingSession.assignmentId,
    );
    
    final course = await Course.db.findById(session, assignment!.courseId);
    
    if (course!.requiresAssessment) {
      // Create assessment attempt
      await _createAssessmentAttempt(session, updated, employee);
    } else {
      // Auto-complete assignment
      await _completeAssignment(session, assignment, employee);
    }

    return updated;
  }

  Future<Employee> _getEmployee(Session session) async {
    final userId = await session.auth.authenticatedUserId;
    if (userId == null) throw Exception('Not authenticated');
    
    final employee = await Employee.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId),
    );
    
    if (employee == null) throw Exception('Employee not found');
    return employee;
  }

  Future<bool> _checkPrerequisites(
    Session session,
    int employeeId,
    int courseId,
  ) async {
    final prereqs = await CoursePrerequisite.db.find(
      session,
      where: (t) => t.courseId.equals(courseId),
    );

    for (final prereq in prereqs) {
      final completed = await TrainingAssignment.db.findFirstRow(
        session,
        where: (t) =>
            t.employeeId.equals(employeeId) &
            t.courseId.equals(prereq.prerequisiteCourseId) &
            t.status.equals(AssignmentStatus.completed),
      );
      
      if (completed == null) return false;
    }

    return true;
  }

  Future<void> _logAudit(
    Session session,
    String tableName,
    String recordId,
    String action,
    int actorId,
    Map<String, dynamic> newValues,
  ) async {
    await AuditTrail.db.insertRow(
      session,
      AuditTrail(
        tableName: tableName,
        recordId: recordId,
        action: action,
        actorId: actorId,
        newValues: newValues,
        timestamp: DateTime.now(),
      ),
    );
  }
}
```

---

## 7. Database Architecture

### Schema Organization (Same as Enterprise)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DATABASE SCHEMA STRUCTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  FOUNDATION SCHEMAS (01-04)                                                 │
│  ├── 01_foundation     → organizations, plants, departments                │
│  ├── 02_employees      → employees, employment_history, qualifications     │
│  ├── 03_roles          → roles, permissions, role_assignments              │
│  └── 04_audit          → audit_trails, electronic_signatures, sessions     │
│                                                                             │
│  CREATE MODULE (05-07)                                                      │
│  ├── 05_documents      → documents, versions, acknowledgements             │
│  ├── 06_courses        → courses, modules, lessons, questions              │
│  └── 07_assessments    → assessments, question_banks, rubrics              │
│                                                                             │
│  TRAIN MODULE (08-10)                                                       │
│  ├── 08_training       → training_plans, curricula, assignments            │
│  ├── 09_classroom      → classroom_sessions, attendance, ojt               │
│  └── 10_induction      → induction_programs, checklists, progress          │
│                                                                             │
│  CERTIFY MODULE (11-13)                                                     │
│  ├── 11_certification  → certificates, competencies, validity              │
│  ├── 12_compliance     → compliance_rules, gaps, exemptions                │
│  └── 13_analytics      → dashboards, reports, materialized_views           │
│                                                                             │
│  INFRASTRUCTURE (14-17)                                                     │
│  ├── 14_notifications  → templates, queue, delivery_log                    │
│  ├── 15_integrations   → connectors, sync_log, webhooks                    │
│  ├── 16_workflow       → definitions, instances, tasks                     │
│  └── 17_config         → settings, feature_flags, localization             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Row Level Security (RLS) Policies

```sql
-- RLS policies for multi-tenant isolation

-- Enable RLS on all tables
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE certificates ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user's organization
CREATE OR REPLACE FUNCTION auth.organization_id()
RETURNS UUID AS $$
  SELECT (auth.jwt() -> 'app_metadata' ->> 'organization_id')::UUID;
$$ LANGUAGE SQL STABLE;

-- Helper function to get current employee ID
CREATE OR REPLACE FUNCTION auth.employee_id()
RETURNS UUID AS $$
  SELECT (auth.jwt() -> 'app_metadata' ->> 'employee_id')::UUID;
$$ LANGUAGE SQL STABLE;

-- Documents: Users can only see documents in their organization
CREATE POLICY "documents_org_isolation" ON documents
  FOR ALL
  USING (organization_id = auth.organization_id());

-- Training Assignments: Users see their own + managers see team's
CREATE POLICY "assignments_self_or_team" ON training_assignments
  FOR SELECT
  USING (
    employee_id = auth.employee_id()
    OR EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = training_assignments.employee_id
      AND e.reporting_manager_id = auth.employee_id()
    )
  );

-- Certificates: Public within organization
CREATE POLICY "certificates_org_read" ON certificates
  FOR SELECT
  USING (organization_id = auth.organization_id());

-- Audit trails: Read-only, append-only
CREATE POLICY "audit_read_only" ON audit_trails
  FOR SELECT
  USING (organization_id = auth.organization_id());

CREATE POLICY "audit_insert_only" ON audit_trails
  FOR INSERT
  WITH CHECK (organization_id = auth.organization_id());

-- Prevent updates and deletes on audit trails
CREATE POLICY "audit_no_update" ON audit_trails
  FOR UPDATE
  USING (false);

CREATE POLICY "audit_no_delete" ON audit_trails
  FOR DELETE
  USING (false);
```

### Hash Chaining for Compliance

```sql
-- Trigger for hash-chained audit trails

CREATE OR REPLACE FUNCTION calculate_audit_hash()
RETURNS TRIGGER AS $$
DECLARE
  prev_hash TEXT;
  hash_input TEXT;
BEGIN
  -- Get previous hash in chain
  SELECT integrity_hash INTO prev_hash
  FROM audit_trails
  WHERE organization_id = NEW.organization_id
  ORDER BY created_at DESC, id DESC
  LIMIT 1;

  -- Build hash input
  hash_input := COALESCE(prev_hash, 'GENESIS') || '|' ||
                NEW.table_name || '|' ||
                NEW.record_id || '|' ||
                NEW.action || '|' ||
                COALESCE(NEW.actor_id::text, 'SYSTEM') || '|' ||
                COALESCE(NEW.new_values::text, '{}') || '|' ||
                NEW.created_at::text;

  -- Calculate SHA-256 hash
  NEW.prev_hash := prev_hash;
  NEW.integrity_hash := encode(sha256(hash_input::bytea), 'hex');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_hash_trigger
  BEFORE INSERT ON audit_trails
  FOR EACH ROW
  EXECUTE FUNCTION calculate_audit_hash();
```

---

## 8. Authentication & Security

### Flutter Auth Implementation

```dart
// lib/features/access/data/services/auth_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client;
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;

  AuthService(this._client)
      : _secureStorage = const FlutterSecureStorage(),
        _localAuth = LocalAuthentication();

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.session != null) {
      // Store session securely
      await _secureStorage.write(
        key: 'refresh_token',
        value: response.session!.refreshToken,
      );

      // Log session start
      await _logSessionStart(response.user!.id);
    }

    return response;
  }

  /// Sign in with MFA verification
  Future<AuthMFAVerifyResponse> verifyMFA({
    required String factorId,
    required String code,
  }) async {
    return await _client.auth.mfa.verify(
      factorId: factorId,
      code: code,
    );
  }

  /// Enroll MFA (TOTP)
  Future<AuthMFAEnrollResponse> enrollMFA() async {
    return await _client.auth.mfa.enroll(
      factorType: FactorType.totp,
      friendlyName: 'PharmaLearn Authenticator',
    );
  }

  /// Biometric authentication for e-signatures
  Future<bool> authenticateBiometric({
    required String reason,
  }) async {
    final canAuth = await _localAuth.canCheckBiometrics;
    if (!canAuth) return false;

    return await _localAuth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );
  }

  /// Re-authenticate for e-signature (password + optional biometric)
  Future<bool> reAuthenticateForSignature({
    required String password,
    bool requireBiometric = false,
  }) async {
    // 1. Verify password
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client.auth.signInWithPassword(
        email: user.email!,
        password: password,
      );
    } catch (e) {
      return false;
    }

    // 2. Verify biometric if required
    if (requireBiometric) {
      final bioAuth = await authenticateBiometric(
        reason: 'Verify your identity to apply electronic signature',
      );
      if (!bioAuth) return false;
    }

    return true;
  }

  /// Sign out and cleanup
  Future<void> signOut() async {
    // Log session end
    await _logSessionEnd();

    // Clear secure storage
    await _secureStorage.deleteAll();

    // Sign out from Supabase
    await _client.auth.signOut();
  }

  /// Refresh session
  Future<void> refreshSession() async {
    final refreshToken = await _secureStorage.read(key: 'refresh_token');
    if (refreshToken != null) {
      await _client.auth.refreshSession();
    }
  }

  Future<void> _logSessionStart(String userId) async {
    await _client.from('session_chains').insert({
      'user_id': userId,
      'login_timestamp': DateTime.now().toIso8601String(),
      'ip_address': await _getIpAddress(),
      'user_agent': await _getUserAgent(),
    });
  }

  Future<void> _logSessionEnd() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('session_chains')
        .update({'logout_timestamp': DateTime.now().toIso8601String()})
        .eq('user_id', user.id)
        .isFilter('logout_timestamp', null)
        .order('login_timestamp', ascending: false)
        .limit(1);
  }

  Future<String> _getIpAddress() async {
    // Implement IP detection
    return '0.0.0.0';
  }

  Future<String> _getUserAgent() async {
    // Implement user agent detection
    return 'Flutter/PharmaLearn';
  }
}
```

### E-Signature Widget

```dart
// lib/features/access/presentation/widgets/e_signature_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

class ESignatureDialog extends ConsumerStatefulWidget {
  final String entityType;
  final String entityId;
  final String meaning;
  final String meaningDisplay;
  final bool requiresBiometric;
  final Function(Map<String, dynamic> signature) onSigned;

  const ESignatureDialog({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.meaning,
    required this.meaningDisplay,
    this.requiresBiometric = false,
    required this.onSigned,
  });

  @override
  ConsumerState<ESignatureDialog> createState() => _ESignatureDialogState();
}

class _ESignatureDialogState extends ConsumerState<ESignatureDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return AlertDialog(
      title: const Text('Electronic Signature Required'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Signature meaning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'By signing, I confirm:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.meaningDisplay,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Signer info
              Text(
                'Signing as:',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                user?.name ?? '',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                user?.title ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                DateTime.now().toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 24),

              // Password field
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Enter Password to Sign',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Reason field (optional for some meanings)
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason for signing (optional)',
                  prefixIcon: Icon(Icons.comment),
                  border: OutlineInputBorder(),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ],

              const SizedBox(height: 16),

              // Compliance notice
              Text(
                '21 CFR Part 11 Compliant Electronic Signature',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _sign,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.draw),
          label: const Text('Apply Signature'),
        ),
      ],
    );
  }

  Future<void> _sign() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // Re-authenticate
      final authenticated = await authService.reAuthenticateForSignature(
        password: _passwordController.text,
        requireBiometric: widget.requiresBiometric,
      );

      if (!authenticated) {
        setState(() {
          _error = 'Authentication failed. Please check your password.';
          _isLoading = false;
        });
        return;
      }

      // Apply signature via API
      final signatureService = ref.read(signatureServiceProvider);
      final signature = await signatureService.sign(
        entityType: widget.entityType,
        entityId: widget.entityId,
        meaning: widget.meaning,
        reason: _reasonController.text.isNotEmpty ? _reasonController.text : null,
      );

      widget.onSigned(signature);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to apply signature: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}
```

---

## 9. Real-Time Features

### Supabase Realtime Integration

```dart
// lib/core/services/realtime_service.dart

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};

  RealtimeService(this._client);

  /// Subscribe to document changes
  Stream<List<Map<String, dynamic>>> subscribeToDocuments(String organizationId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    final channel = _client
        .channel('documents:$organizationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'documents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'organization_id',
            value: organizationId,
          ),
          callback: (payload) {
            controller.add([payload.newRecord]);
          },
        )
        .subscribe();

    _channels['documents:$organizationId'] = channel;

    return controller.stream;
  }

  /// Subscribe to training assignments for an employee
  Stream<Map<String, dynamic>> subscribeToAssignments(String employeeId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    final channel = _client
        .channel('assignments:$employeeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'training_assignments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'employee_id',
            value: employeeId,
          ),
          callback: (payload) {
            controller.add(payload.newRecord);
          },
        )
        .subscribe();

    _channels['assignments:$employeeId'] = channel;

    return controller.stream;
  }

  /// Subscribe to notifications
  Stream<Map<String, dynamic>> subscribeToNotifications(String userId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    final channel = _client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notification_queue',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) {
            controller.add(payload.newRecord);
          },
        )
        .subscribe();

    _channels['notifications:$userId'] = channel;

    return controller.stream;
  }

  /// Presence for live training sessions
  Future<RealtimeChannel> joinTrainingSession(
    String sessionId,
    Map<String, dynamic> userInfo,
  ) async {
    final channel = _client.channel(
      'training_session:$sessionId',
      opts: const RealtimeChannelConfig(self: true),
    );

    channel
        .onPresenceSync((payload) {
          // Handle presence sync
        })
        .onPresenceJoin((payload) {
          // Handle user joined
        })
        .onPresenceLeave((payload) {
          // Handle user left
        })
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await channel.track(userInfo);
          }
        });

    _channels['training_session:$sessionId'] = channel;
    return channel;
  }

  /// Broadcast to training session
  Future<void> broadcastToSession(String sessionId, String event, Map<String, dynamic> payload) async {
    final channel = _channels['training_session:$sessionId'];
    if (channel != null) {
      await channel.sendBroadcastMessage(
        event: event,
        payload: payload,
      );
    }
  }

  /// Unsubscribe from channel
  Future<void> unsubscribe(String channelKey) async {
    final channel = _channels.remove(channelKey);
    if (channel != null) {
      await channel.unsubscribe();
    }
  }

  /// Unsubscribe from all channels
  Future<void> unsubscribeAll() async {
    for (final channel in _channels.values) {
      await channel.unsubscribe();
    }
    _channels.clear();
  }
}
```

---

## 10. File Storage

### Supabase Storage Service

```dart
// lib/core/services/storage_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class StorageService {
  final SupabaseClient _client;

  StorageService(this._client);

  // Storage buckets
  static const String documentsBucket = 'documents';
  static const String coursesBucket = 'courses';
  static const String certificatesBucket = 'certificates';
  static const String profilesBucket = 'profiles';
  static const String scormBucket = 'scorm';

  /// Upload document file with hash verification
  Future<StorageUploadResult> uploadDocument({
    required String organizationId,
    required String documentId,
    required String versionId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    // Calculate file hash for integrity
    final fileHash = sha256.convert(fileBytes).toString();

    // Build path: org_id/doc_id/version_id/filename
    final filePath = '$organizationId/$documentId/$versionId/$fileName';

    // Upload to Supabase Storage
    final response = await _client.storage
        .from(documentsBucket)
        .uploadBinary(
          filePath,
          fileBytes,
          fileOptions: FileOptions(
            contentType: _getMimeType(fileName),
            upsert: false, // Never overwrite (immutable)
          ),
        );

    // Get public URL
    final publicUrl = _client.storage
        .from(documentsBucket)
        .getPublicUrl(filePath);

    return StorageUploadResult(
      path: filePath,
      url: publicUrl,
      hash: fileHash,
      size: fileBytes.length,
    );
  }

  /// Upload SCORM package (zip) and extract
  Future<StorageUploadResult> uploadScormPackage({
    required String organizationId,
    required String courseId,
    required Uint8List packageBytes,
    required String fileName,
  }) async {
    final fileHash = sha256.convert(packageBytes).toString();
    final filePath = '$organizationId/$courseId/$fileName';

    await _client.storage
        .from(scormBucket)
        .uploadBinary(
          filePath,
          packageBytes,
          fileOptions: FileOptions(
            contentType: 'application/zip',
            upsert: true,
          ),
        );

    // TODO: Trigger Edge Function to extract SCORM package
    // For now, return the zip path
    final publicUrl = _client.storage
        .from(scormBucket)
        .getPublicUrl(filePath);

    return StorageUploadResult(
      path: filePath,
      url: publicUrl,
      hash: fileHash,
      size: packageBytes.length,
    );
  }

  /// Generate signed URL for private files
  Future<String> getSignedUrl(String bucket, String path, {int expiresIn = 3600}) async {
    final response = await _client.storage
        .from(bucket)
        .createSignedUrl(path, expiresIn);
    return response;
  }

  /// Download file
  Future<Uint8List> downloadFile(String bucket, String path) async {
    return await _client.storage
        .from(bucket)
        .download(path);
  }

  /// Delete file (only for drafts, not effective documents)
  Future<void> deleteFile(String bucket, String path) async {
    await _client.storage
        .from(bucket)
        .remove([path]);
  }

  String _getMimeType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.mp4':
        return 'video/mp4';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}

class StorageUploadResult {
  final String path;
  final String url;
  final String hash;
  final int size;

  StorageUploadResult({
    required this.path,
    required this.url,
    required this.hash,
    required this.size,
  });
}
```

---

## 11. Background Jobs

### pg_cron + pg_net for Scheduled Tasks

```sql
-- Enable extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Schedule: Daily compliance check at 2 AM
SELECT cron.schedule(
  'daily-compliance-check',
  '0 2 * * *',
  $$
  SELECT net.http_post(
    url := 'http://dart-backend:8080/api/v1/jobs/compliance-check',
    headers := '{"Authorization": "Bearer ${SERVICE_ROLE_KEY}"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);

-- Schedule: Certificate expiry reminders at 8 AM
SELECT cron.schedule(
  'certificate-expiry-reminders',
  '0 8 * * *',
  $$
  INSERT INTO notification_queue (
    recipient_id,
    template_id,
    channel,
    data,
    organization_id
  )
  SELECT 
    c.employee_id,
    'cert_expiry_reminder',
    'email',
    jsonb_build_object(
      'certificate_name', c.certificate_name,
      'expiry_date', c.valid_until,
      'days_remaining', c.valid_until - CURRENT_DATE
    ),
    c.organization_id
  FROM certificates c
  WHERE c.valid_until BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
    AND c.status = 'active'
    AND NOT EXISTS (
      SELECT 1 FROM notification_queue nq
      WHERE nq.data->>'certificate_id' = c.id::text
      AND nq.created_at > CURRENT_DATE - INTERVAL '7 days'
    );
  $$
);

-- Schedule: Training due date reminders at 9 AM
SELECT cron.schedule(
  'training-due-reminders',
  '0 9 * * *',
  $$
  INSERT INTO notification_queue (
    recipient_id,
    template_id,
    channel,
    data,
    organization_id
  )
  SELECT 
    ta.employee_id,
    'training_due_reminder',
    'email',
    jsonb_build_object(
      'course_name', c.course_name,
      'due_date', ta.due_date,
      'days_remaining', ta.due_date - CURRENT_DATE
    ),
    ta.organization_id
  FROM training_assignments ta
  JOIN courses c ON c.id = ta.course_id
  WHERE ta.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
    AND ta.status IN ('assigned', 'in_progress');
  $$
);

-- Schedule: Analytics materialized view refresh every 15 min
SELECT cron.schedule(
  'mv-refresh-training-status',
  '*/15 * * * *',
  $$
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_employee_training_status;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_compliance_summary;
  $$
);

-- Schedule: Audit trail archival (weekly, Sunday 3 AM)
SELECT cron.schedule(
  'audit-archive',
  '0 3 * * 0',
  $$
  WITH archived AS (
    INSERT INTO audit_trails_archive
    SELECT * FROM audit_trails
    WHERE created_at < CURRENT_DATE - INTERVAL '90 days'
    RETURNING id
  )
  DELETE FROM audit_trails WHERE id IN (SELECT id FROM archived);
  $$
);

-- Schedule: Session cleanup (every 30 min)
SELECT cron.schedule(
  'session-cleanup',
  '*/30 * * * *',
  $$
  UPDATE session_chains
  SET logout_timestamp = NOW(),
      logout_reason = 'session_timeout'
  WHERE logout_timestamp IS NULL
    AND login_timestamp < NOW() - INTERVAL '8 hours';
  $$
);
```

### Dart Frog Background Worker

```dart
// routes/api/v1/jobs/compliance_check.dart

import 'package:dart_frog/dart_frog.dart';
import 'package:supabase/supabase.dart';

Future<Response> onRequest(RequestContext context) async {
  // Verify service role
  final authHeader = context.request.headers['authorization'];
  if (authHeader != context.read<String>(#serviceRoleKey)) {
    return Response(statusCode: 401);
  }

  final supabase = context.read<SupabaseClient>();
  
  // Run compliance calculations
  final results = await _runComplianceCheck(supabase);

  return Response.json(body: {
    'status': 'completed',
    'processed': results.length,
    'gaps_found': results.where((r) => r['has_gap'] == true).length,
  });
}

Future<List<Map<String, dynamic>>> _runComplianceCheck(SupabaseClient supabase) async {
  // Get all active employees with their required training
  final employees = await supabase
      .from('employees')
      .select('''
        id,
        organization_id,
        job_role:job_roles(
          id,
          required_courses:job_role_courses(
            course_id,
            is_mandatory,
            retraining_frequency_days
          )
        )
      ''')
      .eq('is_active', true);

  final results = <Map<String, dynamic>>[];

  for (final emp in employees) {
    final empId = emp['id'];
    final requiredCourses = emp['job_role']?['required_courses'] as List? ?? [];

    for (final req in requiredCourses) {
      final courseId = req['course_id'];
      final retrainDays = req['retraining_frequency_days'];

      // Check if employee has valid completion
      final completion = await supabase
          .from('training_assignments')
          .select()
          .eq('employee_id', empId)
          .eq('course_id', courseId)
          .eq('status', 'completed')
          .order('completed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      bool hasGap = false;
      String? gapReason;

      if (completion == null) {
        hasGap = true;
        gapReason = 'Never completed';
      } else if (retrainDays != null) {
        final completedAt = DateTime.parse(completion['completed_at']);
        final expiresAt = completedAt.add(Duration(days: retrainDays));
        if (expiresAt.isBefore(DateTime.now())) {
          hasGap = true;
          gapReason = 'Retraining overdue';
        }
      }

      if (hasGap) {
        // Create or update compliance gap
        await supabase.from('compliance_gaps').upsert({
          'employee_id': empId,
          'course_id': courseId,
          'gap_reason': gapReason,
          'detected_at': DateTime.now().toIso8601String(),
          'organization_id': emp['organization_id'],
        }, onConflict: 'employee_id,course_id');
      } else {
        // Remove gap if exists
        await supabase
            .from('compliance_gaps')
            .delete()
            .eq('employee_id', empId)
            .eq('course_id', courseId);
      }

      results.add({
        'employee_id': empId,
        'course_id': courseId,
        'has_gap': hasGap,
      });
    }
  }

  return results;
}
```

---

## 12. Observability & Monitoring

### Simple Monitoring Stack (On-Premise)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY STACK (SIMPLIFIED)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  METRICS (Prometheus + Grafana)                                     │   │
│  │                                                                     │   │
│  │  • PostgreSQL metrics (pg_stat_statements, connections, cache)     │   │
│  │  • Redis metrics (memory, hits/misses, connections)                │   │
│  │  • Application metrics (request count, latency, errors)            │   │
│  │  • Business metrics (active users, training completions)           │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LOGS (Loki or PostgreSQL)                                          │   │
│  │                                                                     │   │
│  │  • Structured JSON logs to application_logs table                  │   │
│  │  • API request/response logging                                    │   │
│  │  • Error stack traces                                              │   │
│  │  • Audit trail (already in audit_trails table)                     │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ALERTS (Grafana Alerting)                                          │   │
│  │                                                                     │   │
│  │  • Database connection pool exhaustion                             │   │
│  │  • High error rate (>1%)                                           │   │
│  │  • Disk space low (<20%)                                           │   │
│  │  • Backup failure                                                  │   │
│  │  • Certificate expiry (SSL)                                        │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Application Logging Table

```sql
-- Simple application log storage in PostgreSQL

CREATE TABLE application_logs (
    id              BIGSERIAL PRIMARY KEY,
    timestamp       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    level           TEXT NOT NULL CHECK (level IN ('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')),
    logger          TEXT NOT NULL,
    message         TEXT NOT NULL,
    context         JSONB,
    error_stack     TEXT,
    request_id      TEXT,
    user_id         UUID,
    organization_id UUID,
    
    -- Indexing for queries
    created_at      DATE GENERATED ALWAYS AS (DATE(timestamp)) STORED
);

-- Partition by date for easy archival
CREATE INDEX idx_logs_timestamp ON application_logs (timestamp DESC);
CREATE INDEX idx_logs_level ON application_logs (level) WHERE level IN ('ERROR', 'FATAL');
CREATE INDEX idx_logs_org ON application_logs (organization_id, timestamp DESC);

-- Auto-cleanup logs older than 30 days
SELECT cron.schedule(
  'cleanup-app-logs',
  '0 4 * * *',
  $$DELETE FROM application_logs WHERE timestamp < NOW() - INTERVAL '30 days';$$
);
```

### Flutter Logging Service

```dart
// lib/core/services/logging_service.dart

import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoggingService {
  final SupabaseClient _client;
  final Logger _logger;
  String? _currentRequestId;

  LoggingService(this._client)
      : _logger = Logger(
          printer: PrettyPrinter(
            methodCount: 2,
            errorMethodCount: 8,
            lineLength: 120,
            colors: true,
            printEmojis: true,
            printTime: true,
          ),
        );

  void setRequestId(String requestId) {
    _currentRequestId = requestId;
  }

  Future<void> debug(String message, {Map<String, dynamic>? context}) async {
    _logger.d(message);
    await _persistLog('DEBUG', 'app', message, context: context);
  }

  Future<void> info(String message, {Map<String, dynamic>? context}) async {
    _logger.i(message);
    await _persistLog('INFO', 'app', message, context: context);
  }

  Future<void> warn(String message, {Map<String, dynamic>? context}) async {
    _logger.w(message);
    await _persistLog('WARN', 'app', message, context: context);
  }

  Future<void> error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    _logger.e(message, error: error, stackTrace: stackTrace);
    await _persistLog(
      'ERROR',
      'app',
      message,
      context: context,
      errorStack: stackTrace?.toString(),
    );
  }

  Future<void> _persistLog(
    String level,
    String logger,
    String message, {
    Map<String, dynamic>? context,
    String? errorStack,
  }) async {
    try {
      final user = _client.auth.currentUser;
      final appMetadata = user?.appMetadata;

      await _client.from('application_logs').insert({
        'level': level,
        'logger': logger,
        'message': message,
        'context': context,
        'error_stack': errorStack,
        'request_id': _currentRequestId,
        'user_id': user?.id,
        'organization_id': appMetadata?['organization_id'],
      });
    } catch (e) {
      // Don't fail the app if logging fails
      _logger.e('Failed to persist log', error: e);
    }
  }
}
```

---

## 13. Compliance Architecture

### 21 CFR Part 11 Compliance Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    21 CFR PART 11 COMPLIANCE IMPLEMENTATION                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  §11.10 Controls for Closed Systems                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ (a) System Validation         │ IQ/OQ/PQ documentation required    │   │
│  │ (b) Legible Record Copies     │ PDF export with signatures         │   │
│  │ (c) Record Protection         │ RLS + backup + encryption          │   │
│  │ (d) Limited Access            │ RBAC via roles/permissions         │   │
│  │ (e) Audit Trail               │ audit_trails table, hash-chained   │   │
│  │ (f) Operational Checks        │ Workflow state validation          │   │
│  │ (g) Authority Checks          │ Permission checks before action    │   │
│  │ (h) Device Checks             │ N/A (web-based)                    │   │
│  │ (i) Training                  │ System trains users on itself      │   │
│  │ (j) Controls Documentation    │ This architecture document         │   │
│  │ (k) Revision Controls         │ document_versions, change_reasons  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  §11.50 Signature Manifestations                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Printed name                │ employee_name in signature        │   │
│  │ • Date/time of signing        │ created_at timestamp (UTC)        │   │
│  │ • Meaning of signature        │ meaning + meaning_display fields  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  §11.70 Signature/Record Linking                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • integrity_hash links signature to exact record state            │   │
│  │ • data_snapshot stores record at time of signing                  │   │
│  │ • Cannot modify record without invalidating hash                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  §11.100 General E-Signature Requirements                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Each signature unique to one individual                         │   │
│  │ • Identity verified before signature use                          │   │
│  │ • Certification of signature authenticity                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  §11.200 E-Signature Components                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Minimum 2 components: password + biometric (optional)           │   │
│  │ • password_reauth_verified flag                                   │   │
│  │ • biometric_verified flag                                         │   │
│  │ • Session must be re-authenticated                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Audit Trail Integrity Verification

```dart
// lib/features/access/domain/usecases/verify_audit_chain.dart

import 'package:crypto/crypto.dart';
import 'dart:convert';

class VerifyAuditChainUseCase {
  final SupabaseClient _client;

  VerifyAuditChainUseCase(this._client);

  /// Verify the integrity of the audit trail hash chain
  Future<AuditVerificationResult> execute({
    required String organizationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _client
        .from('audit_trails')
        .select()
        .eq('organization_id', organizationId)
        .order('created_at', ascending: true);

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    final records = await query;

    int totalRecords = 0;
    int validRecords = 0;
    int invalidRecords = 0;
    final invalidDetails = <Map<String, dynamic>>[];

    String? previousHash;

    for (final record in records) {
      totalRecords++;

      final expectedPrevHash = record['prev_hash'];
      final storedHash = record['integrity_hash'];

      // Verify previous hash matches
      if (expectedPrevHash != previousHash && previousHash != null) {
        invalidRecords++;
        invalidDetails.add({
          'id': record['id'],
          'reason': 'Previous hash mismatch',
          'expected': previousHash,
          'actual': expectedPrevHash,
        });
        continue;
      }

      // Recalculate hash
      final hashInput = '${expectedPrevHash ?? "GENESIS"}|'
          '${record['table_name']}|'
          '${record['record_id']}|'
          '${record['action']}|'
          '${record['actor_id'] ?? "SYSTEM"}|'
          '${jsonEncode(record['new_values'] ?? {})}|'
          '${record['created_at']}';

      final calculatedHash = sha256.convert(utf8.encode(hashInput)).toString();

      if (calculatedHash != storedHash) {
        invalidRecords++;
        invalidDetails.add({
          'id': record['id'],
          'reason': 'Hash mismatch - record may have been tampered',
          'expected': calculatedHash,
          'actual': storedHash,
        });
      } else {
        validRecords++;
      }

      previousHash = storedHash;
    }

    return AuditVerificationResult(
      totalRecords: totalRecords,
      validRecords: validRecords,
      invalidRecords: invalidRecords,
      isChainIntact: invalidRecords == 0,
      invalidDetails: invalidDetails,
      verifiedAt: DateTime.now(),
    );
  }
}

class AuditVerificationResult {
  final int totalRecords;
  final int validRecords;
  final int invalidRecords;
  final bool isChainIntact;
  final List<Map<String, dynamic>> invalidDetails;
  final DateTime verifiedAt;

  AuditVerificationResult({
    required this.totalRecords,
    required this.validRecords,
    required this.invalidRecords,
    required this.isChainIntact,
    required this.invalidDetails,
    required this.verifiedAt,
  });

  Map<String, dynamic> toJson() => {
        'total_records': totalRecords,
        'valid_records': validRecords,
        'invalid_records': invalidRecords,
        'is_chain_intact': isChainIntact,
        'invalid_details': invalidDetails,
        'verified_at': verifiedAt.toIso8601String(),
      };
}
```

---

## 14. Infrastructure Requirements

### Hardware Specifications

| Environment | Servers | CPU | RAM | Storage | Network |
|-------------|---------|-----|-----|---------|---------|
| **Minimal** | 2 | 4 cores each | 16GB each | 500GB SSD | 1 Gbps |
| **Standard** | 4 | 8 cores each | 32GB each | 1TB NVMe | 10 Gbps |
| **HA** | 6+ | 8 cores each | 64GB each | 2TB NVMe | 10 Gbps |

### Server Allocation (Standard)

| Server | Role | Specs | Services |
|--------|------|-------|----------|
| **Server 1** | Reverse Proxy / LB | 4 CPU, 8GB RAM | Nginx, Let's Encrypt |
| **Server 2** | Application | 8 CPU, 32GB RAM | Supabase Stack (Docker) |
| **Server 3** | Database Primary | 8 CPU, 64GB RAM | PostgreSQL Primary |
| **Server 4** | Database Replica / Cache | 4 CPU, 16GB RAM | PostgreSQL Replica, Redis |

### Cost Estimate (Monthly)

| Component | Minimal | Standard | HA |
|-----------|---------|----------|-----|
| Servers (leased/cloud) | $400 | $1,200 | $2,500 |
| Storage (NAS/SAN) | $100 | $300 | $600 |
| Backup storage | $50 | $150 | $300 |
| Network/Bandwidth | $50 | $100 | $200 |
| SSL Certificates | $0 (Let's Encrypt) | $0 | $50 |
| Monitoring (Grafana Cloud free tier) | $0 | $0 | $100 |
| **Total** | **~$600/month** | **~$1,750/month** | **~$3,750/month** |

---

## 15. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)

```
Week 1-2: Infrastructure Setup
├── Server provisioning
├── Docker installation
├── Supabase self-hosted deployment
├── SSL certificate configuration
└── Basic networking and firewall

Week 3-4: Core Schema & Auth
├── Database schema migration
├── RLS policies implementation
├── GoTrue configuration
├── MFA setup
└── Flutter project scaffolding
```

### Phase 2: CREATE & ACCESS Modules (Weeks 5-8)

```
Week 5-6: ACCESS Module
├── User authentication flows
├── Role management UI
├── Session management
├── E-signature implementation
└── Audit trail integration

Week 7-8: CREATE Module
├── Document management CRUD
├── Version control
├── Course authoring
├── Assessment builder
└── File upload/storage
```

### Phase 3: TRAIN Module (Weeks 9-12)

```
Week 9-10: Training Core
├── Training assignment engine
├── Learning path management
├── Real-time progress tracking
├── Classroom session booking
└── Attendance tracking

Week 11-12: Training Advanced
├── OJT workflows
├── Induction programs
├── SCORM player integration
├── Video streaming
└── Notifications
```

### Phase 4: CERTIFY Module (Weeks 13-16)

```
Week 13-14: Assessment & Certification
├── Assessment engine
├── Auto-grading
├── Certificate generation
├── Competency matrix
└── Validity tracking

Week 15-16: Compliance & Reports
├── Compliance dashboard
├── Gap analysis
├── Training matrix reports
├── Audit reports
└── Analytics views
```

### Phase 5: Validation & Go-Live (Weeks 17-20)

```
Week 17-18: Testing & Validation
├── Unit testing
├── Integration testing
├── UAT with users
├── Performance testing
└── Security audit

Week 19-20: Documentation & Go-Live
├── IQ/OQ/PQ documentation
├── User training
├── Data migration
├── Go-live support
└── Handover
```

---

## Appendix A: Docker Compose Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/yourcompany/pharmalearn-lms.git
cd pharmalearn-lms

# 2. Copy environment template
cp .env.example .env

# 3. Generate secrets
echo "JWT_SECRET=$(openssl rand -base64 32)" >> .env
echo "POSTGRES_PASSWORD=$(openssl rand -base64 24)" >> .env

# 4. Start Supabase stack
docker-compose up -d

# 5. Run database migrations
docker-compose exec db psql -U postgres -f /migrations/001_foundation.sql
docker-compose exec db psql -U postgres -f /migrations/002_employees.sql
# ... continue with all migration files

# 6. Verify services
curl http://localhost:8000/rest/v1/  # PostgREST
curl http://localhost:8000/auth/v1/health  # GoTrue

# 7. Access Supabase Studio
open http://localhost:3001
```

---

## Appendix B: Flutter Build Commands

```bash
# Development
flutter run -d chrome --dart-define=SUPABASE_URL=http://localhost:8000 \
                      --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Build for Web (production)
flutter build web --release \
  --dart-define=SUPABASE_URL=https://api.pharmalearn.yourcompany.com \
  --dart-define=SUPABASE_ANON_KEY=your-production-anon-key

# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release

# Build for Windows Desktop
flutter build windows --release

# Build for macOS Desktop
flutter build macos --release
```

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-23 | Architecture Team | Initial on-premise architecture with Dart/Flutter/Supabase stack |

---

*This architecture document is confidential and intended for PharmaLearn development team use only.*
