import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/query_parser.dart';

/// GET /v1/roles
Future<Response> rolesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewRoles,
    jwtPermissions: auth.permissions,
  );

  final q = QueryParams.fromRequest(req);

  var query = supabase
      .from('roles')
      .select('*')
      .eq('organization_id', auth.orgId);

  if (q.search != null && q.search!.isNotEmpty) {
    query = query.ilike('name', '%${q.search}%');
  }

  final offset = (q.page - 1) * q.perPage;
  final response = await query
      .order('name', ascending: true)
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  final total = response.count;
  return ApiResponse.paginated(
    response.data,
    Pagination(
      page: q.page,
      perPage: q.perPage,
      total: total,
      totalPages: total == 0 ? 1 : (total / q.perPage).ceil(),
    ),
  ).toResponse();
}

/// POST /v1/roles
///
/// Body: `{name, description, permissions: [...]}`
Future<Response> rolesCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageRoles,
    jwtPermissions: auth.permissions,
  );

  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final name = body['name'] as String?;
  if (name == null || name.isEmpty) {
    throw ValidationException({'name': 'Required'});
  }

  final role = await supabase
      .from('roles')
      .insert({
        'name': name,
        'description': body['description'],
        'organization_id': auth.orgId,
        'created_by': auth.employeeId,
      })
      .select()
      .single();

  final perms = (body['permissions'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      [];

  if (perms.isNotEmpty) {
    await supabase.from('role_permissions').insert(
      perms
          .map((p) => {
                'role_id': role['id'],
                'permission': p,
                'granted_by': auth.employeeId,
              })
          .toList(),
    );
  }

  return ApiResponse.created({'role': role}).toResponse();
}
