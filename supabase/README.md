# PharmaLearn LMS - Supabase Backend

A comprehensive Learning Management System (LMS) backend built with Supabase for pharmaceutical industry compliance, featuring 21 CFR Part 11 and EU Annexure 11 compliance.

## 🏗️ Architecture Overview

```
supabase/
├── schemas/                    # SQL Schema Files
│   ├── 00_extensions/         # PostgreSQL extensions
│   ├── 01_types/              # Enums, composite types, domains
│   ├── 02_core/               # Core infrastructure (audit, workflow, e-signature)
│   ├── 03_organization/       # Organizations, plants, departments
│   ├── 04_identity/           # Roles, permissions, employees, groups
│   ├── 05_documents/          # Document management
│   ├── 06_courses/            # Course management
│   ├── 07_training/           # Training programs (GTP, schedules, OJT)
│   ├── 08_assessment/         # Question banks, assessments, results
│   ├── 09_compliance/         # Training records, certificates, waivers
│   ├── 10_quality/            # Deviation, CAPA, change control
│   ├── 11_audit/              # Security & compliance audit trails
│   ├── 12_notifications/      # Notification system
│   ├── 13_analytics/          # Dashboards and reports
│   ├── 14_workflow/           # Workflow configuration
│   ├── 15_cron/               # Scheduled jobs
│   ├── 16_infrastructure/     # System config, storage, integrations
│   └── 99_policies/           # Row Level Security policies
├── seed/                       # Seed data files
├── functions/                  # Edge Functions
│   ├── auth-hook/             # Authentication audit hook
│   ├── esignature-verify/     # 21 CFR Part 11 e-signature
│   ├── generate-certificate/  # Certificate generation
│   └── send-notification/     # Multi-channel notifications
├── scripts/                    # Deployment scripts
└── tests/                      # Test files
```

## 🔐 Compliance Features

### 21 CFR Part 11 Compliance
- **Electronic Signatures**: Password + biometric verification with meaning statements
- **Audit Trails**: Immutable, timestamped records with hash chain integrity
- **Access Control**: Role-based with hierarchical approval levels
- **Data Integrity**: SHA-256 hash verification for tamper detection

### EU Annexure 11 Compliance
- **Validation**: Documented system validation
- **Accuracy Checks**: Input validation and data verification
- **Data Storage**: Secure, backed up, with disaster recovery
- **Electronic Records**: Complete audit trails with timestamps

## 📊 Learn-IQ Workflow System

The Learn-IQ hierarchical approval system:

- **Role Levels**: 1 (highest authority) to 99.99 (lowest)
- **Approval Rule**: Approvers must have a LOWER level number than initiators
- **Object Lifecycle**:
  ```
  draft → initiated → pending_approval → approved/returned/dropped → active/inactive
  ```

### Standard Reasons
Pre-defined, standardized reasons for audit compliance:
- Approval reasons (APR001-APR005)
- Rejection reasons (REJ001-REJ005)
- Return for revision (RET001-RET003)
- Waiver reasons (WAV001-WAV004)
- E-signature meanings (ESIG001-ESIG004)

## 🚀 Deployment

### Prerequisites
- Supabase CLI installed (`brew install supabase/tap/supabase`)
- Supabase project created

### Deploy Schemas

```bash
# Make deploy script executable
chmod +x supabase/scripts/deploy_schemas.sh

# Run deployment
./supabase/scripts/deploy_schemas.sh
```

Or deploy individual schemas:

```bash
supabase db push --file supabase/schemas/00_extensions/01_uuid.sql
```

### Deploy Edge Functions

```bash
supabase functions deploy esignature-verify
supabase functions deploy generate-certificate
supabase functions deploy send-notification
supabase functions deploy auth-hook
```

### Seed Data

```bash
supabase db push --file supabase/seed/01_organizations.sql
supabase db push --file supabase/seed/02_roles_permissions.sql
supabase db push --file supabase/seed/03_standard_reasons.sql
supabase db push --file supabase/seed/04_notification_templates.sql
```

## 📱 Flutter Integration

### Initialize Supabase

```dart
import 'package:pharma_learn/services/supabase/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService().initialize();
  runApp(MyApp());
}
```

### E-Signature Example

```dart
final service = SupabaseService();

final result = await service.verifyESignature(
  entityType: 'course',
  entityId: courseId,
  action: 'approve',
  meaning: 'I have reviewed and approve this course',
  password: userPassword,
  reasonId: 'APR001',
);
```

### Real-time Subscriptions

```dart
final channel = service.subscribeToTable(
  table: 'training_assignments',
  callback: (payload) {
    print('New assignment: ${payload.newRecord}');
  },
  event: PostgresChangeEvent.insert,
);
```

## 🗃️ Key Tables

### Core Entities
- `organizations` - Multi-tenant organization support
- `employees` - Employee master with compliance tracking
- `roles` - Hierarchical roles with Learn-IQ levels
- `courses` - Course master with version control
- `gtp_masters` - Group Training Programs

### Compliance
- `audit_trails` - Immutable audit log
- `electronic_signatures` - 21 CFR Part 11 signatures
- `training_records` - Complete training history
- `certificates` - Training certificates with QR verification

### Workflow
- `pending_approvals` - Approval queue
- `workflow_instances` - Running workflows
- `workflow_tasks` - Individual approval tasks

## 🔒 Row Level Security

RLS policies ensure:
- Users only see data from their organization
- Employees see their own training records
- Admins have elevated access based on role level
- Audit trails are read-only (no updates/deletes)

## 📈 Analytics

Built-in analytics tables:
- `training_analytics` - Aggregated training metrics
- `course_analytics` - Course performance metrics
- `compliance_snapshots` - Point-in-time compliance status
- `employee_training_analytics` - Individual employee metrics

## 🔔 Notification System

Multi-channel notifications:
- Email (queued for external delivery)
- In-app notifications
- SMS (optional)
- Push notifications (optional)

Templates with variable substitution:
- Training assignments
- Reminders and escalations
- Approval requests
- Certificate issuance

## 📋 Cron Jobs

Scheduled background tasks:
- Training reminders (daily)
- Escalation processing (daily)
- Compliance status updates (daily)
- Certificate expiration checks (daily)
- Analytics aggregation (daily)
- Notification queue processing (every 5 min)

## 🧪 Testing

```bash
# Run tests
supabase test db
```

## 📄 License

Proprietary - PharmaLearn LMS

## 🤝 Support

For support, contact the development team.
