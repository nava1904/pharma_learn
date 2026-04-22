import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/trainers/:id - Get trainer by ID
Future<Response> trainerGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('trainers')
      .select('''
        *,
        employee:employees(id, employee_number, full_name, email),
        trainer_certifications(*)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Trainer not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/trainers/:id - Update trainer
Future<Response> trainerUpdateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'trainers.update',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final updateData = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'updated_by': auth.employeeId,
  };

  if (body['trainer_type'] != null) updateData['trainer_type'] = body['trainer_type'];
  if (body['specializations'] != null) updateData['specializations'] = body['specializations'];
  if (body['bio'] != null) updateData['bio'] = body['bio'];
  if (body['is_active'] != null) updateData['is_active'] = body['is_active'];
  if (body['max_sessions_per_day'] != null) updateData['max_sessions_per_day'] = body['max_sessions_per_day'];

  final result = await supabase
      .from('trainers')
      .update(updateData)
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'trainers',
    'entity_id': id,
    'action': 'UPDATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// GET /v1/trainers/:id/certifications - List trainer certifications
Future<Response> trainerCertsListHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;

  final result = await supabase
      .from('trainer_certifications')
      .select()
      .eq('trainer_id', id)
      .order('valid_until', ascending: false);

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/trainers/:id/certifications - Add trainer certification
Future<Response> trainerCertsAddHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'trainers.manage_certifications',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final errors = <String, String>{};
  if (body['certification_name'] == null) {
    errors['certification_name'] = 'certification_name is required';
  }
  if (body['issued_date'] == null) {
    errors['issued_date'] = 'issued_date is required';
  }

  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  final result = await supabase.from('trainer_certifications').insert({
    'trainer_id': id,
    'certification_name': body['certification_name'],
    'issuing_authority': body['issuing_authority'],
    'certification_number': body['certification_number'],
    'issued_date': body['issued_date'],
    'valid_until': body['valid_until'],
    'document_url': body['document_url'],
    'created_by': auth.employeeId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'trainer_certifications',
    'entity_id': result['id'],
    'action': 'CREATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}
