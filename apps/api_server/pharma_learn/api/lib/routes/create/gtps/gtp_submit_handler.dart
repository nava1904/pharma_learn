import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/gtps/:id/submit
Future<Response> gtpSubmitHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.createGtps, jwtPermissions: auth.permissions,
  );

  final gtp = await supabase.from('gtp_masters').select('id, name, status, organization_id, plant_id').eq('id', id).eq('organization_id', auth.orgId).maybeSingle();
  if (gtp == null) throw NotFoundException('GTP not found');

  final status = gtp['status'] as String? ?? '';
  if (!['draft', 'initiated', 'returned'].contains(status)) {
    throw ConflictException('GTP cannot be submitted from status "$status".');
  }

  final body = await readJson(req);

  final initiatorLevelRow = await supabase.from('employee_roles').select('roles!inner(level)').eq('employee_id', auth.employeeId).order('roles(level)', ascending: true).limit(1).maybeSingle();
  final initiatorLevel = (initiatorLevelRow?['roles'] as Map?)?['level'] as num? ?? 99.99;

  final initiatorRow = await supabase.from('employees').select('first_name, last_name').eq('id', auth.employeeId).single();
  final initiatorName = '${initiatorRow['first_name']} ${initiatorRow['last_name']}';

  final now = DateTime.now().toUtc();
  final approvalId = await supabase.from('pending_approvals').insert({
    'entity_type': 'gtp_masters',
    'entity_id': id,
    'entity_display_name': gtp['name'],
    'requested_action': 'submit_for_approval',
    'current_state': status,
    'target_state': 'active',
    'initiated_by': auth.employeeId,
    'initiator_name': initiatorName,
    'initiator_role_level': initiatorLevel,
    'requires_approval': true,
    'approval_type': 'by_approval_group',
    'due_date': body['due_date'] ?? now.add(const Duration(days: 7)).toIso8601String(),
    'comments': body['comments'],
    'status': 'pending',
    'organization_id': auth.orgId,
    'plant_id': auth.plantId,
  }).select('id').single();

  await supabase.from('gtp_masters').update({'status': 'pending_approval'}).eq('id', id);

  final updated = await supabase.from('gtp_masters').select().eq('id', id).single();
  return ApiResponse.ok({'gtp': updated, 'approval_id': approvalId['id']}).toResponse();
}
