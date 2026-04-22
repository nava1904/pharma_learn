import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/query_parser.dart';

/// GET /v1/workflow/quality/capa - List CAPA records
/// Reference: ICH Q10 — Corrective and Preventive Actions
Future<Response> capaListHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final q = QueryParams.fromRequest(req);
  final qp = req.url.queryParameters;
  final offset = (q.page - 1) * q.perPage;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'quality.view',
    jwtPermissions: auth.permissions,
  );

  var query = supabase
      .from('capa_records')
      .select('''
        *,
        created_by_employee:employees!capa_records_created_by_fkey(id, full_name),
        assigned_to_employee:employees!capa_records_assigned_to_fkey(id, full_name)
      ''')
      .eq('org_id', auth.orgId);

  // Filter by status
  if (qp['status'] != null) {
    query = query.eq('status', qp['status']!);
  }

  // Filter by type (corrective/preventive)
  if (qp['type'] != null) {
    query = query.eq('capa_type', qp['type']!);
  }

  // Filter by priority
  if (qp['priority'] != null) {
    query = query.eq('priority', qp['priority']!);
  }

  final response = await query
      .order('created_at', ascending: false)
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

/// GET /v1/workflow/quality/capa/:id - Get CAPA by ID
Future<Response> capaGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'quality.view',
    jwtPermissions: auth.permissions,
  );

  final result = await supabase
      .from('capa_records')
      .select('''
        *,
        created_by_employee:employees!capa_records_created_by_fkey(id, full_name),
        assigned_to_employee:employees!capa_records_assigned_to_fkey(id, full_name),
        capa_actions(*)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('CAPA record not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/workflow/quality/capa - Create CAPA record
Future<Response> capaCreateHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'quality.create',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final errors = <String, String>{};
  if (body['title'] == null) {
    errors['title'] = 'title is required';
  }
  if (body['capa_type'] == null) {
    errors['capa_type'] = 'capa_type is required (corrective/preventive)';
  }
  if (body['description'] == null) {
    errors['description'] = 'description is required';
  }

  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  final result = await supabase.from('capa_records').insert({
    'title': body['title'],
    'capa_type': body['capa_type'],
    'description': body['description'],
    'root_cause': body['root_cause'],
    'source': body['source'],
    'source_reference': body['source_reference'],
    'priority': body['priority'] ?? 'medium',
    'assigned_to': body['assigned_to'],
    'due_date': body['due_date'],
    'status': 'open',
    'created_by': auth.employeeId,
    'org_id': auth.orgId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'capa_records',
    'entity_id': result['id'],
    'action': 'CREATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}

/// POST /v1/workflow/quality/capa/:id/close - Close CAPA [esig]
Future<Response> capaCloseHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to close CAPA').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'quality.close',
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('capa_records')
      .select('id, status')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('CAPA record not found').toResponse();
  }

  if (existing['status'] == 'closed') {
    return ErrorResponse.conflict('CAPA already closed').toResponse();
  }

  final bodyStr = await req.readAsString();
  final body = bodyStr.isEmpty ? <String, dynamic>{} : jsonDecode(bodyStr) as Map<String, dynamic>;

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'capa_records',
    'entity_id': id,
    'meaning': 'CLOSE_CAPA',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  final result = await supabase
      .from('capa_records')
      .update({
        'status': 'closed',
        'closed_at': DateTime.now().toUtc().toIso8601String(),
        'closed_by': auth.employeeId,
        'closure_summary': body['closure_summary'],
        'effectiveness_check': body['effectiveness_check'],
        'esignature_id': esigResult['id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'capa_records',
    'entity_id': id,
    'action': 'CLOSE',
    'performed_by': auth.employeeId,
    'changes': {'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// GET /v1/workflow/quality/deviations - List deviations
Future<Response> deviationsListHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final q = QueryParams.fromRequest(req);
  final qp = req.url.queryParameters;
  final offset = (q.page - 1) * q.perPage;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'quality.view',
    jwtPermissions: auth.permissions,
  );

  var query = supabase
      .from('deviations')
      .select('''
        *,
        reported_by_employee:employees!deviations_reported_by_fkey(id, full_name)
      ''')
      .eq('org_id', auth.orgId);

  // Filter by status
  if (qp['status'] != null) {
    query = query.eq('status', qp['status']!);
  }

  // Filter by severity
  if (qp['severity'] != null) {
    query = query.eq('severity', qp['severity']!);
  }

  final response = await query
      .order('created_at', ascending: false)
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

/// POST /v1/workflow/quality/deviations - Report deviation
Future<Response> deviationCreateHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'quality.report_deviation',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final errors = <String, String>{};
  if (body['title'] == null) {
    errors['title'] = 'title is required';
  }
  if (body['description'] == null) {
    errors['description'] = 'description is required';
  }

  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  final result = await supabase.from('deviations').insert({
    'title': body['title'],
    'description': body['description'],
    'severity': body['severity'] ?? 'minor',
    'area_affected': body['area_affected'],
    'immediate_action': body['immediate_action'],
    'status': 'reported',
    'reported_by': auth.employeeId,
    'reported_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  await OutboxService(supabase).publish(
    aggregateType: 'deviations',
    aggregateId: result['id'] as String,
    eventType: 'quality.deviation_reported',
    payload: {
      'deviation_id': result['id'],
      'severity': body['severity'] ?? 'minor',
      'reported_by': auth.employeeId,
    },
    orgId: auth.orgId,
  );

  await supabase.from('audit_trails').insert({
    'entity_type': 'deviations',
    'entity_id': result['id'],
    'action': 'REPORT',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}
