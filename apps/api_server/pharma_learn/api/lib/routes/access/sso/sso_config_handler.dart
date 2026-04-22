import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/access/sso/configurations/:id - Get SSO configuration details
Future<Response> ssoConfigGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'sso.view',
    jwtPermissions: auth.permissions,
  );

  final result = await supabase
      .from('sso_configurations')
      .select()
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('SSO configuration not found').toResponse();
  }

  // Remove sensitive fields from response
  final sanitized = Map<String, dynamic>.from(result);
  if (sanitized['configuration'] is Map) {
    final config = Map<String, dynamic>.from(sanitized['configuration']);
    config.remove('client_secret');
    config.remove('private_key');
    sanitized['configuration'] = config;
  }

  return ApiResponse.ok(sanitized).toResponse();
}

/// PATCH /v1/access/sso/configurations/:id - Update SSO configuration
Future<Response> ssoConfigUpdateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'sso.update',
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

  if (body['name'] != null) updateData['name'] = body['name'];
  if (body['domain'] != null) updateData['domain'] = body['domain'];
  if (body['is_enabled'] != null) updateData['is_enabled'] = body['is_enabled'];
  if (body['configuration'] != null) updateData['configuration'] = body['configuration'];

  final result = await supabase
      .from('sso_configurations')
      .update(updateData)
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'sso_configurations',
    'entity_id': id,
    'action': 'UPDATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}
