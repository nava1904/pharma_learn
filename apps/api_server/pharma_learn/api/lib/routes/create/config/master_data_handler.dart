import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';
import '../../../utils/query_parser.dart';

/// GET /v1/config/format-numbers
///
/// Lists all format numbers for the organization.
/// Format numbers are used for report numbering and templates.
Future<Response> formatNumbersListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final params = req.url.queryParameters;
  final q = QueryParams.fromRequest(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCourses,
    jwtPermissions: auth.permissions,
  );

  final offset = (q.page - 1) * q.perPage;

  var query = supabase
      .from('format_numbers')
      .select('*')
      .eq('organization_id', auth.orgId);

  if (params['report_type'] != null) {
    query = query.eq('report_type', params['report_type']!);
  }
  if (params['is_active'] != null) {
    query = query.eq('is_active', params['is_active'] == 'true');
  }

  final response = await query
      .order('report_type')
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  return ApiResponse.paginated(
    response.data,
    Pagination(
      page: q.page,
      perPage: q.perPage,
      total: response.count,
      totalPages: response.count == 0 ? 1 : (response.count / q.perPage).ceil(),
    ),
  ).toResponse();
}

/// GET /v1/config/format-numbers/:id
Future<Response> formatNumberGetHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final formatNumber = await supabase
      .from('format_numbers')
      .select('*')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (formatNumber == null) {
    throw NotFoundException('Format number not found');
  }

  return ApiResponse.ok(formatNumber).toResponse();
}

/// POST /v1/config/format-numbers
///
/// Creates a new format number.
///
/// Body:
/// ```json
/// {
///   "format_number": "FMT-001",
///   "unique_code": "ATTENDANCE_SHEET",
///   "report_type": "attendance_sheet",
///   "template_content": "..."
/// }
/// ```
Future<Response> formatNumberCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final formatNumberValue = requireString(body, 'format_number');
  final uniqueCode = requireString(body, 'unique_code');
  final reportType = requireString(body, 'report_type');

  // Check unique constraint
  final existing = await supabase
      .from('format_numbers')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('report_type', reportType)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Format number for report type $reportType already exists');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final formatNumber = await supabase
      .from('format_numbers')
      .insert({
        'organization_id': auth.orgId,
        'format_number': formatNumberValue,
        'unique_code': uniqueCode,
        'report_type': reportType,
        'template_content': body['template_content'],
        'is_active': true,
        'created_at': now,
        'updated_at': now,
      })
      .select()
      .single();

  return ApiResponse.created(formatNumber).toResponse();
}

/// PUT /v1/config/format-numbers/:id
Future<Response> formatNumberUpdateHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('format_numbers')
      .select('*')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Format number not found');
  }

  final now = DateTime.now().toUtc().toIso8601String();
  
  final updateData = <String, dynamic>{
    'updated_at': now,
  };

  if (body['format_number'] != null) updateData['format_number'] = body['format_number'];
  if (body['unique_code'] != null) updateData['unique_code'] = body['unique_code'];
  if (body['template_content'] != null) updateData['template_content'] = body['template_content'];
  if (body['is_active'] != null) updateData['is_active'] = body['is_active'];

  final updated = await supabase
      .from('format_numbers')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/config/format-numbers/:id
Future<Response> formatNumberDeleteHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('format_numbers')
      .select('id')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Format number not found');
  }

  await supabase.from('format_numbers').delete().eq('id', id);

  return ApiResponse.noContent().toResponse();
}

// ============================================================================
// SATISFACTION SCALES
// ============================================================================

/// GET /v1/config/satisfaction-scales
///
/// Lists all satisfaction scales for the organization.
/// Satisfaction scales define rating parameters for feedback evaluation.
Future<Response> satisfactionScalesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final params = req.url.queryParameters;
  final q = QueryParams.fromRequest(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCourses,
    jwtPermissions: auth.permissions,
  );

  final offset = (q.page - 1) * q.perPage;

  var query = supabase
      .from('satisfaction_scales')
      .select('*')
      .eq('organization_id', auth.orgId);

  if (params['is_active'] != null) {
    query = query.eq('is_active', params['is_active'] == 'true');
  }
  if (params['search'] != null && params['search']!.isNotEmpty) {
    query = query.or('name.ilike.%${params['search']}%,unique_code.ilike.%${params['search']}%');
  }

  final response = await query
      .order('name')
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  return ApiResponse.paginated(
    response.data,
    Pagination(
      page: q.page,
      perPage: q.perPage,
      total: response.count,
      totalPages: response.count == 0 ? 1 : (response.count / q.perPage).ceil(),
    ),
  ).toResponse();
}

/// GET /v1/config/satisfaction-scales/:id
Future<Response> satisfactionScaleGetHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final scale = await supabase
      .from('satisfaction_scales')
      .select('*')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (scale == null) {
    throw NotFoundException('Satisfaction scale not found');
  }

  return ApiResponse.ok(scale).toResponse();
}

/// POST /v1/config/satisfaction-scales
///
/// Creates a new satisfaction scale.
///
/// Body:
/// ```json
/// {
///   "name": "5-Point Scale",
///   "unique_code": "SCALE-5",
///   "description": "Standard 5-point satisfaction scale",
///   "number_of_parameters": 5,
///   "parameters": [
///     {"value": 1, "label": "Very Dissatisfied"},
///     {"value": 2, "label": "Dissatisfied"},
///     {"value": 3, "label": "Neutral"},
///     {"value": 4, "label": "Satisfied"},
///     {"value": 5, "label": "Very Satisfied"}
///   ]
/// }
/// ```
Future<Response> satisfactionScaleCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final name = requireString(body, 'name');
  final uniqueCode = requireString(body, 'unique_code');
  final numberOfParameters = (body['number_of_parameters'] as num?)?.toInt();
  final parameters = body['parameters'] as List?;

  if (numberOfParameters == null || numberOfParameters < 2) {
    throw ValidationException({'number_of_parameters': 'Must be at least 2'});
  }

  if (parameters == null || parameters.isEmpty) {
    throw ValidationException({'parameters': 'Parameters are required'});
  }

  if (parameters.length != numberOfParameters) {
    throw ValidationException({
      'parameters': 'Number of parameters must match number_of_parameters',
    });
  }

  // Check unique constraint
  final existing = await supabase
      .from('satisfaction_scales')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('unique_code', uniqueCode)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Satisfaction scale with code $uniqueCode already exists');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final scale = await supabase
      .from('satisfaction_scales')
      .insert({
        'organization_id': auth.orgId,
        'name': name,
        'unique_code': uniqueCode,
        'description': body['description'],
        'number_of_parameters': numberOfParameters,
        'parameters': parameters,
        'is_active': true,
        'created_at': now,
        'updated_at': now,
      })
      .select()
      .single();

  return ApiResponse.created(scale).toResponse();
}

/// PUT /v1/config/satisfaction-scales/:id
Future<Response> satisfactionScaleUpdateHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('satisfaction_scales')
      .select('*')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Satisfaction scale not found');
  }

  // If changing unique_code, verify uniqueness
  if (body['unique_code'] != null && body['unique_code'] != existing['unique_code']) {
    final duplicate = await supabase
        .from('satisfaction_scales')
        .select('id')
        .eq('organization_id', auth.orgId)
        .eq('unique_code', body['unique_code'])
        .neq('id', id)
        .maybeSingle();

    if (duplicate != null) {
      throw ConflictException('Satisfaction scale with code ${body['unique_code']} already exists');
    }
  }

  // Validate parameters if provided
  final parameters = body['parameters'] as List?;
  final numberOfParameters = (body['number_of_parameters'] as num?)?.toInt() ?? 
      existing['number_of_parameters'] as int;

  if (parameters != null && parameters.length != numberOfParameters) {
    throw ValidationException({
      'parameters': 'Number of parameters must match number_of_parameters',
    });
  }

  final now = DateTime.now().toUtc().toIso8601String();
  
  final updateData = <String, dynamic>{
    'updated_at': now,
  };

  if (body['name'] != null) updateData['name'] = body['name'];
  if (body['unique_code'] != null) updateData['unique_code'] = body['unique_code'];
  if (body['description'] != null) updateData['description'] = body['description'];
  if (body['number_of_parameters'] != null) updateData['number_of_parameters'] = body['number_of_parameters'];
  if (parameters != null) updateData['parameters'] = parameters;
  if (body['is_active'] != null) updateData['is_active'] = body['is_active'];

  final updated = await supabase
      .from('satisfaction_scales')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/config/satisfaction-scales/:id
Future<Response> satisfactionScaleDeleteHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('satisfaction_scales')
      .select('id')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Satisfaction scale not found');
  }

  // Check if scale is in use by any feedback templates
  final inUse = await supabase
      .from('feedback_evaluation_templates')
      .select('id')
      .eq('satisfaction_scale_id', id)
      .limit(1)
      .maybeSingle();

  if (inUse != null) {
    throw ConflictException('Cannot delete scale that is in use by feedback templates');
  }

  await supabase.from('satisfaction_scales').delete().eq('id', id);

  return ApiResponse.noContent().toResponse();
}
