# Training Triggers & User Profiles Implementation

**Date:** 2026-04-27  
**Status:** ✅ Complete

---

## Summary

This implementation completes the training trigger system and user profile management, bringing backend coverage from 94.5% to 98.2%.

---

## 1. Training Triggers Management

### New Files Created

**`lib/routes/train/triggers/training_triggers_handler.dart`** (~450 lines)

Complete CRUD API for training trigger rules and event management.

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/train/triggers/rules` | GET | List all trigger rules |
| `/v1/train/triggers/rules` | POST | Create new trigger rule |
| `/v1/train/triggers/rules/:id` | GET | Get trigger rule details |
| `/v1/train/triggers/rules/:id` | PATCH | Update trigger rule |
| `/v1/train/triggers/rules/:id` | DELETE | Deactivate trigger rule |
| `/v1/train/triggers/events` | GET | List trigger events (audit log) |
| `/v1/train/triggers/events/:id/reprocess` | POST | Reprocess failed event |
| `/v1/train/triggers/fire` | POST | Manually fire a trigger |
| `/v1/train/triggers/stats` | GET | Trigger statistics |

**Total: 9 endpoints**

### Event Sources Supported

- `sop_update` - Document/SOP revision
- `deviation` - Quality deviation raised
- `capa` - CAPA created
- `role_change` - Employee role changed
- `new_hire` - New employee onboarded
- `certification_expiry` - Certificate expiring
- `document_update` - General document update
- `audit_finding` - Audit finding recorded

### Target Scopes

- `involved_employees` - Employees directly linked to entity
- `affected_department` - All employees in affected department
- `all_role` - All employees with specific roles
- `all_plant` - All employees in plant
- `specific_employees` - Manually specified employee list

---

## 2. Quality-to-Training Integration

### Updated Files

**`lib/routes/workflow/quality/deviation_handler.dart`**
- Added `_fireDeviationTrainingTrigger()` function
- Automatically fires training trigger when deviation is created

**`lib/routes/workflow/quality/capa_handler.dart`**
- Added `_fireCapaTrainingTrigger()` function
- Automatically fires training trigger when CAPA is created

### How It Works

```
Deviation Created → _fireDeviationTrainingTrigger()
                 → supabase.rpc('process_training_trigger')
                 → Matches active rules for 'deviation' event
                 → Creates employee_assignments for matched employees
                 → Logs event in training_trigger_events
```

---

## 3. User Profile Management

### New Files Created

**`lib/routes/access/employees/employee_profile_handler.dart`** (~480 lines)

Complete permission profile and override management.

**`supabase/schemas/03_access_control/07_permission_overrides.sql`** (~130 lines)

Schema for direct permission grants/revocations.

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/access/employees/:id/profile` | GET | Get effective permissions |
| `/v1/access/employees/:id/profile` | PUT | Assign global profile |
| `/v1/access/employees/:id/permissions` | GET | List permission overrides |
| `/v1/access/employees/:id/permissions/grant` | POST | Grant direct permission |
| `/v1/access/employees/:id/permissions/revoke` | POST | Revoke permission |
| `/v1/access/employees/:id/permissions/bulk` | POST | Bulk update permissions |
| `/v1/access/employees/:id/permissions/:permission` | DELETE | Remove override |

**Total: 7 endpoints**

### Permission Resolution Order

1. **Direct Denial** (highest priority) - Explicitly denied permission
2. **Direct Grant** - Explicitly granted permission
3. **Role-based** - Permissions from assigned roles via global profiles

### Schema: employee_permission_overrides

```sql
CREATE TABLE employee_permission_overrides (
    id UUID PRIMARY KEY,
    employee_id UUID NOT NULL REFERENCES employees(id),
    permission TEXT NOT NULL,
    granted BOOLEAN NOT NULL DEFAULT true,
    granted_by UUID REFERENCES employees(id),
    granted_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ,  -- NULL = permanent
    reason TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT uq_employee_permission UNIQUE (employee_id, permission)
);
```

### SQL Functions Added

- `get_employee_effective_permissions(p_employee_id)` - Returns all permissions with sources
- `employee_has_permission(p_employee_id, p_permission)` - Checks specific permission

---

## 4. Routes Updated

### `train/routes.dart`
```dart
import 'triggers/routes.dart';
// ...
mountTriggersRoutes(app);
```

### `access/employees/routes.dart`
```dart
import 'employee_profile_handler.dart';
// ...
..get('/v1/access/employees/:id/profile', employeeProfileGetHandler)
..put('/v1/access/employees/:id/profile', employeeProfileAssignHandler)
..get('/v1/access/employees/:id/permissions', employeePermissionsListHandler)
..post('/v1/access/employees/:id/permissions/grant', employeePermissionGrantHandler)
..post('/v1/access/employees/:id/permissions/revoke', employeePermissionRevokeHandler)
..post('/v1/access/employees/:id/permissions/bulk', employeePermissionsBulkHandler)
..delete('/v1/access/employees/:id/permissions/:permission', employeePermissionRemoveHandler)
```

---

## 5. Validation

```
$ dart analyze lib/
Analyzing lib...
12 issues found (all info-level lint warnings).
```

No compile errors.

---

## 6. Coverage Improvement

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| **Implemented** | 94.5% (205) | 98.2% (213) | +3.7% |
| **Partial** | 3.2% (7) | 0% (0) | -3.2% |
| **Missing** | 2.3% (5) | 1.8% (4) | -0.5% |

### Items Completed
- ✅ Training Trigger Rules CRUD
- ✅ Training Trigger Events Audit
- ✅ Quality-to-Training Automation (Deviation, CAPA)
- ✅ User Profile Assignment
- ✅ Direct Permission Grants/Revokes
- ✅ Permission Override Management

### Remaining (Low Priority)
- Document Types/Categories API
- Plants/Organizations API
- Venue Templates API
- Password Reset Self-Service

---

## 7. Usage Examples

### Create a Training Trigger Rule

```http
POST /v1/train/triggers/rules
{
  "rule_name": "Critical Deviation Training",
  "event_source": "deviation",
  "conditions": {"severity": ["critical", "major"]},
  "course_id": "uuid-of-deviation-handling-course",
  "target_scope": "affected_department",
  "due_days_from_trigger": 7,
  "priority": "critical",
  "is_active": true
}
```

### Grant Direct Permission

```http
POST /v1/access/employees/:id/permissions/grant
{
  "permission": "training.triggers.manage",
  "reason": "Temporary access for Q1 training initiative",
  "expires_at": "2026-06-30T23:59:59Z"
}
```

### Get Effective Permissions

```http
GET /v1/access/employees/:id/profile

Response:
{
  "employee": {...},
  "roles": [...],
  "direct_overrides": [...],
  "effective_permissions": ["training.view", "reports.export", ...],
  "permission_sources": {
    "training.view": [{"source": "role", "role_name": "Trainer"}],
    "reports.export": [{"source": "direct_grant", "expires_at": "..."}]
  }
}
```
