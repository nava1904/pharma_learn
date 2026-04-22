import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/ojt/:id - Get OJT assignment details
Future<Response> ojtDetailHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('ojt_assignments')
      .select('''
        *,
        employee:employees(id, employee_number, full_name),
        supervisor:employees!ojt_assignments_supervisor_id_fkey(id, full_name),
        course:courses(id, code, name),
        ojt_tasks(*)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('OJT assignment not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// GET /v1/train/ojt/:id/items - List OJT tasks
Future<Response> ojtItemsHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;

  final result = await supabase
      .from('ojt_tasks')
      .select('*, ojt_task_completion(*)')
      .eq('ojt_assignment_id', id)
      .order('sequence_number');

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/train/ojt/:id/sign-off - Sign off OJT task [esig]
/// Reference: Alfa §4.3.11 — OJT witness sign-off with e-signature
/// Reference: G2 migration — ojt_task_completion.esignature_id
Future<Response> ojtSignoffHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required for OJT sign-off').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'ojt.signoff',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;
  final taskId = body['task_id'] as String?;
  final comments = body['comments'] as String?;

  if (taskId == null) {
    return ErrorResponse.validation({'task_id': 'task_id is required'}).toResponse();
  }

  // Verify task exists and belongs to this OJT assignment
  final task = await supabase
      .from('ojt_tasks')
      .select('id, ojt_assignment_id, task_name')
      .eq('id', taskId)
      .eq('ojt_assignment_id', id)
      .maybeSingle();

  if (task == null) {
    return ErrorResponse.notFound('OJT task not found').toResponse();
  }

  // Check if already signed off
  final existing = await supabase
      .from('ojt_task_completion')
      .select('id')
      .eq('task_id', taskId)
      .maybeSingle();

  if (existing != null) {
    return ErrorResponse.conflict('Task already signed off').toResponse();
  }

  // Get OJT assignment to verify witness is different from trainee
  final assignment = await supabase
      .from('ojt_assignments')
      .select('employee_id')
      .eq('id', id)
      .single();

  if (assignment['employee_id'] == auth.employeeId) {
    return ErrorResponse.validation({
      'witness': 'Trainee cannot sign off their own OJT tasks'
    }).toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'ojt_task_completion',
    'entity_id': taskId,
    'meaning': 'OJT_SIGNOFF',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  // Create task completion record with esignature_id (G2 migration)
  final result = await supabase.from('ojt_task_completion').insert({
    'ojt_assignment_id': id,
    'task_id': taskId,
    'completed_by': assignment['employee_id'],
    'witnessed_by': auth.employeeId,
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'comments': comments,
    'esignature_id': esigResult['id'],
    'org_id': auth.orgId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'ojt_task_completion',
    'entity_id': result['id'],
    'action': 'SIGNOFF',
    'performed_by': auth.employeeId,
    'changes': {'task_id': taskId, 'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/train/ojt/:id/complete - Complete entire OJT assignment [esig]
Future<Response> ojtCompleteHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to complete OJT').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'ojt.complete',
    jwtPermissions: auth.permissions,
  );

  // Verify OJT exists
  final assignment = await supabase
      .from('ojt_assignments')
      .select('id, status, employee_id')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (assignment == null) {
    return ErrorResponse.notFound('OJT assignment not found').toResponse();
  }

  if (assignment['status'] == 'completed') {
    return ErrorResponse.conflict('OJT already completed').toResponse();
  }

  // Verify all tasks are signed off
  final totalTasks = await supabase
      .from('ojt_tasks')
      .select('id')
      .eq('ojt_assignment_id', id);

  final completedTasks = await supabase
      .from('ojt_task_completion')
      .select('id')
      .eq('ojt_assignment_id', id);

  if ((completedTasks as List).length < (totalTasks as List).length) {
    return ErrorResponse.validation({
      'tasks': 'All OJT tasks must be signed off before completion'
    }).toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'ojt_assignments',
    'entity_id': id,
    'meaning': 'COMPLETE_OJT',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  // Update OJT assignment
  final result = await supabase
      .from('ojt_assignments')
      .update({
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'completed_by': auth.employeeId,
        'esignature_id': esigResult['id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  // Publish event for certificate generation
  await OutboxService(supabase).publish(
    aggregateType: 'ojt_assignments',
    aggregateId: id,
    eventType: 'training.completed',
    payload: {
      'ojt_assignment_id': id,
      'employee_id': assignment['employee_id'],
      'training_type': 'ojt',
    },
    orgId: auth.orgId,
  );

  await supabase.from('audit_trails').insert({
    'entity_type': 'ojt_assignments',
    'entity_id': id,
    'action': 'COMPLETE',
    'performed_by': auth.employeeId,
    'changes': {'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}
