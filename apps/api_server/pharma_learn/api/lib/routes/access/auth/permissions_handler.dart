import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/auth/permissions/check
///
/// Checks whether the current employee has one or more permissions.
/// First checks JWT-embedded permissions (fast path), then falls back
/// to the `check_permission` RPC.
///
/// Body: `{"permissions": ["documents.approve", "courses.create"]}`
/// Response: `{data: {results: {"documents.approve": true, "courses.create": false}}}`
Future<Response> permissionsCheckHandler(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final requested = (body['permissions'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      [];

  if (requested.isEmpty) {
    return ErrorResponse.validation({'permissions': 'Required non-empty list'})
        .toResponse();
  }

  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final checker = PermissionChecker(supabase);

  final results = <String, bool>{};
  for (final perm in requested) {
    results[perm] = await checker.has(
      auth.employeeId,
      perm,
      jwtPermissions: auth.permissions,
    );
  }

  return ApiResponse.ok({'results': results}).toResponse();
}
