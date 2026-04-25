import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/gtps/:id
Future<Response> gtpGetHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.viewCourses, jwtPermissions: auth.permissions,
  );

  final gtp = await supabase.from('gtp_masters').select('*, gtp_courses ( course_id, sequence_number, is_mandatory, courses ( id, name ) )')
      .eq('id', id).eq('organization_id', auth.orgId).maybeSingle();

  if (gtp == null) throw NotFoundException('GTP not found');
  return ApiResponse.ok({'gtp': gtp}).toResponse();
}

/// PATCH /v1/gtps/:id
Future<Response> gtpPatchHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.editGtps, jwtPermissions: auth.permissions,
  );

  final gtp = await supabase.from('gtp_masters').select('id, status').eq('id', id).eq('organization_id', auth.orgId).maybeSingle();
  if (gtp == null) throw NotFoundException('GTP not found');

  final status = gtp['status'] as String? ?? '';
  if (!['draft', 'initiated', 'returned'].contains(status)) {
    throw ConflictException('GTP cannot be edited in status "$status".');
  }

  final body = await readJson(req);
  final editableFields = [
    'name', 'short_description', 'schedule_type', 'training_type',
    'effective_from', 'effective_to', 'is_qualification_gtp',
  ];
  final updates = <String, dynamic>{};
  for (final f in editableFields) {
    if (body.containsKey(f)) updates[f] = body[f];
  }

  if (updates.isEmpty) return ApiResponse.ok({'gtp': gtp}).toResponse();

  final updated = await supabase.from('gtp_masters').update(updates).eq('id', id).eq('organization_id', auth.orgId).select().single();
  return ApiResponse.ok({'gtp': updated}).toResponse();
}
