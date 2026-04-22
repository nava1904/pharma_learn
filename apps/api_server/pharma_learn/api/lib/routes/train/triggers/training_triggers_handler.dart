import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';
import '../../../utils/query_parser.dart';

/// GET /v1/train/triggers/rules
///
/// Lists all training trigger rules for the organization.
/// Training triggers automatically create training assignments
/// based on events like SOP updates, CAPAs, deviations, etc.
Future<Response> triggerRulesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final q = QueryParams.fromRequest(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageTraining,
    jwtPermissions: auth.permissions,
  );

  final offset = (q.page - 1) * q.perPage;
  final eventSource = req.url.queryParameters['event_source'];
  final isActive = req.url.queryParameters['is_active'];

  var query = supabase
      .from('training_trigger_rules')
      .select('''
        id, rule_name, event_source, entity_type_filter, conditions,
        training_assignment_template_id, course_id, document_id,
        target_scope, target_roles, target_employee_ids,
        due_days_from_trigger, priority, is_active, created_at, updated_at,
        course:courses!training_trigger_rules_course_id_fkey (
          id, unique_code, name
        ),
        document:documents!training_trigger_rules_document_id_fkey (
          id, sop_number, name
        )
      ''')
      .eq('organization_id', auth.orgId);

  if (eventSource != null && eventSource.isNotEmpty) {
    query = query.eq('event_source', eventSource);
  }
  if (isActive != null) {
    query = query.eq('is_active', isActive == 'true');
  }

  final rules = await query
      .order('priority', ascending: false)
      .order('created_at', ascending: false)
      .range(offset, offset + q.perPage - 1);

  return ApiResponse.ok({
    'rules': rules,
    'page': q.page,
    'per_page': q.perPage,
  }).toResponse();
}

/// POST /v1/train/triggers/rules
///
/// Creates a new training trigger rule.
Future<Response> triggerRuleCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageTraining,
    jwtPermissions: auth.permissions,
  );

  final ruleName = requireString(body, 'rule_name');
  final eventSource = requireString(body, 'event_source');

  // Validate event source
  final validSources = [
    'sop_update', 'deviation', 'capa', 'role_change', 'new_hire',
    'certification_expiry', 'document_update', 'audit_finding'
  ];
  if (!validSources.contains(eventSource)) {
    throw ValidationException({
      'event_source': 'Invalid event source. Must be one of: ${validSources.join(", ")}'
    });
  }

  final targetScope = body['target_scope'] as String? ?? 'involved_employees';
  final validScopes = ['involved_employees', 'affected_department', 'all_role', 'all_plant', 'specific_employees'];
  if (!validScopes.contains(targetScope)) {
    throw ValidationException({
      'target_scope': 'Invalid target scope. Must be one of: ${validScopes.join(", ")}'
    });
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final rule = await supabase
      .from('training_trigger_rules')
      .insert({
        'organization_id': auth.orgId,
        'rule_name': ruleName,
        'event_source': eventSource,
        'entity_type_filter': body['entity_type_filter'],
        'conditions': body['conditions'],
        'training_assignment_template_id': body['training_assignment_template_id'],
        'course_id': body['course_id'],
        'document_id': body['document_id'],
        'target_scope': targetScope,
        'target_roles': body['target_roles'] ?? [],
        'target_employee_ids': body['target_employee_ids'] ?? [],
        'due_days_from_trigger': body['due_days_from_trigger'] ?? 7,
        'priority': body['priority'] ?? 'high',
        'is_active': body['is_active'] ?? true,
        'created_at': now,
        'updated_at': now,
      })
      .select()
      .single();

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_trigger_rule',
    'entity_id': rule['id'],
    'action': 'TRIGGER_RULE_CREATED',
    'event_category': 'TRAINING',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': {'rule_name': ruleName, 'event_source': eventSource},
  });

  return ApiResponse.created({'rule': rule}).toResponse();
}

/// GET /v1/train/triggers/rules/:id
///
/// Gets a specific training trigger rule.
Future<Response> triggerRuleGetHandler(Request req) async {
  final ruleId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageTraining,
    jwtPermissions: auth.permissions,
  );

  final rule = await supabase
      .from('training_trigger_rules')
      .select('''
        *,
        course:courses!training_trigger_rules_course_id_fkey (
          id, unique_code, name, status
        ),
        document:documents!training_trigger_rules_document_id_fkey (
          id, sop_number, name, status
        )
      ''')
      .eq('id', ruleId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (rule == null) {
    throw NotFoundException('Training trigger rule not found');
  }

  return ApiResponse.ok({'rule': rule}).toResponse();
}

/// PATCH /v1/train/triggers/rules/:id
///
/// Updates a training trigger rule.
Future<Response> triggerRuleUpdateHandler(Request req) async {
  final ruleId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageTraining,
    jwtPermissions: auth.permissions,
  );

  // Verify exists
  final existing = await supabase
      .from('training_trigger_rules')
      .select('id, rule_name')
      .eq('id', ruleId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Training trigger rule not found');
  }

  final allowedFields = [
    'rule_name', 'entity_type_filter', 'conditions',
    'training_assignment_template_id', 'course_id', 'document_id',
    'target_scope', 'target_roles', 'target_employee_ids',
    'due_days_from_trigger', 'priority', 'is_active'
  ];

  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updates[field] = body[field];
    }
  }

  final rule = await supabase
      .from('training_trigger_rules')
      .update(updates)
      .eq('id', ruleId)
      .select()
      .single();

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_trigger_rule',
    'entity_id': ruleId,
    'action': 'TRIGGER_RULE_UPDATED',
    'event_category': 'TRAINING',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': {'updated_fields': updates.keys.toList()},
  });

  return ApiResponse.ok({'rule': rule}).toResponse();
}

/// DELETE /v1/train/triggers/rules/:id
///
/// Deletes (or deactivates) a training trigger rule.
Future<Response> triggerRuleDeleteHandler(Request req) async {
  final ruleId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageTraining,
    jwtPermissions: auth.permissions,
  );

  // Soft delete by deactivating
  await supabase
      .from('training_trigger_rules')
      .update({
        'is_active': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', ruleId)
      .eq('organization_id', auth.orgId);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_trigger_rule',
    'entity_id': ruleId,
    'action': 'TRIGGER_RULE_DEACTIVATED',
    'event_category': 'TRAINING',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
  });

  return ApiResponse.noContent().toResponse();
}

/// GET /v1/train/triggers/events
///
/// Lists training trigger events (audit log of what triggered).
Future<Response> triggerEventsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final q = QueryParams.fromRequest(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageTraining,
    jwtPermissions: auth.permissions,
  );

  final offset = (q.page - 1) * q.perPage;
  final eventSource = req.url.queryParameters['event_source'];
  final processed = req.url.queryParameters['processed'];

  var query = supabase
      .from('training_trigger_events')
      .select('''
        id, event_source, entity_type, entity_id, event_metadata,
        triggered_at, processed, processed_at, assignments_created,
        error_message, created_at
      ''')
      .eq('organization_id', auth.orgId);

  if (eventSource != null && eventSource.isNotEmpty) {
    query = query.eq('event_source', eventSource);
  }
  if (processed != null) {
    query = query.eq('processed', processed == 'true');
  }

  final events = await query
      .order('triggered_at', ascending: false)
      .range(offset, offset + q.perPage - 1);

  return ApiResponse.ok({
    'events': events,
    'page': q.page,
    'per_page': q.perPage,
  }).toResponse();
}

/// POST /v1/train/triggers/fire
///
/// Manually fires a training trigger for testing or ad-hoc assignment.
/// This calls the process_training_trigger SQL function.
Future<Response> triggerFireHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageTraining,
    jwtPermissions: auth.permissions,
  );

  final eventSource = requireString(body, 'event_source');
  final entityId = requireString(body, 'entity_id');
  final entityType = body['entity_type'] as String?;
  final metadata = body['metadata'] as Map<String, dynamic>?;

  // Call the SQL function to process the trigger
  final result = await supabase.rpc(
    'process_training_trigger',
    params: {
      'p_event_source': eventSource,
      'p_entity_id': entityId,
      'p_org_id': auth.orgId,
      'p_entity_type': entityType,
      'p_metadata': metadata,
    },
  );

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_trigger',
    'entity_id': entityId,
    'action': 'TRIGGER_FIRED_MANUALLY',
    'event_category': 'TRAINING',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': {
      'event_source': eventSource,
      'entity_type': entityType,
      'assignments_created': result,
    },
  });

  return ApiResponse.ok({
    'success': true,
    'assignments_created': result,
    'message': 'Training trigger processed successfully',
  }).toResponse();
}

/// POST /v1/train/triggers/events/:id/reprocess
///
/// Reprocesses a failed trigger event.
Future<Response> triggerEventReprocessHandler(Request req) async {
  final eventId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageTraining,
    jwtPermissions: auth.permissions,
  );

  // Get the event
  final event = await supabase
      .from('training_trigger_events')
      .select()
      .eq('id', eventId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (event == null) {
    throw NotFoundException('Training trigger event not found');
  }

  // Reset processed status
  await supabase
      .from('training_trigger_events')
      .update({
        'processed': false,
        'processed_at': null,
        'error_message': null,
        'assignments_created': 0,
      })
      .eq('id', eventId);

  // Fire the trigger again
  final result = await supabase.rpc(
    'process_training_trigger',
    params: {
      'p_event_source': event['event_source'],
      'p_entity_id': event['entity_id'],
      'p_org_id': auth.orgId,
      'p_entity_type': event['entity_type'],
      'p_metadata': event['event_metadata'],
    },
  );

  return ApiResponse.ok({
    'success': true,
    'assignments_created': result,
    'message': 'Trigger event reprocessed successfully',
  }).toResponse();
}

/// GET /v1/train/triggers/stats
///
/// Returns statistics about training triggers.
Future<Response> triggerStatsHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageTraining,
    jwtPermissions: auth.permissions,
  );

  // Get rule counts by event source
  final ruleCounts = await supabase
      .from('training_trigger_rules')
      .select('event_source, is_active')
      .eq('organization_id', auth.orgId);

  // Get event counts
  final eventCounts = await supabase
      .from('training_trigger_events')
      .select('event_source, processed, assignments_created')
      .eq('organization_id', auth.orgId)
      .gte('triggered_at', DateTime.now().subtract(Duration(days: 30)).toIso8601String());

  // Calculate stats
  final rulesBySource = <String, int>{};
  final activeRules = (ruleCounts as List).where((r) => r['is_active'] == true).length;
  for (final rule in ruleCounts) {
    final source = rule['event_source'] as String;
    rulesBySource[source] = (rulesBySource[source] ?? 0) + 1;
  }

  final eventsBySource = <String, int>{};
  var totalAssignments = 0;
  var failedEvents = 0;
  for (final event in eventCounts as List) {
    final source = event['event_source'] as String;
    eventsBySource[source] = (eventsBySource[source] ?? 0) + 1;
    totalAssignments += (event['assignments_created'] as int?) ?? 0;
    if (event['processed'] == false) failedEvents++;
  }

  return ApiResponse.ok({
    'total_rules': ruleCounts.length,
    'active_rules': activeRules,
    'rules_by_source': rulesBySource,
    'events_last_30_days': eventCounts.length,
    'events_by_source': eventsBySource,
    'total_assignments_created': totalAssignments,
    'failed_events': failedEvents,
  }).toResponse();
}
