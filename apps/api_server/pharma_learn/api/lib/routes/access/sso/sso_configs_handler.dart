import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/query_parser.dart';

/// GET /v1/access/sso/configurations - List SSO configurations
/// Reference: EE §5.4.2 — AD/SSO integration
Future<Response> ssoConfigsListHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'sso.view',
    jwtPermissions: auth.permissions,
  );

  final q = QueryParams.fromRequest(req);
  final offset = (q.page - 1) * q.perPage;

  final response = await supabase
      .from('sso_configurations')
      .select('id, name, provider_type, is_enabled, domain, created_at, updated_at')
      .eq('org_id', auth.orgId)
      .order('name')
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  final pagination = Pagination(
    page: q.page,
    perPage: q.perPage,
    total: response.count,
    totalPages: response.count == 0 ? 1 : (response.count / q.perPage).ceil(),
  );

  return ApiResponse.paginated(response.data, pagination).toResponse();
}

/// POST /v1/access/sso/configurations - Create SSO configuration
Future<Response> ssoConfigsCreateHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'sso.create',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  // Validate required fields
  final errors = <String, String>{};
  final name = body['name'] as String?;
  final providerType = body['provider_type'] as String?;

  if (name == null || name.trim().isEmpty) {
    errors['name'] = 'name is required';
  }
  if (providerType == null) {
    errors['provider_type'] = 'provider_type is required';
  } else if (!['saml', 'oidc', 'ldap'].contains(providerType)) {
    errors['provider_type'] = 'provider_type must be saml, oidc, or ldap';
  }

  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  final result = await supabase.from('sso_configurations').insert({
    'name': name,
    'provider_type': providerType,
    'domain': body['domain'],
    'configuration': body['configuration'] ?? {},
    'is_enabled': body['is_enabled'] ?? false,
    'org_id': auth.orgId,
    'created_by': auth.employeeId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'sso_configurations',
    'entity_id': result['id'],
    'action': 'CREATE',
    'performed_by': auth.employeeId,
    'changes': {'name': name, 'provider_type': providerType},
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}
