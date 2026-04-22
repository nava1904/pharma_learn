import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/obligations/:id - Get obligation by ID
Future<Response> obligationGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('employee_assignments')
      .select('''
        *,
        course:courses(id, code, name, course_type, estimated_duration_minutes),
        employee:employees(id, employee_number, full_name),
        schedule:training_schedules(id, name)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Obligation not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/train/obligations/:id/waive - Waive training obligation [esig]
/// Reference: EE §5.1.10 — waiver with e-signature
Future<Response> obligationWaiveHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to waive training obligation').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'obligations.waive',
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('employee_assignments')
      .select('id, status, employee_id, course_id')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Obligation not found').toResponse();
  }

  if (existing['status'] == 'completed' || existing['status'] == 'waived') {
    return ErrorResponse.conflict('Cannot waive a completed or already waived obligation').toResponse();
  }

  final bodyStr = await req.readAsString();
  final body = bodyStr.isEmpty ? <String, dynamic>{} : jsonDecode(bodyStr) as Map<String, dynamic>;

  final waiveReason = body['reason'] as String?;
  if (waiveReason == null || waiveReason.trim().isEmpty) {
    return ErrorResponse.validation({'reason': 'Waiver reason is required'}).toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'employee_assignments',
    'entity_id': id,
    'meaning': 'WAIVE',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  // Create waiver record
  await supabase.from('training_waivers').insert({
    'assignment_id': id,
    'employee_id': existing['employee_id'],
    'course_id': existing['course_id'],
    'waived_by': auth.employeeId,
    'reason': waiveReason,
    'esignature_id': esigResult['id'],
    'org_id': auth.orgId,
  });

  // Update assignment status
  final result = await supabase
      .from('employee_assignments')
      .update({
        'status': 'waived',
        'waived_at': DateTime.now().toUtc().toIso8601String(),
        'waived_by': auth.employeeId,
        'waive_reason': waiveReason,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'employee_assignments',
    'entity_id': id,
    'action': 'WAIVE',
    'performed_by': auth.employeeId,
    'changes': {'reason': waiveReason, 'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}
