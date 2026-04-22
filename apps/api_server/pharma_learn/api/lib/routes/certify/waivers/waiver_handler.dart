import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/certify/waivers/:id - Get waiver by ID
Future<Response> waiverGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('training_waivers')
      .select('''
        *,
        employee:employees(id, employee_number, full_name),
        course:courses(id, code, name),
        assignment:employee_assignments(id),
        waived_by_employee:employees!training_waivers_waived_by_fkey(id, full_name)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Waiver not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/certify/waivers/:id/approve - Approve waiver [esig]
Future<Response> waiverApproveHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to approve waiver').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'waivers.approve',
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('training_waivers')
      .select('id, status')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Waiver not found').toResponse();
  }

  if (existing['status'] != 'pending') {
    return ErrorResponse.conflict('Waiver is not pending approval').toResponse();
  }

  final bodyStr = await req.readAsString();
  final body = bodyStr.isEmpty ? <String, dynamic>{} : jsonDecode(bodyStr) as Map<String, dynamic>;

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'training_waivers',
    'entity_id': id,
    'meaning': 'APPROVE_WAIVER',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  final result = await supabase
      .from('training_waivers')
      .update({
        'status': 'approved',
        'approved_at': DateTime.now().toUtc().toIso8601String(),
        'approved_by': auth.employeeId,
        'approval_comments': body['comments'],
        'esignature_id': esigResult['id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_waivers',
    'entity_id': id,
    'action': 'APPROVE',
    'performed_by': auth.employeeId,
    'changes': {'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/certify/waivers/:id/reject - Reject waiver [esig]
Future<Response> waiverRejectHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to reject waiver').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'waivers.reject',
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('training_waivers')
      .select('id, status')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Waiver not found').toResponse();
  }

  if (existing['status'] != 'pending') {
    return ErrorResponse.conflict('Waiver is not pending approval').toResponse();
  }

  final bodyStr = await req.readAsString();
  final body = bodyStr.isEmpty ? <String, dynamic>{} : jsonDecode(bodyStr) as Map<String, dynamic>;

  final rejectReason = body['reason'] as String?;
  if (rejectReason == null || rejectReason.trim().isEmpty) {
    return ErrorResponse.validation({'reason': 'Rejection reason is required'}).toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'training_waivers',
    'entity_id': id,
    'meaning': 'REJECT_WAIVER',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  final result = await supabase
      .from('training_waivers')
      .update({
        'status': 'rejected',
        'rejected_at': DateTime.now().toUtc().toIso8601String(),
        'rejected_by': auth.employeeId,
        'rejection_reason': rejectReason,
        'esignature_id': esigResult['id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_waivers',
    'entity_id': id,
    'action': 'REJECT',
    'performed_by': auth.employeeId,
    'changes': {'reason': rejectReason, 'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}
