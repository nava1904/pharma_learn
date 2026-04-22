import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/certify/competencies/:id - Get competency by ID
Future<Response> competencyGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('employee_competencies')
      .select('''
        *,
        employee:employees(id, employee_number, full_name),
        competency_definition:competency_definitions(id, name, code, level),
        certificate:certificates(id, certificate_number)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Competency not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/certify/competencies/:id/revoke - Revoke competency [esig]
Future<Response> competencyRevokeHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to revoke competency').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'competencies.revoke',
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('employee_competencies')
      .select('id, status')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Competency not found').toResponse();
  }

  if (existing['status'] == 'revoked' || existing['status'] == 'invalidated') {
    return ErrorResponse.conflict('Competency already revoked/invalidated').toResponse();
  }

  final bodyStr = await req.readAsString();
  final body = bodyStr.isEmpty ? <String, dynamic>{} : jsonDecode(bodyStr) as Map<String, dynamic>;
  final reason = body['reason'] as String? ?? esig.reason;

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'employee_competencies',
    'entity_id': id,
    'meaning': 'REVOKE_COMPETENCY',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  final result = await supabase
      .from('employee_competencies')
      .update({
        'status': 'revoked',
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
        'revoked_by': auth.employeeId,
        'revocation_reason': reason,
        'esignature_id': esigResult['id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'employee_competencies',
    'entity_id': id,
    'action': 'REVOKE',
    'performed_by': auth.employeeId,
    'changes': {'reason': reason, 'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/certify/competencies - Award competency [esig]
Future<Response> competencyAwardHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to award competency').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'competencies.award',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final errors = <String, String>{};
  if (body['employee_id'] == null) {
    errors['employee_id'] = 'employee_id is required';
  }
  if (body['competency_definition_id'] == null) {
    errors['competency_definition_id'] = 'competency_definition_id is required';
  }

  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'employee_competencies',
    'entity_id': body['competency_definition_id'],
    'meaning': 'AWARD_COMPETENCY',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  final result = await supabase.from('employee_competencies').insert({
    'employee_id': body['employee_id'],
    'competency_definition_id': body['competency_definition_id'],
    'certificate_id': body['certificate_id'],
    'training_record_id': body['training_record_id'],
    'status': 'active',
    'awarded_at': DateTime.now().toUtc().toIso8601String(),
    'awarded_by': auth.employeeId,
    'valid_until': body['valid_until'],
    'esignature_id': esigResult['id'],
    'org_id': auth.orgId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'employee_competencies',
    'entity_id': result['id'],
    'action': 'AWARD',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}
