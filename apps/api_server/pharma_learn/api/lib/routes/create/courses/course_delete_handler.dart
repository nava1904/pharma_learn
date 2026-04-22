import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// DELETE /v1/courses/:id
///
/// Soft-deletes a course by setting status to 'archived'.
/// Only draft or returned courses can be deleted.
/// Published or approved courses must go through a change control process.
Future<Response> courseDeleteHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final course = await supabase
      .from('courses')
      .select('id, status, organization_id')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (course == null) {
    throw NotFoundException('Course not found');
  }

  final status = course['status'] as String? ?? '';
  const deletableStatuses = ['draft', 'initiated', 'returned'];
  if (!deletableStatuses.contains(status)) {
    throw ConflictException(
      'Course in status "$status" cannot be deleted. Only draft, initiated, or returned courses may be deleted.',
    );
  }

  await supabase.from('courses').update({
    'status': 'archived',
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('id', id);

  return ApiResponse.ok({'deleted': true, 'course_id': id}).toResponse();
}
