# ACCESS Module — Identity, Authentication & Authorization
**PharmaLearn LMS — Detailed Implementation Guide**

> **Version:** 1.0  
> **Date:** 2026-04-23  
> **Module Owner:** Identity & Security Team  
> **Status:** Production Planning  
> **Compliance:** 21 CFR Part 11, EU GDPR, WHO GMP  
> **Dependencies:** CREATE module (document access), TRAIN module (enrollment), CERTIFY module (assessment access)

---

## Table of Contents

1. [Module Overview](#module-overview)
2. [Core Concepts](#core-concepts)
3. [Data Model & Supabase Schema](#data-model--supabase-schema)
4. [Authentication Architecture](#authentication-architecture)
5. [API Architecture](#api-architecture)
6. [Authorization & RBAC](#authorization--rbac)
7. [Real-World Reference: Enterprise SSO](#real-world-reference-enterprise-sso)
8. [Vyuh Framework Integration](#vyuh-framework-integration)
9. [Security & Compliance](#security--compliance)
10. [Implementation Checklist](#implementation-checklist)

---

## Module Overview

### Purpose

The **ACCESS** module provides comprehensive identity and access management for the PharmaLearn LMS. It handles:
- User registration, authentication, and session management
- Multi-factor authentication (MFA)
- Role-based access control (RBAC) with hierarchical roles
- Permissions system for fine-grained access
- E-signature management for 21 CFR Part 11 compliance
- Single Sign-On (SSO) integration with enterprise identity providers
- Biometric authentication support (iOS/Android)

### Key Features

- **Authentication Methods**: Username/password, OAuth2 (SAML/OpenID Connect), biometric, TOTP
- **Session Management**: JWT-based sessions with refresh tokens
- **Multi-Role Support**: Employees can have multiple roles across plants/departments
- **Hierarchical Permissions**: Granular permission system with role inheritance
- **E-Signature Certificates**: PKI certificate management for 21 CFR Part 11
- **Audit Logging**: All login/permission changes logged immutably
- **API Key Management**: For service-to-service communication
- **Delegation**: Temporary authority transfer (manager can delegate during leave)

### Success Metrics

| Metric | Target | Rationale |
|--------|--------|-----------|
| Login time | < 1 second | Fast user experience |
| MFA prompt-to-auth | < 30 seconds | User convenience |
| Permission lookup | < 50ms | Real-time access decisions |
| SSO integration | < 2 weeks | Pre-built integrations |
| Password reset | < 5 minutes | Self-service, no IT involvement |

---

## Core Concepts

### 1. Authentication Flows

```
┌──────────────────────────────────────────────────────────────────┐
│                    AUTHENTICATION FLOWS                           │
└──────────────────────────────────────────────────────────────────┘

Flow 1: Username/Password + MFA
┌─────────────┐
│ App         │
└─────┬───────┘
      │ POST /v1/auth/login
      ├─ username + password
      ├─ platform (web/mobile)
      ▼
┌─────────────────────┐
│ GoTrue (Supabase)   │
├─────────────────────┤
│ 1. Hash password    │
│ 2. Verify hash      │
│ 3. MFA required?    │
│    - YES: Return    │
│      session_id,    │
│      mfa_required   │
│    - NO: Return JWT │
└─────┬───────────────┘
      │ User receives MFA code
      │ POST /v1/auth/verify-mfa
      ├─ session_id
      ├─ mfa_code (6-digit)
      │ or biometric_data
      ▼
┌─────────────────────┐
│ GoTrue validates    │
│ Returns JWT + RTK   │
└─────┬───────────────┘
      │
      ▼
┌─────────────────────┐
│ App (Authenticated) │
│ JWT in header       │
└─────────────────────┘

Flow 2: OAuth2/SAML (SSO)
┌─────────────┐
│ App         │
│ [Login with │
│  Company    │
│  AD/LDAP]   │
└─────┬───────┘
      │ POST /v1/auth/sso-providers
      ▼
┌────────────────────────┐
│ Gets list of SSO       │
│ providers              │
│ - Azure AD             │
│ - Google Workspace     │
│ - Okta                 │
│ - Custom SAML          │
└─────┬──────────────────┘
      │ Redirect to provider
      │ https://provider.com/oauth/authorize?...
      ▼
┌────────────────────┐
│ User authenticates │
│ to provider        │
└─────┬──────────────┘
      │ Provider redirects
      │ /v1/auth/callback?code=...
      ▼
┌────────────────────────┐
│ Supabase GoTrue        │
│ 1. Exchange code       │
│ 2. Get user profile    │
│ 3. Create/link account │
│ 4. Return JWT          │
└─────┬──────────────────┘
      │
      ▼
┌────────────────────┐
│ App Authenticated  │
└────────────────────┘

Flow 3: Biometric (iOS/Android)
┌─────────────┐
│ App         │
│ [Tap        │
│  Biometric] │
└─────┬───────┘
      │ local_auth plugin
      │ (native iOS/Android)
      ▼
┌──────────────────┐
│ Biometric prompt │
│ (FaceID/TouchID) │
└─────┬────────────┘
      │ If auth success
      ▼
┌──────────────────────────┐
│ App retrieves stored JWT │
│ (from secure storage)    │
│ If expired, use RTK to   │
│ refresh                  │
└─────┬───────────────────┘
      │
      ▼
┌────────────────┐
│ App Ready to   │
│ Use API        │
└────────────────┘
```

### 2. RBAC Hierarchy

```
Organization Level
├── Role Category 1: Manufacturing
│   ├── Role: Manufacturing Manager
│   │   ├── Permissions: [create_document, approve_sop, view_all_docs]
│   │   └── Inherits from: Base Manufacturing Role
│   ├── Role: Technician
│   │   ├── Permissions: [view_assigned_docs, complete_training]
│   │   └── Inherits from: Base Employee Role
│   └── Role: QA Officer
│       └── Permissions: [approve_document, audit_trail_view]
│
├── Role Category 2: Training
│   ├── Role: Training Coordinator
│   │   └── Permissions: [create_course, schedule_training, track_attendance]
│   └── Role: Trainer
│       └── Permissions: [deliver_training, assess_employees]
│
└── Role Category 3: Compliance
    ├── Role: Compliance Officer
    │   └── Permissions: [view_all_training, export_reports]
    └── Role: Auditor
        └── Permissions: [view_audit_trail, read_only_all_records]

Scope: Department + Plant
├── Manufacturing @ Plant A
├── Quality @ Plant B
└── Training @ All Plants
```

### 3. Permission Model

```json
{
  "permission": {
    "id": "perm_create_document",
    "name": "Create Document",
    "category": "document_management",
    "resource": "documents",
    "action": "create",
    "scopes": ["organization", "plant", "department"],
    "description": "Allow creation of new SOPs and work instructions"
  },
  
  "role": {
    "id": "role_manufacturing_manager",
    "name": "Manufacturing Manager",
    "organization_id": "org-uuid",
    "permissions": [
      "perm_create_document",
      "perm_approve_document",
      "perm_view_all_documents_dept"
    ],
    "inherits_from": "role_base_manager"
  },
  
  "employee_role": {
    "id": "emp_role_uuid",
    "employee_id": "emp-uuid",
    "role_id": "role_manufacturing_manager",
    "valid_from": "2026-01-01",
    "valid_until": "2027-12-31",
    "assigned_scopes": {
      "plant_id": "plant-a-uuid",
      "department_id": "dept-manu-uuid"
    }
  }
}
```

### 4. Session & Token Management

```
JWT Token Structure:
┌──────────────────────────────────────┐
│ Header                               │
├──────────────────────────────────────┤
│ {                                    │
│   "alg": "RS256",                    │
│   "typ": "JWT",                      │
│   "kid": "key_id_123"                │
│ }                                    │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ Payload                              │
├──────────────────────────────────────┤
│ {                                    │
│   "sub": "employee-uuid",            │
│   "org_id": "org-uuid",              │
│   "roles": [                         │
│     {                                │
│       "role_id": "role-manu-mgr",    │
│       "scopes": {                    │
│         "plant_id": "plant-a",       │
│         "dept_id": "dept-manu"       │
│       }                              │
│     }                                │
│   ],                                 │
│   "permissions": [                   │
│     "doc:create",                    │
│     "doc:approve",                   │
│     "training:schedule"              │
│   ],                                 │
│   "iat": 1713883200,                 │
│   "exp": 1713969600,  (8 hours)      │
│   "aud": "pharmalearn-app"           │
│ }                                    │
└──────────────────────────────────────┘

Refresh Token Flow:
┌────────────────────────────────────┐
│ Access Token expires (8h)          │
├────────────────────────────────────┤
│ App sends Refresh Token            │
│ POST /v1/auth/refresh              │
│ + old JWT                          │
│ + refresh_token                    │
│ + device_fingerprint               │
├────────────────────────────────────┤
│ GoTrue validates RTK               │
│ (not expired, not revoked)         │
│ Returns new JWT                    │
│ (old refresh_token still valid)    │
└────────────────────────────────────┘

Refresh Token Rotation (Security):
After 7 days or after 30 uses:
  → Old RTK revoked
  → New RTK issued
  → Device registration updated
  → Old sessions cleared
```

---

## Data Model & Supabase Schema

### Core Tables

#### 1. **employees** — User accounts

```sql
CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    -- Basic info
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone_number TEXT,
    employee_code TEXT UNIQUE,  -- E.g., "EMP001", used in exports
    
    -- Employment
    department_id UUID REFERENCES departments(id),
    plant_id UUID REFERENCES plants(id),
    job_title TEXT,
    employment_type employment_type,  -- PERMANENT, CONTRACT, TEMPORARY
    employment_status employment_status,  -- ACTIVE, ON_LEAVE, TERMINATED, SUSPENDED
    
    -- Contact
    physical_address TEXT,
    city TEXT,
    country TEXT,
    
    -- Compliance
    induction_completed BOOLEAN DEFAULT FALSE,
    induction_completed_at TIMESTAMPTZ,
    training_due_on_date DATE,
    
    -- System
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    
    UNIQUE(organization_id, employee_code)
);

CREATE INDEX idx_employees_org ON employees(organization_id);
CREATE INDEX idx_employees_dept ON employees(department_id);
CREATE INDEX idx_employees_email ON employees(email);
CREATE INDEX idx_employees_status ON employees(employment_status);
```

#### 2. **user_credentials** — Authentication data (GoTrue integration)

```sql
CREATE TABLE IF NOT EXISTS user_credentials (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    employee_id UUID NOT NULL UNIQUE REFERENCES employees(id),
    
    -- Password (managed by GoTrue, not stored here)
    -- GoTrue stores: hashed_password, password_updated_at
    
    -- MFA
    mfa_enabled BOOLEAN DEFAULT FALSE,
    mfa_type mfa_type,  -- 'totp', 'sms'
    totp_secret_encrypted TEXT,  -- Encrypted TOTP seed
    phone_for_mfa TEXT,  -- Backup phone for SMS
    mfa_verified_at TIMESTAMPTZ,
    
    -- Status
    account_status account_status,  -- ACTIVE, LOCKED, DISABLED
    failed_login_attempts INTEGER DEFAULT 0,
    last_failed_login TIMESTAMPTZ,
    locked_until TIMESTAMPTZ,
    
    -- Audit
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    last_login_device TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Secure MFA secret encryption
ALTER TABLE user_credentials ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_credentials_own_access ON user_credentials
    FOR SELECT USING (auth.uid() = id);
```

#### 3. **roles** — Role definitions

```sql
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    -- Role info
    name TEXT NOT NULL,
    description TEXT,
    level INTEGER,  -- Hierarchy level for inheritance
    
    -- Inheritance
    inherits_from_role_id UUID REFERENCES roles(id),
    
    -- Scope
    applicable_at scope_type,  -- 'organization', 'plant', 'department'
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(organization_id, name),
    CONSTRAINT chk_role_level CHECK (level >= 0)
);

CREATE INDEX idx_roles_org ON roles(organization_id);
```

#### 4. **role_categories** — Categorize roles for UI

```sql
CREATE TABLE IF NOT EXISTS role_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    name TEXT NOT NULL,
    description TEXT,
    icon_name TEXT,
    
    UNIQUE(organization_id, name)
);
```

#### 5. **permissions** — Permission definitions

```sql
CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID,  -- NULL = system-wide permission
    
    -- Permission name
    name TEXT NOT NULL,
    description TEXT,
    resource TEXT NOT NULL,  -- 'documents', 'courses', 'training', 'assessment'
    action TEXT NOT NULL,    -- 'create', 'read', 'update', 'delete', 'approve'
    
    -- Hierarchical
    category permission_category,  -- DOCUMENT_MGMT, TRAINING, ASSESSMENT, COMPLIANCE
    
    -- Scope
    scope_level scope_type,  -- 'organization', 'plant', 'department', 'resource'
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(organization_id, resource, action)
);

-- Example permissions
INSERT INTO permissions VALUES (
    'perm_doc_create', null, 'Create Document', 'Allows creation of new documents',
    'documents', 'create', 'DOCUMENT_MGMT', 'organization'
);

INSERT INTO permissions VALUES (
    'perm_doc_approve', null, 'Approve Document', 'Allows approval of documents for publication',
    'documents', 'approve', 'DOCUMENT_MGMT', 'department'
);
```

#### 6. **role_permissions** — Join table

```sql
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (role_id, permission_id)
);

CREATE INDEX idx_role_permissions_role ON role_permissions(role_id);
```

#### 7. **employee_roles** — Assign roles to employees

```sql
CREATE TABLE IF NOT EXISTS employee_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    role_id UUID NOT NULL REFERENCES roles(id),
    
    -- Scope assignment (where does this role apply?)
    plant_id UUID REFERENCES plants(id),
    department_id UUID REFERENCES departments(id),
    
    -- Validity
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until DATE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    assigned_by UUID REFERENCES employees(id),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(employee_id, role_id, plant_id, department_id),
    CONSTRAINT chk_dates CHECK (valid_until >= valid_from OR valid_until IS NULL)
);

CREATE INDEX idx_emp_roles_emp ON employee_roles(employee_id);
CREATE INDEX idx_emp_roles_role ON employee_roles(role_id);
```

#### 8. **operational_delegations** — Temporary authority transfer

```sql
CREATE TABLE IF NOT EXISTS operational_delegations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    delegator_id UUID NOT NULL REFERENCES employees(id),
    delegatee_id UUID NOT NULL REFERENCES employees(id),
    
    -- What is delegated?
    role_id UUID NOT NULL REFERENCES roles(id),
    
    -- When?
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    
    -- Reason
    reason TEXT,  -- 'annual_leave', 'sabbatical', 'sick_leave'
    
    -- Tracking
    created_at TIMESTAMPTZ DEFAULT NOW(),
    approved_by UUID REFERENCES employees(id),
    approved_at TIMESTAMPTZ,
    
    CONSTRAINT chk_delegation_dates CHECK (valid_until > valid_from)
);
```

#### 9. **biometric_registrations** — Fingerprint/Face for MFA

```sql
CREATE TABLE IF NOT EXISTS biometric_registrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    
    -- Device info
    device_id TEXT NOT NULL,
    device_model TEXT,
    platform ios_android,
    
    -- Biometric data
    biometric_type biometric_type,  -- 'face_id', 'touch_id', 'fingerprint'
    biometric_template BYTEA NOT NULL,  -- Encrypted biometric template
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    registered_at TIMESTAMPTZ DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    
    UNIQUE(employee_id, device_id, biometric_type)
);

-- Encrypt biometric data at rest
ALTER TABLE biometric_registrations ENABLE ROW LEVEL SECURITY;
```

#### 10. **user_sessions** — Track active sessions (audit)

```sql
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    
    -- Session info
    jwt_token_id TEXT,
    session_type session_type,  -- 'web', 'mobile_ios', 'mobile_android', 'desktop'
    
    -- Device tracking
    device_fingerprint TEXT,
    device_name TEXT,
    ip_address INET,
    user_agent TEXT,
    
    -- Timing
    started_at TIMESTAMPTZ DEFAULT NOW(),
    last_activity_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    
    -- Auth method
    auth_method auth_method,  -- 'password', 'biometric', 'sso', 'api_key'
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    terminated_at TIMESTAMPTZ,
    termination_reason TEXT,
    
    CONSTRAINT chk_session_dates CHECK (expires_at > started_at)
);

CREATE INDEX idx_sessions_emp ON user_sessions(employee_id);
CREATE INDEX idx_sessions_active ON user_sessions(is_active, expires_at);
```

#### 11. **sso_configurations** — SAML/OAuth2 providers

```sql
CREATE TABLE IF NOT EXISTS sso_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    -- Provider type
    provider_type sso_provider_type,  -- 'azure_ad', 'google', 'okta', 'saml'
    
    -- Configuration
    provider_name TEXT NOT NULL,
    client_id TEXT NOT NULL,
    client_secret_encrypted TEXT NOT NULL,
    tenant_id TEXT,  -- Azure-specific
    
    -- SAML-specific
    idp_entity_id TEXT,
    idp_sso_url TEXT,
    idp_certificate_public_key TEXT,
    
    -- OAuth2-specific
    authorization_endpoint TEXT,
    token_endpoint TEXT,
    userinfo_endpoint TEXT,
    
    -- Mapping
    email_claim_name TEXT DEFAULT 'email',
    name_claim_name TEXT DEFAULT 'name',
    department_claim_name TEXT DEFAULT 'department',
    
    -- Status
    is_enabled BOOLEAN DEFAULT FALSE,
    is_default BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(organization_id, provider_type)
);

-- Encrypt secrets
ALTER TABLE sso_configurations ENABLE ROW LEVEL SECURITY;
```

#### 12. **e_signature_certificates** — PKI management for 21 CFR Part 11

```sql
CREATE TABLE IF NOT EXISTS e_signature_certificates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    -- Certificate
    certificate_thumbprint TEXT UNIQUE NOT NULL,  -- SHA-256 of cert
    certificate_pem TEXT NOT NULL,  -- Full certificate
    certificate_issuer TEXT,
    subject_name TEXT,
    
    -- Validity
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    
    -- Private key (encrypted, stored securely)
    private_key_encrypted BYTEA,
    key_encryption_method TEXT,  -- 'AES256-GCM'
    
    -- Usage
    sign_count INTEGER DEFAULT 0,
    last_signed_at TIMESTAMPTZ,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_revoked BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(employee_id, certificate_thumbprint)
);

-- Strict access control for private keys
ALTER TABLE e_signature_certificates ENABLE ROW LEVEL SECURITY;

CREATE POLICY cert_private_key_restricted ON e_signature_certificates
    FOR SELECT USING (
        auth.uid() = employee_id OR
        auth.jwt_claim('role') = 'admin'
    );
```

---

## Authentication Architecture

### GoTrue (Supabase Auth) Integration

**Supabase GoTrue** is our identity provider:

```
Client                    GoTrue                PostgreSQL
  │                         │                        │
  ├─ POST /signup ─────────→ │ Create user in        │
  │  (email, password)       │ auth.users table      │
  │                         │ ─────────────────────→│
  │                         │
  │ ← JWT + RTK ───────────┤ (No password stored)   │
  │ (session_id)            │
  │
  ├─ POST /login ─────────→ │ Hash password         │
  │  (email, password)      │ Verify against hash   │
  │                         │
  │ ← JWT + RTK ───────────┤ Return session        │
  │
  ├─ POST /verify-mfa ────→ │ Check TOTP code      │
  │  (session_id, code)     │ or SMS code          │
  │                         │
  │ ← JWT (full) ──────────┤ Return full JWT      │
  │
  └─ GET /v1/profile ─────→ │ Validate JWT         │
     (Authorization header)  │ Return user data     │
                             │ from employees       │
                             │ table                │
```

**Why GoTrue?**
- ✅ Built into Supabase (no separate service)
- ✅ Supports SAML, OAuth2, PKCE
- ✅ Handles password hashing (bcrypt)
- ✅ Manages sessions and refresh tokens
- ✅ 21 CFR Part 11 compatible (timestamps, audit)

### Custom Role & Permission Layer (Post-Auth)

```dart
// After GoTrue authentication, our layer adds:

Future<Map<String, dynamic>> fetchUserWithPermissions(String userId) async {
  // Step 1: Get GoTrue user
  final authUser = supabase.auth.currentUser;
  
  // Step 2: Get Employee record
  final employee = await supabase
    .from('employees')
    .select('*')
    .eq('id', userId)
    .single();
  
  // Step 3: Get Roles
  final roles = await supabase
    .from('employee_roles')
    .select('*, roles(*, role_permissions(*, permissions(*)))')
    .eq('employee_id', userId)
    .eq('is_active', true);
  
  // Step 4: Flatten permissions
  final permissions = <String>{};
  for (var empRole in roles) {
    if (empRole['is_active']) {
      final rolePerms = empRole['roles']['role_permissions'];
      for (var rp in rolePerms) {
        permissions.add(rp['permissions']['name']);
      }
    }
  }
  
  // Step 5: Return enriched user object
  return {
    'id': authUser.id,
    'email': authUser.email,
    'employee': employee,
    'roles': roles,
    'permissions': permissions.toList(),
    'scopes': _computeScopes(roles),  // Org, plant, dept access
  };
}
```

---

## API Architecture

### 1. User Registration

**Endpoint:** `POST /v1/auth/register`

**Request:**
```json
{
  "email": "john.trainer@pharmalearn.com",
  "password": "SecurePassword123!",
  "first_name": "John",
  "last_name": "Trainer",
  "organization_id": "org-uuid",
  "department_id": "dept-uuid",
  "job_title": "Manufacturing Trainer",
  "phone_number": "+91-9876543210",
  "employee_code": "EMP001"
}
```

**Response (201 Created):**
```json
{
  "user": {
    "id": "employee-uuid",
    "email": "john.trainer@pharmalearn.com",
    "created_at": "2026-04-23T10:00:00Z"
  },
  "session": {
    "access_token": "eyJhbGciOiJSUzI1NiIs...",
    "refresh_token": "sbr_1234567890...",
    "expires_in": 28800,
    "token_type": "bearer"
  },
  "mfa_required": false,
  "message": "User created successfully. Welcome to PharmaLearn!"
}
```

### 2. User Login

**Endpoint:** `POST /v1/auth/login`

**Request:**
```json
{
  "email": "john.trainer@pharmalearn.com",
  "password": "SecurePassword123!",
  "device_info": {
    "platform": "web",  // or "ios", "android"
    "device_id": "unique-device-id",
    "device_name": "iPad Pro"
  }
}
```

**Response (200 OK):**
```json
{
  "session": {
    "access_token": "eyJhbGciOiJSUzI1NiIs...",
    "refresh_token": "sbr_1234567890...",
    "expires_in": 28800
  },
  "user": {
    "id": "emp-uuid",
    "email": "john.trainer@pharmalearn.com",
    "employee": {
      "first_name": "John",
      "last_name": "Trainer",
      "department": { "id": "...", "name": "Manufacturing" }
    }
  },
  "permissions": [
    "documents:create",
    "documents:approve",
    "training:schedule"
  ],
  "mfa_required": false
}
```

**If MFA Required (200 OK):**
```json
{
  "mfa_required": true,
  "session_id": "session_abc123",
  "mfa_methods_available": ["totp", "sms"],
  "message": "Please complete MFA to proceed"
}
```

### 3. MFA Verification

**Endpoint:** `POST /v1/auth/verify-mfa`

**Request:**
```json
{
  "session_id": "session_abc123",
  "mfa_code": "123456",  // 6-digit TOTP or SMS code
  "mfa_method": "totp"
}
```

**Response (200 OK):**
```json
{
  "session": {
    "access_token": "eyJhbGciOiJSUzI1NiIs...",
    "refresh_token": "sbr_1234567890...",
    "expires_in": 28800
  },
  "user": { ... }
}
```

**Error (401 Unauthorized):**
```json
{
  "error": "invalid_mfa_code",
  "message": "The MFA code is incorrect or expired",
  "retry_count": 2,
  "max_retries": 5
}
```

### 4. Biometric Authentication

**Endpoint:** `POST /v1/auth/biometric-login`

**Request:**
```json
{
  "device_id": "unique-device-id",
  "biometric_type": "face_id",  // or "touch_id", "fingerprint"
  "biometric_signature": "base64-encrypted-biometric-data",
  "platform": "ios"
}
```

**Response (200 OK):**
```json
{
  "session": {
    "access_token": "eyJhbGciOiJSUzI1NiIs...",
    "refresh_token": "sbr_1234567890...",
    "expires_in": 28800
  },
  "auth_method": "biometric",
  "user": { ... }
}
```

### 5. Refresh Token

**Endpoint:** `POST /v1/auth/refresh`

**Request:**
```json
{
  "refresh_token": "sbr_1234567890...",
  "device_fingerprint": "device-hash"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs...",
  "refresh_token": "sbr_0987654321...",  // New RTK (rotated)
  "expires_in": 28800
}
```

### 6. Logout

**Endpoint:** `POST /v1/auth/logout`

**Request:**
```json
{
  "session_id": "optional-specific-session-id",
  "device_id": "optional-device-id"
}
```

**Response (204 No Content):**
- Token revoked
- Session terminated
- Audit logged

### 7. SSO Login (Google/Azure AD)

**Endpoint:** `POST /v1/auth/sso-login`

**Request:**
```json
{
  "provider": "azure_ad",  // or "google", "okta"
  "auth_code": "authorization-code-from-provider",
  "redirect_uri": "https://pharmalearn.com/auth/callback"
}
```

**Response (200 OK):**
```json
{
  "session": { ... },
  "user": { ... },
  "sso_provider": "azure_ad",
  "is_first_login": false,
  "permissions": [ ... ]
}
```

### 8. Get Current User Profile

**Endpoint:** `GET /v1/auth/profile`

**Headers:** `Authorization: Bearer {JWT_TOKEN}`

**Response (200 OK):**
```json
{
  "id": "emp-uuid",
  "email": "john.trainer@pharmalearn.com",
  "employee": {
    "first_name": "John",
    "last_name": "Trainer",
    "department": { "id": "...", "name": "Manufacturing" },
    "job_title": "Manufacturing Trainer",
    "employment_status": "active"
  },
  "roles": [
    {
      "role_id": "role-uuid",
      "role_name": "Manufacturing Manager",
      "plant_id": "plant-a-uuid",
      "department_id": "dept-manu-uuid",
      "valid_from": "2026-01-01",
      "valid_until": "2027-12-31"
    },
    {
      "role_id": "role-trainer-uuid",
      "role_name": "Trainer",
      "valid_from": "2025-06-01"
    }
  ],
  "permissions": [
    "documents:create",
    "documents:read",
    "documents:approve",
    "training:schedule",
    "training:deliver",
    "assessment:grade"
  ],
  "organization": {
    "id": "org-uuid",
    "name": "ABC Pharmaceuticals"
  },
  "mfa_enabled": true,
  "mfa_verified": true,
  "last_login": "2026-04-23T10:00:00Z",
  "login_count": 156
}
```

### 9. Check Permission

**Endpoint:** `POST /v1/auth/check-permission`

**Request:**
```json
{
  "permission": "documents:approve",
  "resource_id": "doc-uuid",
  "scope": {
    "plant_id": "plant-a-uuid",
    "department_id": "dept-manu-uuid"
  }
}
```

**Response (200 OK):**
```json
{
  "has_permission": true,
  "permission": "documents:approve",
  "reason": "User has 'Manufacturing Manager' role in this department"
}
```

**Response (403 Forbidden):**
```json
{
  "has_permission": false,
  "permission": "documents:approve",
  "reason": "User is in 'Viewer' role; only 'Manager' and above can approve"
}
```

### 10. List All Sessions

**Endpoint:** `GET /v1/auth/sessions`

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "session-uuid-1",
      "device_type": "web",
      "device_name": "Chrome on Mac",
      "ip_address": "192.168.1.100",
      "started_at": "2026-04-23T10:00:00Z",
      "last_activity": "2026-04-23T10:15:00Z",
      "is_current": true,
      "auth_method": "password"
    },
    {
      "id": "session-uuid-2",
      "device_type": "ios",
      "device_name": "John's iPad",
      "ip_address": "192.168.1.101",
      "started_at": "2026-04-20T14:00:00Z",
      "last_activity": "2026-04-20T15:30:00Z",
      "is_current": false,
      "auth_method": "biometric"
    }
  ]
}
```

### 11. Revoke Other Sessions

**Endpoint:** `POST /v1/auth/revoke-session/{session_id}`

**Response (204 No Content):**
- Session terminated immediately
- Device logged out
- Audit trail recorded

### 12. E-Signature Certificate Management

**Endpoint:** `POST /v1/auth/e-signature/upload-certificate`

**Request:** (multipart/form-data)
```
file: <PEM certificate>
password: <private key password>
description: "My signing certificate 2026"
```

**Response (201 Created):**
```json
{
  "id": "cert-uuid",
  "thumbprint": "sha256:abc123def456...",
  "subject_name": "CN=John Trainer, O=ABC Pharma, C=US",
  "issued_by": "ABC Pharma CA",
  "valid_from": "2024-01-01T00:00:00Z",
  "valid_until": "2025-12-31T23:59:59Z",
  "is_active": true,
  "message": "Certificate uploaded successfully"
}
```

### 13. Manage MFA

#### Enable TOTP

**Endpoint:** `POST /v1/auth/mfa/enable-totp`

**Response (200 OK):**
```json
{
  "secret": "JBSWY3DPEBLW64TMMQ======",
  "qr_code_url": "otpauth://totp/PharmaLearn:john@pharmalearn.com?secret=...",
  "backup_codes": [
    "backup-code-1",
    "backup-code-2",
    "...",
    "backup-code-10"
  ],
  "message": "Scan the QR code with your authenticator app"
}
```

#### Verify TOTP Setup

**Endpoint:** `POST /v1/auth/mfa/verify-totp-setup`

**Request:**
```json
{
  "code": "123456"
}
```

**Response (200 OK):**
```json
{
  "mfa_enabled": true,
  "mfa_type": "totp",
  "message": "TOTP MFA enabled successfully"
}
```

#### Disable MFA

**Endpoint:** `POST /v1/auth/mfa/disable`

**Request:**
```json
{
  "password": "current-password"  // Confirmation
}
```

**Response (200 OK):**
```json
{
  "mfa_enabled": false,
  "message": "MFA disabled"
}
```

---

## Authorization & RBAC

### Permission Checking in Code

```dart
// Middleware for protecting endpoints
Future<void> checkPermission(
  String requiredPermission,
  String? scopePlantId,
  String? scopeDeptId,
) async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw UnauthorizedException('Not authenticated');
  }
  
  // Get JWT claims
  final claims = JwtDecoder.decode(user.session!.accessToken);
  final permissions = List<String>.from(claims['permissions'] ?? []);
  
  // Check if user has permission
  if (!permissions.contains(requiredPermission)) {
    throw ForbiddenException(
      'Permission denied: $requiredPermission',
    );
  }
  
  // Check scope (if applicable)
  if (scopePlantId != null || scopeDeptId != null) {
    final scopes = claims['scopes'] as List?;
    final hasScope = scopes?.any((scope) {
      return (scopePlantId == null || scope['plant_id'] == scopePlantId) &&
             (scopeDeptId == null || scope['dept_id'] == scopeDeptId);
    }) ?? false;
    
    if (!hasScope) {
      throw ForbiddenException(
        'Access denied to this plant/department',
      );
    }
  }
}

// Usage in endpoint handler
Future<void> approveDocument(String docId, String level) async {
  // Protect with permission + scope check
  await checkPermission(
    'documents:approve_level_$level',
    plantId: document.plant_id,
    deptId: document.department_id,
  );
  
  // Proceed with approval logic
  await documentService.approve(docId, level);
}
```

### RLS (Row-Level Security) Policies

```sql
-- Policy 1: Users can only see documents in their org
CREATE POLICY documents_org_isolation ON documents
    FOR SELECT USING (
        organization_id IN (
            SELECT organization_id FROM employees WHERE id = auth.uid()
        )
    );

-- Policy 2: Users can only see employees in their org
CREATE POLICY employees_org_isolation ON employees
    FOR SELECT USING (
        organization_id IN (
            SELECT organization_id FROM employees WHERE id = auth.uid()
        )
    );

-- Policy 3: Only admins can see all permissions
CREATE POLICY permissions_admin_view ON permissions
    FOR SELECT USING (
        auth.jwt_claim('role') = 'admin' OR
        organization_id IS NULL  -- System permissions visible to all
    );

-- Policy 4: Users can only see their own sessions
CREATE POLICY user_sessions_personal ON user_sessions
    FOR SELECT USING (
        employee_id = auth.uid()
    );
```

---

## Real-World Reference: Enterprise SSO

### Azure AD Integration Pattern (from Learn IQ, Ample Logic)

**Step 1: Register PharmaLearn as Application**

In Azure AD portal:
```
App Registration → PharmaLearn LMS
├── Application (client) ID: client-id-uuid
├── Tenant ID: tenant-uuid
├── Client Secret: secret-xyz (encrypted in sso_configurations)
├── Redirect URI: https://pharmalearn.com/auth/callback
└── API Permissions:
    ├── User.Read (delegated)
    ├── Directory.Read.All (delegated)
    └── Application.Read.All (application)
```

**Step 2: Configuration in DB**

```sql
INSERT INTO sso_configurations (
    organization_id, provider_type, provider_name,
    client_id, client_secret_encrypted, tenant_id,
    authorization_endpoint, token_endpoint, userinfo_endpoint,
    email_claim_name, name_claim_name, department_claim_name,
    is_enabled, is_default
) VALUES (
    'org-uuid', 'azure_ad', 'ABC Pharma Azure AD',
    'client-id', encrypt('secret'), 'tenant-uuid',
    'https://login.microsoftonline.com/tenant-uuid/oauth2/v2.0/authorize',
    'https://login.microsoftonline.com/tenant-uuid/oauth2/v2.0/token',
    'https://graph.microsoft.com/v1.0/me',
    'email', 'displayName', 'department',
    true, true
);
```

**Step 3: OAuth2 Flow**

```
User clicks "Login with Azure AD"
  ↓
POST /v1/auth/sso-login
  ├─ provider: "azure_ad"
  ├─ Generates state + code_verifier (PKCE)
  └─ Redirects to Azure AD authorize endpoint
  
User authenticates with Azure AD
  ↓
Azure AD redirects to:
  /auth/callback?code=...&state=...
  
Back-end exchanges code for token:
  POST https://login.microsoftonline.com/.../ token
  ├─ grant_type: "authorization_code"
  ├─ code: (from callback)
  ├─ client_id: client-id
  ├─ client_secret: secret
  └─ code_verifier: (PKCE verification)
  
Receives ID token + Access token
  ├─ ID Token contains: email, name, department
  └─ Access Token for API calls
  
Extract user info from ID token:
  ├─ email: john.trainer@abc-pharma.com
  ├─ name: John Trainer
  ├─ department: Manufacturing
  └─ groups: ["group-managers", "group-trainers"]
  
Find or create user:
  SELECT * FROM employees WHERE email = 'john.trainer@abc-pharma.com'
  ├─ If exists: Use existing account
  └─ If new: Create employee + link to Azure AD
  
Assign roles automatically (using department + groups):
  ├─ department = "Manufacturing" → role_manufacturing_employee
  ├─ "group-managers" → role_manager
  └─ "group-trainers" → role_trainer
  
Return JWT + RTK
  ↓
User logged in!
```

### Benefits of SSO Integration

| Benefit | Implementation |
|---------|-----------------|
| **No password management** | Azure AD handles passwords |
| **Automatic role assignment** | Groups → Roles mapping |
| **MFA already handled** | Azure AD MFA policies |
| **Audit trail in Azure** | Complementary to our audit |
| **GDPR compliant** | Azure DPA + Schrems II compliant |
| **Support for on-prem AD** | Via Azure AD Connect |

---

## Vyuh Framework Integration

### Using Vyuh for Identity Management

#### 1. **vyuh_entity_system** for Role/Permission CRUD

```dart
// Define Role Entity
final roleEntity = EntityDefinition(
  id: 'role',
  label: 'Role',
  properties: [
    StringProperty(
      id: 'name',
      label: 'Role Name',
      required: true,
    ),
    StringProperty(
      id: 'description',
      label: 'Description',
    ),
    IntegerProperty(
      id: 'level',
      label: 'Hierarchy Level',
      min: 0,
      max: 10,
    ),
    BooleanProperty(
      id: 'is_active',
      label: 'Active',
      defaultValue: true,
    ),
    MultiSelectProperty(
      id: 'permissions',
      label: 'Assigned Permissions',
      options: [
        {'id': 'perm_create_doc', 'label': 'Create Document'},
        {'id': 'perm_approve_doc', 'label': 'Approve Document'},
        {'id': 'perm_train_assign', 'label': 'Assign Training'},
      ],
    ),
  ],
);

// Auto-generates:
// - Role CRUD screens
// - Permission checkboxes
// - Automatic API endpoints
// - Validation (name uniqueness, etc.)
```

#### 2. **vyuh_rule_engine** for Access Decisions

```dart
// Rule: Can user approve this document?
final documentApprovalRule = Rule(
  id: 'can_approve_document',
  name: 'Document Approval Permission',
  conditions: [
    'user.roles contains "approver"',
    'document.department_id in user.assigned_departments',
    'document.status == "under_review"',
    'user.mfa_verified == true',
    'current_approval_level <= user.max_approval_level',
  ],
  action: 'grant_approval_permission',
  otherwise: 'deny_approval',
);

// Evaluate
final canApprove = ruleEngine.evaluate(
  rule: documentApprovalRule,
  context: {
    'user': currentUser,
    'document': doc,
    'current_approval_level': 1,
  },
);

if (!canApprove) {
  showError('You do not have permission to approve this document');
}
```

#### 3. **vyuh_workflow_engine** for MFA Setup

```dart
// MFA Setup Workflow
final mfaSetupWorkflow = WorkflowDefinition(
  id: 'mfa_enrollment',
  label: 'MFA Enrollment',
  steps: [
    TaskNode(
      id: 'show_mfa_options',
      label: 'Select MFA Method',
      assignedTo: RoleExpression('authenticated_user'),
      action: 'mfa/show_options',  // TOTP, SMS, Biometric
    ),
    ConditionalNode(
      id: 'mfa_type_check',
      conditions: {
        'totp': 'generate_totp_secret',
        'sms': 'send_sms_code',
        'biometric': 'register_biometric',
      },
    ),
    TaskNode(
      id: 'verify_mfa',
      label: 'Verify MFA',
      action: 'mfa/verify_setup',
    ),
    TaskNode(
      id: 'save_backup_codes',
      label: 'Save Backup Codes',
      action: 'mfa/download_backup_codes',
    ),
  ],
);
```

---

## Security & Compliance

### 21 CFR Part 11 Compliance

**Section 11.100: General Requirements**

Our implementation:
```sql
-- Every login is audited
INSERT INTO user_sessions (
    employee_id, jwt_token_id, auth_method,
    device_fingerprint, ip_address, user_agent,
    started_at, expires_at
) VALUES (...);

-- Every permission change is logged
INSERT INTO audit_trail (
    entity_type, entity_id, action, changed_by_id,
    old_values, new_values, ip_address
) VALUES (
    'permission', perm_id, 'assigned_to_role',
    admin_id, null, jsonb_build_object('role_id', role_id),
    get_ip_address()
);
```

**Section 11.200: Electronic Signatures**

```dart
// E-signature with PKI certificate
Future<String> signData(String data, String employeeId) async {
  // Load employee's certificate
  final cert = await db.eSignatureCertificates
      .where((c) => c.employeeId == employeeId && c.isActive)
      .first;
  
  if (cert.validUntil.isBefore(DateTime.now())) {
    throw Exception('Certificate expired');
  }
  
  // Sign with private key
  final privateKey = decryptPrivateKey(
    cert.privateKeyEncrypted,
    employeePassword,  // User provides password
  );
  
  final signature = _signWithPrivateKey(
    data,
    privateKey,
    'SHA256withRSA',
  );
  
  // Log the signature action
  await db.eSignatures.insert(
    ESignature(
      signedById: employeeId,
      signatureValue: signature,
      signedTimestamp: DateTime.now(),
      signingReason: 'Approved document SOP-001',
      signedDocumentHash: sha256(data),
      ipAddress: getClientIp(),
    ),
  );
  
  return signature;
}
```

**Section 11.300: Meaning & Intent**

Every e-signature includes context:
```json
{
  "signed_by": "emp-uuid",
  "signed_action": "approved",
  "signing_reason": "Approval of manufacturing SOP v1.1",
  "signed_document_hash": "sha256:abc123...",
  "timestamp": "2026-04-24T14:00:00Z",
  "timestamp_authority": "GlobalSign TSA",
  "ip_address": "192.168.1.100",
  "user_agent": "Mozilla/5.0 (iPad...)"
}
```

**Section 11.400: Audit Trails**

Immutable, append-only audit trail:
```sql
-- No deletes allowed
CREATE POLICY audit_trail_immutable ON audit_trail
    AS (operation = DELETE) USING (FALSE);

-- Example audit entries
INSERT INTO audit_trail VALUES (
    'user_login', employee_id, 'login', employee_id,
    null, '{"method": "password", "mfa": "verified"}',
    client_ip
);

INSERT INTO audit_trail VALUES (
    'role_assignment', role_id, 'assigned_to_employee',
    admin_id,
    null,
    '{"employee_id": "emp-uuid", "valid_from": "2026-01-01"}',
    admin_ip
);
```

### Password Security

```sql
-- Managed by GoTrue (bcrypt hashing, not stored in our DB)
-- GoTrue settings:
-- - Minimum 8 characters
-- - Password changed every 90 days (configurable)
-- - Failed login lockout after 5 attempts (30 min)
-- - Session timeout after 8 hours of inactivity
```

### Token Security

```dart
// JWT token best practices
final jwtConfig = {
  'algorithm': 'RS256',  // Asymmetric (public verify, private sign)
  'expiresIn': '8h',     // Short-lived
  'issuer': 'PharmaLearn LMS',
  'audience': 'pharmalearn-app',
  'subject': 'employee-uuid',
};

// Refresh token rotation
// - Old RTK revoked after 7 days or 30 uses
// - New RTK issued on each refresh
// - Device fingerprint validated (prevent token theft)
```

---

## Implementation Checklist

### Phase 1: Schema & Core Auth (Weeks 1-2)

- [ ] Create Supabase tables
  - [ ] employees
  - [ ] user_credentials
  - [ ] roles, permissions, role_permissions
  - [ ] employee_roles
  - [ ] user_sessions
  - [ ] e_signature_certificates
- [ ] Set up GoTrue configuration
  - [ ] Enable TOTP MFA
  - [ ] Enable Email MFA
  - [ ] Configure password policy
- [ ] Implement RLS policies
  - [ ] Organization isolation
  - [ ] User session privacy
- [ ] Create audit tables & triggers

### Phase 2: API Endpoints (Weeks 3-4)

- [ ] Auth endpoints (register, login, logout)
- [ ] MFA endpoints (enable, verify, disable)
- [ ] Biometric endpoints
- [ ] Session management endpoints
- [ ] Permission checking endpoints
- [ ] E-signature certificate management

### Phase 3: SSO Integration (Weeks 5-6)

- [ ] Azure AD configuration
- [ ] OAuth2/SAML client setup
- [ ] User provisioning logic
- [ ] Group-to-role mapping
- [ ] Test with real Azure AD instance

### Phase 4: Flutter UI (Weeks 7-8)

- [ ] Login screen
- [ ] MFA setup & verification screens
- [ ] Biometric registration
- [ ] User profile screen
- [ ] Session management UI
- [ ] E-signature certificate upload

### Phase 5: Testing & Compliance (Week 9)

- [ ] Unit tests (auth logic, RLS)
- [ ] Integration tests (end-to-end flows)
- [ ] Security testing (OWASP Top 10)
- [ ] 21 CFR Part 11 compliance audit
- [ ] Load testing (1000+ concurrent users)

---

## References

- Supabase GoTrue: https://supabase.com/docs/guides/auth
- 21 CFR Part 11: https://www.ecfr.gov/ead/title-21/chapter-I/part-11
- OAuth2 PKCE: https://oauth.net/2/pkce/
- SAML: https://en.wikipedia.org/wiki/SAML_2.0
- Vyuh Framework: https://pub.vyuh.tech

---

**Document Author:** Identity & Security Team  
**Last Updated:** 2026-04-23  
**Next Review:** 2026-05-23
