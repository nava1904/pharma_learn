import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/access/delegations/:id - Get delegation by ID
Future<Response> delegationGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('delegations')
      .select('''
        *,
        delegator:employees!delegations_delegator_id_fkey(id, employee_number, full_name),
        delegate:employees!delegations_delegate_id_fkey(id, employee_number, full_name),
        created_by_employee:employees!delegations_created_by_fkey(id, full_name)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Delegation not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}
