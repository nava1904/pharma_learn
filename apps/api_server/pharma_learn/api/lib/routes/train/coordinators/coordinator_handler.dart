import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/coordinators/:id - Get coordinator by ID
Future<Response> coordinatorGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('training_coordinators')
      .select('''
        *,
        employee:employees(id, employee_number, full_name, email, department_id),
        departments(id, name)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Coordinator not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/train/coordinators/:id - Update coordinator
Future<Response> coordinatorUpdateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'coordinators.update',
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

  if (body['department_ids'] != null) updateData['department_ids'] = body['department_ids'];
  if (body['plant_ids'] != null) updateData['plant_ids'] = body['plant_ids'];
  if (body['scope'] != null) updateData['scope'] = body['scope'];

  final result = await supabase
      .from('training_coordinators')
      .update(updateData)
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_coordinators',
    'entity_id': id,
    'action': 'UPDATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/train/coordinators/:id/deactivate - Deactivate coordinator
Future<Response> coordinatorDeactivateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'coordinators.deactivate',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  final body = bodyStr.isEmpty ? <String, dynamic>{} : jsonDecode(bodyStr) as Map<String, dynamic>;
  final reason = body['reason'] as String?;

  final result = await supabase
      .from('training_coordinators')
      .update({
        'is_active': false,
        'deactivated_at': DateTime.now().toUtc().toIso8601String(),
        'deactivated_by': auth.employeeId,
        'deactivation_reason': reason,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_coordinators',
    'entity_id': id,
    'action': 'DEACTIVATE',
    'performed_by': auth.employeeId,
    'changes': {'reason': reason},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}
