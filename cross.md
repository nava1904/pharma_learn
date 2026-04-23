# CROSS Module — Inter-Module Integration & Architecture
**PharmaLearn LMS — Cross-Module Communication & Data Flows**

> **Version:** 1.0  
> **Date:** 2026-04-23  
> **Scope:** All 4 core modules (CREATE, ACCESS, TRAIN, CERTIFY)  
> **Pattern:** Event-driven architecture, saga patterns, eventual consistency  
> **Compliance:** Audit trail, ACID transactions where needed, immutable logs

---

## Table of Contents

1. [Integration Overview](#integration-overview)
2. [Module Dependencies Graph](#module-dependencies-graph)
3. [Data Flow Patterns](#data-flow-patterns)
4. [Event-Driven Architecture](#event-driven-architecture)
5. [Saga Patterns (Long-Running Workflows)](#saga-patterns-long-running-workflows)
6. [API Contracts & Message Formats](#api-contracts--message-formats)
7. [Data Consistency & Eventual Consistency](#data-consistency--eventual-consistency)
8. [Error Handling & Compensation](#error-handling--compensation)
9. [Real-Time Notifications](#real-time-notifications)
10. [Deployment & Scaling](#deployment--scaling)

---

## Integration Overview

### The Four Modules at a Glance

```
┌──────────────────────────────────────────────────────────────────┐
│                      PharmaLearn LMS                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │    CREATE       │  │    ACCESS       │  │    TRAIN        │ │
│  │                 │  │                 │  │                 │ │
│  │ Documents       │  │ Authentication  │  │ Sessions        │ │
│  │ Courses         │  │ Authorization   │  │ Attendance      │ │
│  │ Assessments     │  │ E-Signatures    │  │ Progress        │ │
│  │ Certificates    │  │ Audit Trail     │  │ OJT             │ │
│  │                 │  │                 │  │                 │ │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘ │
│           │                    │                    │           │
│           └────────────────────┼────────────────────┘           │
│                                │                                 │
│                                ▼                                 │
│                   ┌─────────────────────┐                       │
│                   │     CERTIFY         │                       │
│                   │                     │                       │
│                   │ Assessments         │                       │
│                   │ Grading             │                       │
│                   │ Certificates        │                       │
│                   │ Compliance Reports  │                       │
│                   └─────────────────────┘                       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

Message Bus (Event-Driven):
├─ document.created
├─ document.approved
├─ course.published
├─ training_assigned
├─ training_completed
├─ assessment.passed
├─ assessment.failed
├─ certificate.issued
└─ certificate.expired
```

---

## Module Dependencies Graph

### Dependency Directions (Flow of Data)

```
CREATE
├── Document published
│   └─ Event: document:published
│      └─ Triggers: CERTIFY (link to assessment)
│         └─ Triggers: TRAIN (make available for training)
│
└─ Course published
   └─ Event: course:published
      ├─ Triggers: ACCESS (update role-based access)
      ├─ Triggers: TRAIN (schedule training sessions)
      └─ Triggers: CERTIFY (create assessment instance)

ACCESS
├── User authenticated
│   └─ Event: user:authenticated
│      ├─ Triggers: TRAIN (fetch assignments)
│      ├─ Triggers: CREATE (fetch accessible documents)
│      └─ Triggers: CERTIFY (fetch available assessments)
│
└─ Role assigned
   └─ Event: role:assigned
      ├─ Triggers: TRAIN (auto-assign training)
      ├─ Triggers: CREATE (update document visibility)
      └─ Triggers: CERTIFY (auto-assign assessment)

TRAIN
├── Training session scheduled
│   └─ Event: training:session:scheduled
│      └─ Triggers: ACCESS (notify approvers)
│
├── Employees enrolled
│   └─ Event: training:employees:enrolled
│      └─ Triggers: CERTIFY (prepare assessment)
│
├── Training completed
│   └─ Event: training:completed
│      └─ Triggers: CERTIFY (auto-enroll in assessment)
│
└─ Attendance recorded
   └─ Event: attendance:recorded
      └─ Triggers: CREATE (audit log to document)

CERTIFY
├── Assessment passed
│   └─ Event: assessment:passed
│      ├─ Triggers: CREATE (issue certificate)
│      ├─ Triggers: TRAIN (mark training complete)
│      └─ Triggers: ACCESS (update employee competency)
│
└─ Assessment failed
   └─ Event: assessment:failed
      ├─ Triggers: TRAIN (assign remedial)
      ├─ Triggers: ACCESS (restrict access to advanced courses)
      └─ Triggers: CERTIFY (trigger remedial assessment)
```

### No Circular Dependencies

```
✓ Good: CREATE → TRAIN → CERTIFY (one-way flow mostly)
✗ Bad: CREATE ↔ CERTIFY (would create circular dependency)

Solution: Use events to decouple:
  CREATE publishes: "course:published"
  CERTIFY subscribes and creates assessment
  No direct API call between them
```

---

## Data Flow Patterns

### Pattern 1: Course Publication → Training Availability

```
Timeline: 10-20 seconds total

T=0: Author clicks "Publish Course"
     ├─ CREATE module
     │  └─ Validates course (all topics, assessment linked)
     │  └─ Updates status: DRAFT → UNDER_REVIEW
     │  └─ Publishes event: course:status_changed
     │     {
     │       "event_id": "evt_123",
     │       "timestamp": "2026-04-23T10:00:00Z",
     │       "course_id": "course-uuid",
     │       "old_status": "draft",
     │       "new_status": "under_review",
     │       "approvers": ["approver_1", "approver_2"],
     │       "metadata": {
     │         "version": "1.0",
     │         "change_summary": "Ready for review"
     │       }
     │     }

T+2: ACCESS module receives event
     ├─ Updates role permissions
     │  └─ Course now visible to assigned roles
     │  └─ Event: access:course_visibility_updated
     │     {
     │       "course_id": "course-uuid",
     │       "visible_to_roles": ["role_trainer", "role_manager"],
     │       "timestamp": "2026-04-23T10:00:02Z"
     │     }

T+4: TRAIN module receives event
     ├─ Makes course available for scheduling
     │  └─ Course now appears in "Schedule Training" dialog
     │  └─ Event: train:course_available_for_scheduling
     │     {
     │       "course_id": "course-uuid",
     │       "available_from": "2026-04-23T10:00:04Z"
     │     }

T+6: CERTIFY module receives event
     ├─ Creates assessment instance from question paper
     │  └─ If course has linked assessment, create editable copy
     │  └─ Event: certify:assessment_created
     │     {
     │       "assessment_id": "assess_uuid",
     │       "course_id": "course-uuid",
     │       "source_question_paper": "qpaper-uuid",
     │       "created_from_event": "course:status_changed"
     │     }

T+8: Approval workflow starts
     ├─ Approver 1 reviews course
     ├─ Approver 2 reviews course
     └─ Both approve → course:published event

T+18: course:published event
      ├─ All modules update final state
      ├─ Managers can now schedule training
      ├─ Employees can see course in dashboard
      └─ Compliance report reflects new training available
```

### Pattern 2: Training Assignment → Certificate Issuance

```
Timeline: ~6 weeks (end-to-end)

Week 1: Training Assignment
  Day 1
  ├─ TRAIN: Employee assigned to course
  │  └─ Event: training:assigned
  │     {
  │       "employee_id": "emp-uuid",
  │       "course_id": "course-uuid",
  │       "assignment_date": "2026-04-23",
  │       "due_date": "2026-06-15",
  │       "assignment_type": "mandatory"
  │     }
  │
  ├─ ACCESS: Receives event
  │  └─ Updates employee's training dashboard
  │  └─ Sends notification: "You have been assigned: GMP Training"
  │  └─ Event: access:notification_sent
  │
  └─ CREATE: Receives event
     └─ Makes course documents accessible
     └─ Logs in audit trail
     └─ Event: create:document_access_granted

Week 2-3: Self-Learning
  ├─ TRAIN: Tracks progress
  │  ├─ Employee opens course
  │  ├─ Reads documents
  │  ├─ Watches videos
  │  └─ Event: training:progress_updated
  │     {
  │       "employee_id": "emp-uuid",
  │       "course_id": "course-uuid",
  │       "progress_percent": 75,
  │       "last_activity": "2026-05-02T14:30:00Z"
  │     }
  │
  └─ CERTIFY: Prepares assessment
     └─ Event: certify:assessment_ready
        └─ Notifies employee assessment unlocked

Week 4: Assessment
  ├─ CERTIFY: Employee takes assessment
  │  ├─ Session: 1 hour
  │  ├─ Submits answers
  │  └─ Event: assessment:submitted
  │     {
  │       "attempt_id": "attempt-uuid",
  │       "employee_id": "emp-uuid",
  │       "submitted_at": "2026-05-06T15:00:00Z",
  │       "time_taken_seconds": 3600
  │     }
  │
  ├─ Auto-grading
  │  ├─ Process: < 1 second
  │  ├─ Results: 85/100 (PASSED)
  │  └─ Event: assessment:graded
  │     {
  │       "attempt_id": "attempt-uuid",
  │       "status": "graded",
  │       "is_passed": true,
  │       "marks": 85,
  │       "graded_at": "2026-05-06T15:00:01Z"
  │     }
  │
  └─ Event: assessment:passed
     {
       "employee_id": "emp-uuid",
       "course_id": "course-uuid",
       "marks": 85,
       "timestamp": "2026-05-06T15:00:01Z"
     }

Week 4: Certificate + Completion
  ├─ CERTIFY: Certificate generation
  │  ├─ Create PDF from template
  │  ├─ Add employee name, course, marks
  │  ├─ Add QR code for verification
  │  ├─ E-sign certificate
  │  └─ Event: certificate:issued
  │     {
  │       "certificate_id": "cert-uuid",
  │       "employee_id": "emp-uuid",
  │       "certificate_number": "CERT-2026-001234",
  │       "issued_at": "2026-05-06T15:05:00Z"
  │     }
  │
  ├─ TRAIN: Mark training as completed
  │  ├─ Update assignment status: COMPLETED
  │  ├─ Store certificate_id reference
  │  └─ Event: training:completed
  │     {
  │       "assignment_id": "assign-uuid",
  │       "employee_id": "emp-uuid",
  │       "completed_on": "2026-05-06",
  │       "certificate_id": "cert-uuid"
  │     }
  │
  ├─ ACCESS: Update competency record
  │  ├─ Employee now "competent" in GMP
  │  ├─ Can access advanced courses
  │  └─ Event: access:competency_updated
  │     {
  │       "employee_id": "emp-uuid",
  │       "competency": "gmp_training",
  │       "level": 3,
  │       "valid_until": "2027-05-06"
  │     }
  │
  └─ CREATE: Archive old versions (if applicable)
     └─ Audit trail: "Training on GMP-v1.1 completed"
```

---

## Event-Driven Architecture

### Message Bus Design

**Technology:** Supabase Realtime + PostgreSQL LISTEN/NOTIFY

```sql
-- Event log table (immutable, append-only)
CREATE TABLE IF NOT EXISTS event_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type TEXT NOT NULL,  -- 'document:published', 'assessment:passed'
    entity_type TEXT,          -- 'document', 'course', 'assessment'
    entity_id UUID,
    source_module TEXT,        -- 'create', 'access', 'train', 'certify'
    payload JSONB NOT NULL,    -- Full event data
    
    -- Routing
    target_modules TEXT[],     -- Modules that should handle this
    processed_by TEXT[],       -- Modules that have processed
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    
    -- Consistency
    version INTEGER DEFAULT 1,
    idempotency_key TEXT,      -- For replay protection
    
    UNIQUE(idempotency_key)
);

CREATE INDEX idx_event_log_type ON event_log(event_type);
CREATE INDEX idx_event_log_entity ON event_log(entity_type, entity_id);
CREATE INDEX idx_event_log_status ON event_log(processed_by);
```

### Event Publishing Pattern

```dart
// When document is approved in CREATE module
Future<void> publishDocumentApprovedEvent(String documentId) async {
  final doc = await db.documents.get(documentId);
  
  final event = {
    'event_type': 'document:approved',
    'entity_type': 'document',
    'entity_id': documentId,
    'source_module': 'create',
    'target_modules': ['access', 'train', 'certify'],
    'payload': {
      'document_id': documentId,
      'document_name': doc.name,
      'approved_by': doc.approvedBy,
      'approved_at': doc.approvedAt,
      'version': doc.versionNo,
      'organization_id': doc.organizationId,
    },
    'created_by': currentUser.id,
    'idempotency_key': '${documentId}_approved_${doc.approvedAt.millisecondsSinceEpoch}',
  };
  
  // Insert into event log
  await db.eventLog.insert(event);
  
  // Publish to channels for real-time
  supabase.realtime.send(
    type: 'broadcast',
    event: 'document:approved',
    payload: event['payload'],
  );
  
  // Trigger processing immediately
  await processEventForAllModules(event);
}
```

### Event Subscription Pattern

```dart
// TRAIN module listens to document:approved events
class TrainModuleEventSubscriber {
  void subscribeToDocumentEvents() {
    supabase.realtime
        .channel('document_events')
        .onPostgresChange(
          event: 'INSERT',
          schema: 'public',
          table: 'event_log',
          filter: 'event_type=eq.document:approved',
          callback: (payload) async {
            final event = payload['new'];
            
            // Mark document as available for training
            await db.documents.update(event['entity_id'], {
              'available_for_training': true,
            });
            
            // Notify managers
            await notificationService.send(
              to: roleQuery(role: 'manager'),
              title: 'New training material available',
              body: event['payload']['document_name'],
            );
            
            // Mark event as processed by TRAIN module
            await db.eventLog.update(event['id'], {
              'processed_by': [
                ...event['processed_by'],
                'train',
              ],
            });
          },
        )
        .subscribe();
  }
}
```

---

## Saga Patterns (Long-Running Workflows)

### Saga 1: Course Publication Workflow

**Type:** Orchestration (coordinator manages steps)

```
Coordinator: CREATE Module
Participants: ACCESS, TRAIN, CERTIFY

Step 1: CREATE validates course
  ├─ Validates all topics present
  ├─ Validates assessment linked
  └─ Status: DRAFT → UNDER_REVIEW
  
Step 2: ACCESS grants permissions
  Request: Grant course access to roles
  ├─ If Success → Mark done
  └─ If Failure → COMPENSATE (revert step 1)
  
Step 3: TRAIN enables scheduling
  Request: Make course available for schedules
  ├─ If Success → Mark done
  └─ If Failure → COMPENSATE (revert steps 1-2)
  
Step 4: CERTIFY creates assessment
  Request: Create assessment from question paper
  ├─ If Success → Publish course
  └─ If Failure → COMPENSATE (revert steps 1-3)
  
Final: course:published event
  └─ All modules finalize state
  
Compensation Flow (if any step fails):
  Step 4 fails:
    ├─ DELETE assessment (created in step 3)
    ├─ REVOKE permissions (granted in step 2)
    ├─ DISABLE scheduling (enabled in step 1)
    └─ Revert to DRAFT status
    
  Notify: Approver with error details
  ```

### Saga 2: Training → Assessment → Certificate (6-week)

**Type:** Choreography (events drive each step)

```
Event 1: training:assigned
  Published by: TRAIN
  → All modules listen
  
Event 2: training:completed
  Published by: TRAIN
  → Triggers: CERTIFY assessment
  
Event 3: assessment:passed
  Published by: CERTIFY
  → Triggers: CREATE (issue certificate)
  → Triggers: TRAIN (mark complete)
  → Triggers: ACCESS (update competency)
  
Event 4: certificate:issued
  Published by: CERTIFY
  → All modules finalize state

Failures Handled:
  Assessment: passed but certificate generation fails
  ├─ Retry mechanism: Try 3 times
  ├─ Compensation: Revert training to "pending_cert"
  └─ Manual recovery: Admin can retry certificate generation

  Training: completed but assessment not taken
  ├─ Automatic escalation: Notify employee
  ├─ Deadline: 7 days from training completion
  └─ Escalation: Manager notification after 14 days
```

---

## API Contracts & Message Formats

### Standard Event Message Format

```json
{
  "event_id": "evt_uuid",
  "event_type": "document:approved",
  "entity_type": "document",
  "entity_id": "doc_uuid",
  "timestamp": "2026-04-23T10:00:00Z",
  "version": 1,
  
  "source": {
    "module": "create",
    "user_id": "emp_uuid",
    "ip_address": "192.168.1.100"
  },
  
  "payload": {
    "document_id": "doc_uuid",
    "name": "SOP-MANU-001",
    "version": "1.0",
    "approver": "approver_name",
    "approved_at": "2026-04-23T10:00:00Z"
  },
  
  "metadata": {
    "idempotency_key": "doc_uuid_approved_1713883200",
    "retry_count": 0,
    "target_modules": ["access", "train"],
    "priority": "high"
  },
  
  "audit": {
    "event_id": "evt_uuid",
    "previous_event_id": "evt_prev_uuid",
    "sequence": 1000
  }
}
```

### Module-to-Module API Contracts

#### CREATE → TRAIN (Make course available for scheduling)

**Event:** `course:published`

**Payload:**
```json
{
  "course_id": "course_uuid",
  "name": "GMP Fundamentals",
  "topics": [
    { "id": "topic_1", "name": "GMP Basics", "estimated_hours": 4 },
    { "id": "topic_2", "name": "Quality Systems", "estimated_hours": 3 }
  ],
  "total_duration_hours": 8,
  "assessment_required": true,
  "assessment_id": "qpaper_uuid"
}
```

**TRAIN Response (acknowledgment):**
```json
{
  "status": "acknowledged",
  "course_id": "course_uuid",
  "available_for_scheduling": true,
  "action_taken": "Added to scheduler",
  "timestamp": "2026-04-23T10:00:05Z"
}
```

#### TRAIN → CERTIFY (Enroll employees in assessment)

**Event:** `training:completed`

**Payload:**
```json
{
  "training_assignment_id": "assign_uuid",
  "employee_id": "emp_uuid",
  "course_id": "course_uuid",
  "completed_on": "2026-05-06",
  "attendance_percentage": 95
}
```

**CERTIFY Response:**
```json
{
  "status": "assessment_enrolled",
  "employee_id": "emp_uuid",
  "attempt_id": "attempt_uuid",
  "assessment_available_until": "2026-05-20",
  "max_attempts": 3,
  "pass_mark": 70
}
```

#### CERTIFY → CREATE (Certificate issuance)

**Event:** `certificate:issued`

**Payload:**
```json
{
  "certificate_id": "cert_uuid",
  "employee_id": "emp_uuid",
  "course_id": "course_uuid",
  "certificate_url": "s3://certificates/cert_uuid.pdf",
  "certificate_number": "CERT-2026-001234",
  "issue_date": "2026-05-06"
}
```

**CREATE Response:**
```json
{
  "status": "certificate_linked",
  "document_type": "CERTIFICATE",
  "document_id": "cert_doc_uuid",
  "storage_location": "s3://certificates/",
  "audit_logged": true
}
```

---

## Data Consistency & Eventual Consistency

### ACID Transactions (Strong Consistency)

**Used for critical operations:**

```sql
-- Approval workflow must be atomic
BEGIN TRANSACTION;

-- Step 1: Update document status
UPDATE documents SET status = 'approved', approved_at = NOW()
WHERE id = $1;

-- Step 2: Record approval
INSERT INTO document_approvals (
    document_id, approver_id, approval_status, approved_at
) VALUES ($1, $2, 'approved', NOW());

-- Step 3: Version archival
UPDATE document_versions SET is_current = FALSE
WHERE document_id = $1 AND is_current = TRUE;

UPDATE document_versions SET is_current = TRUE
WHERE document_id = $1 AND version_no = $2;

-- Step 4: Audit log
INSERT INTO audit_trail (
    entity_type, entity_id, action, changed_by_id, new_values
) VALUES ('document', $1, 'approved', $2, jsonb_build_object(...));

COMMIT;  -- All or nothing
```

### Eventual Consistency (Event-Driven Updates)

**Used for non-critical updates across modules:**

```
Step 1: TRAIN updates training_assignments (COMMITTED)
  └─ UPDATE training_assignments SET status = 'completed'

Step 2: TRAIN publishes event: training:completed
  └─ Inserted into event_log (COMMITTED)

Step 3: CERTIFY subscribes and processes event (ASYNC)
  ├─ Receives event
  ├─ Creates assessment enrollment
  ├─ Eventually: Employee sees assessment available
  │
  └─ If CERTIFY fails:
     ├─ Retry mechanism (exponential backoff)
     ├─ Event remains in event_log (not deleted)
     └─ Manual recovery: Admin dashboard shows unprocessed events

Step 4: ACCESS updates competency records (ASYNC)
  ├─ Receives event
  ├─ Updates employee competency
  └─ Employee dashboard updated (might have 1-2 second delay)

Acceptable Delay: < 5 seconds for "training completed" to appear in dashboard
```

### Idempotency (Prevent Duplicate Processing)

```sql
-- Prevent duplicate event processing
CREATE UNIQUE INDEX idx_event_idempotency 
    ON event_log(idempotency_key);

-- When processing event:
INSERT INTO event_log (..., idempotency_key = ?) 
VALUES (...)
ON CONFLICT (idempotency_key) DO NOTHING;  -- Silently ignore duplicate

-- Mark as processed
UPDATE event_log SET processed_by = array_append(processed_by, 'module_name')
WHERE id = ? 
AND NOT ('module_name' = ANY(processed_by));  -- Only update if not already processed
```

---

## Error Handling & Compensation

### Pattern: Try → Fail → Compensate → Retry

```dart
Future<void> processTrainingCompletion(String assignmentId) async {
  try {
    // Step 1: Mark training as completed
    await trainService.completeTraining(assignmentId);
    
    // Step 2: Notify CERTIFY to create assessment enrollment
    try {
      await certifyService.enrollInAssessment(
        employeeId: assignment.employeeId,
        courseId: assignment.courseId,
      );
    } catch (e) {
      // COMPENSATION: Revert training status
      await trainService.updateStatus(assignmentId, 'in_progress');
      
      // RETRY: Queue for manual processing
      await errorQueue.add({
        'action': 'enroll_assessment',
        'assignment_id': assignmentId,
        'error': e.toString(),
      });
      
      throw Exception('Assessment enrollment failed: $e');
    }
    
    // Step 3: Update compliance records
    try {
      await accessService.updateComplianceStatus(
        employeeId: assignment.employeeId,
        status: 'pending_certification',
      );
    } catch (e) {
      // COMPENSATION: Revert assessment enrollment
      await certifyService.unenrollFromAssessment(
        employeeId: assignment.employeeId,
      );
      
      throw Exception('Compliance update failed: $e');
    }
    
  } catch (e) {
    // Log to error dashboard
    logger.error('Training completion workflow failed', error: e);
    
    // Send alert to admin
    await alertService.send(
      severity: 'high',
      message: 'Training completion failed for $assignmentId',
      details: e.toString(),
    );
  }
}
```

### Compensation Transactions

```sql
-- Rollback course publication
CREATE OR REPLACE FUNCTION compensation_course_publication()
RETURNS TABLE (success BOOLEAN, message TEXT) AS $$
BEGIN
  -- 1. Disable course scheduling (TRAIN module)
  UPDATE training_schedules SET status = 'disabled'
  WHERE course_id = $1;
  
  -- 2. Revoke course access (ACCESS module)
  DELETE FROM course_subgroup_access WHERE course_id = $1;
  
  -- 3. Disable assessments (CERTIFY module)
  UPDATE question_papers SET status = 'draft'
  WHERE course_id = $1 AND status = 'published';
  
  -- 4. Revert course status (CREATE module)
  UPDATE courses SET status = 'draft'
  WHERE id = $1;
  
  -- 5. Audit log
  INSERT INTO audit_trail (entity_type, entity_id, action, ...)
  VALUES ('course', $1, 'publication_rolled_back', ...);
  
  RETURN QUERY SELECT TRUE, 'Course publication rolled back successfully';
END;
$$ LANGUAGE plpgsql;
```

---

## Real-Time Notifications

### Notification Flow (Using Supabase Realtime)

```dart
// When certificate is issued
Future<void> issueCertificate(String employeeId, String certId) async {
  // 1. Create certificate (CERTIFY)
  await db.certificates.insert({...});
  
  // 2. Publish event to notification queue
  await supabase.realtime.broadcast(
    channel: 'employee:$employeeId:certificates',
    event: 'certificate:issued',
    payload: {
      'certificate_id': certId,
      'course_name': 'GMP Fundamentals',
      'issued_at': DateTime.now(),
    },
  );
  
  // 3. Employee's dashboard listens and updates
  // (see below)
}

// Employee dashboard subscription
class EmployeeDashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Subscribe to certificate events
    useEffect(() {
      final subscription = supabase.realtime
          .channel('employee:${currentUser.id}:certificates')
          .on(
            RealtimeListenTypes.broadcast,
            ChannelFilter(event: 'certificate:issued'),
            (payload, [ref]) async {
              // Update UI immediately
              ref.read(certificatesProvider.notifier)
                  .addCertificate(payload['payload']);
              
              // Show toast
              showSnackBar(
                'Congratulations! Certificate issued for ${payload['payload']['course_name']}',
              );
            },
          )
          .subscribe();
      
      return () => subscription.unsubscribe();
    }, []);
  }
}
```

### Notification Types

```
┌─ Real-Time (Realtime WebSocket)
│  ├─ Certificate issued
│  ├─ Assessment available
│  └─ Training session starting (1 hour before)
│
├─ Delayed (Event-driven, 1-5 min delay acceptable)
│  ├─ Training assigned
│  ├─ Attendance recorded
│  └─ Certificate expiring soon (30 days before)
│
└─ Batch (Daily/Weekly, no real-time requirement)
   ├─ Compliance report
   ├─ Training statistics
   └─ Certification expiry alerts (monthly)
```

---

## Deployment & Scaling

### Scaling the Event Bus

```
Low Volume (< 100 events/min):
  ├─ Single PostgreSQL instance
  ├─ Realtime polling every 100ms
  └─ Adequate for < 1000 concurrent users

Medium Volume (100-1000 events/min):
  ├─ PostgreSQL with connection pooling (PgBouncer)
  ├─ Realtime with optimized polling
  ├─ Message queue (Bull/Redis) for processing
  └─ Adequate for 1000-5000 concurrent users

High Volume (1000+ events/min):
  ├─ Dedicated message broker (RabbitMQ, AWS SQS)
  ├─ PostgreSQL for audit trail only
  ├─ Distributed event processing workers
  ├─ Event stream processing (Kafka for analytics)
  └─ Adequate for 5000+ concurrent users
```

### Module Deployment Independence

```
Each module can be deployed independently:

CREATE Module (Backend Service)
├─ Dart Frog or Serverpod
├─ Database: courses, documents tables
├─ Events published to message bus
└─ Subscriptions: access:role_changed

ACCESS Module (Auth Service)
├─ GoTrue (built-in Supabase)
├─ Custom role/permission endpoints
├─ Database: employees, roles, permissions
└─ Events published: user:authenticated, role:assigned

TRAIN Module (Backend Service)
├─ Dart Frog or Serverpod
├─ Database: training_schedules, attendance
├─ Events: training:assigned, training:completed
└─ Subscriptions: course:published, assessment:passed

CERTIFY Module (Backend Service)
├─ Dart Frog or Serverpod
├─ Database: assessments, certificates
├─ Events: assessment:passed, certificate:issued
└─ Subscriptions: training:completed, assessment:failed

Frontend (Flutter)
├─ Single codebase
├─ Connects to all modules via API Gateway
├─ Realtime subscriptions to all events
└─ Local caching (Hive) per module state
```

### Health Checks & Monitoring

```dart
// Module health check endpoints
GET /health (all modules)
  ├─ Database connectivity
  ├─ Message bus connectivity
  ├─ Realtime subscription status
  └─ Response time < 100ms

// Example CERTIFY module health check
GET /v1/health
Response:
{
  "status": "healthy",
  "module": "certify",
  "database": "connected",
  "message_bus": "connected",
  "realtime": "subscribed",
  "pending_events": 5,
  "processed_events": 45000,
  "error_rate": 0.01,
  "response_time_ms": 12
}

// Event processing monitoring
GET /admin/event-processing-status
Response:
{
  "total_events": 50000,
  "unprocessed_events": 5,
  "processing_failures": 2,
  "retry_queue_size": 0,
  "last_processed_at": "2026-04-23T14:45:00Z",
  "average_processing_time_ms": 250
}
```

---

## Integration Testing Strategy

### Test 1: Course Publication End-to-End

```dart
test('Course publication triggers all modules correctly', () async {
  // Setup
  final courseId = await setupTestCourse();
  
  // Execute
  await createService.publishCourse(courseId);
  
  // Verify: CREATE module
  expect(
    await createService.getCourse(courseId),
    hasProperty('status', 'published'),
  );
  
  // Verify: ACCESS module (wait up to 2 seconds)
  await Future.delayed(Duration(milliseconds: 500));
  expect(
    await accessService.isCourseAccessible(courseId, roleId),
    true,
  );
  
  // Verify: TRAIN module
  final schedules = await trainService.getAvailableCoursesForScheduling();
  expect(schedules.map((s) => s.id), contains(courseId));
  
  // Verify: CERTIFY module
  final assessments = await certifyService.getAssessmentsByCourse(courseId);
  expect(assessments.length, greaterThan(0));
  
  // Cleanup
  await cleanupTestData(courseId);
});
```

### Test 2: Training → Certification Workflow

```dart
test('Training completion triggers assessment and certificate', () async {
  // Setup
  final employeeId = await setupTestEmployee();
  final courseId = await setupTestCourse();
  final assignmentId = await trainService.assignTraining(employeeId, courseId);
  
  // Complete training
  await trainService.completeTraining(assignmentId);
  
  // Wait for event propagation (max 2 seconds)
  await Future.delayed(Duration(milliseconds: 500));
  
  // Verify: Assessment enrolled
  final attempt = await certifyService.getLatestAttempt(employeeId, courseId);
  expect(attempt.status, 'enrolled');
  
  // Take and pass assessment
  await certifyService.submitAnswer(attempt.id, q1, 'correct_answer');
  await certifyService.submitAnswer(attempt.id, q2, 'correct_answer');
  final results = await certifyService.submitAssessment(attempt.id);
  expect(results.isPassed, true);
  
  // Verify: Certificate issued
  await Future.delayed(Duration(milliseconds: 500));
  final certificate = await certifyService.getCertificate(employeeId, courseId);
  expect(certificate.status, 'issued');
  
  // Verify: Training marked completed
  final training = await trainService.getAssignment(assignmentId);
  expect(training.status, 'completed');
  expect(training.certificateId, certificate.id);
  
  // Cleanup
  await cleanupTestData();
});
```

---

## References

- Saga Pattern: https://microservices.io/patterns/data/saga.html
- Event Sourcing: https://martinfowler.com/eaaDev/EventSourcing.html
- Supabase Realtime: https://supabase.com/docs/guides/realtime
- PostgreSQL LISTEN/NOTIFY: https://www.postgresql.org/docs/current/sql-notify.html
- Idempotency in APIs: https://stripe.com/blog/idempotency

---

**Document Author:** Integration Architecture Team  
**Last Updated:** 2026-04-23  
**Next Review:** 2026-05-23

---

## Quick Reference: Module Communication Matrix

| From | To | Event | Frequency | Latency |
|------|-----|-------|-----------|---------|
| CREATE | TRAIN | `course:published` | 10-50/day | Real-time |
| CREATE | CERTIFY | `course:published` | 10-50/day | < 5 sec |
| TRAIN | CERTIFY | `training:completed` | 100-500/day | < 5 sec |
| TRAIN | ACCESS | `attendance:recorded` | 1000+/day | < 1 sec |
| CERTIFY | CREATE | `certificate:issued` | 50-200/day | < 5 sec |
| CERTIFY | TRAIN | `assessment:passed` | 50-200/day | < 5 sec |
| ACCESS | All | `role:changed` | 5-20/day | Real-time |
| All | ACCESS | `permission:check` | 10000+/day | < 100ms |

---

**End of Document**
