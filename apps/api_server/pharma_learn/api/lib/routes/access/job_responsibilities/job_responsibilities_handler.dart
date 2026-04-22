import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/access/job-responsibilities
///
/// Lists job responsibilities (admin view).
Future<Response> jobResponsibilitiesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final query = req.url.queryParameters;

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to view job responsibilities');
  }

  var builder = supabase
      .from('job_responsibilities')
      .select('''
        id, designation, date_of_joining, job_responsibility,
        key_result_areas, competencies_required, qualification,
        previous_experience, status, revision_no, 
        effective_from, effective_until, created_at, updated_at,
        employee:employees!job_responsibilities_employee_id_fkey(
          id, employee_number, first_name, last_name
        ),
        department:departments(id, name, unique_code),
        approver_subgroup:subgroups(id, name)
      ''')
      .eq('organization_id', auth.orgId);

  if (query['status'] != null) {
    builder = builder.eq('status', query['status']!);
  }
  if (query['employee_id'] != null) {
    builder = builder.eq('employee_id', query['employee_id']!);
  }
  if (query['department_id'] != null) {
    builder = builder.eq('department_id', query['department_id']!);
  }

  final page = int.tryParse(query['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(query['per_page'] ?? '50') ?? 50;
  final from = (page - 1) * perPage;

  final result = await builder
      .order('created_at', ascending: false)
      .range(from, from + perPage - 1);

  return ApiResponse.ok({
    'job_responsibilities': result,
    'page': page,
    'per_page': perPage,
  }).toResponse();
}

/// POST /v1/access/job-responsibilities
///
/// Creates a job responsibility document for an employee.
Future<Response> jobResponsibilityCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to create job responsibilities');
  }

  final employeeId = requireUuid(body, 'employee_id');
  final designation = requireString(body, 'designation');
  final departmentId = body['department_id'] as String?;
  final dateOfJoiningStr = requireString(body, 'date_of_joining');
  final reportingToName = body['reporting_to_name'] as String?;
  final reportingToDesignation = body['reporting_to_designation'] as String?;
  final authorizedDeputyName = body['authorized_deputy_name'] as String?;
  final authorizedDeputyDesignation = body['authorized_deputy_designation'] as String?;
  final jobResponsibility = requireString(body, 'job_responsibility');
  final keyResultAreas = body['key_result_areas'] as String?;
  final competenciesRequired = body['competencies_required'] as String?;
  final qualification = requireString(body, 'qualification');
  final previousExperience = requireString(body, 'previous_experience');
  final relevantTraining = body['relevant_training'] as String?;
  final externalCertificates = body['external_certificates'] as List?;
  final approverSubgroupId = body['approver_subgroup_id'] as String?;

  // Check for existing active job responsibility
  final existing = await supabase
      .from('job_responsibilities')
      .select('id')
      .eq('employee_id', employeeId)
      .eq('status', 'active')
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Employee already has an active job responsibility document. Create a revision instead.');
  }

  final result = await supabase
      .from('job_responsibilities')
      .insert({
        'organization_id': auth.orgId,
        'employee_id': employeeId,
        'designation': designation,
        'department_id': departmentId,
        'date_of_joining': dateOfJoiningStr,
        'reporting_to_name': reportingToName,
        'reporting_to_designation': reportingToDesignation,
        'authorized_deputy_name': authorizedDeputyName,
        'authorized_deputy_designation': authorizedDeputyDesignation,
        'job_responsibility': jobResponsibility,
        'key_result_areas': keyResultAreas,
        'competencies_required': competenciesRequired,
        'qualification': qualification,
        'previous_experience': previousExperience,
        'relevant_training': relevantTraining,
        'external_certificates': externalCertificates ?? [],
        'approver_subgroup_id': approverSubgroupId,
        'status': 'initiated',
        'created_by': auth.employeeId,
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'job_responsibility',
    aggregateId: result['id'] as String,
    eventType: 'job_responsibility.created',
    payload: {'employee_id': employeeId},
  );

  return ApiResponse.created({
    'job_responsibility': result,
    'message': 'Job responsibility created successfully',
  }).toResponse();
}

/// GET /v1/access/job-responsibilities/:id
Future<Response> jobResponsibilityGetHandler(Request req) async {
  final jrId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (jrId == null || jrId.isEmpty) {
    throw ValidationException({'id': 'Job responsibility ID is required'});
  }

  final result = await supabase
      .from('job_responsibilities')
      .select('''
        id, designation, date_of_joining, reporting_to_name,
        reporting_to_designation, authorized_deputy_name,
        authorized_deputy_designation, job_responsibility,
        key_result_areas, competencies_required, qualification,
        previous_experience, relevant_training, external_certificates,
        status, revision_no, effective_from, effective_until,
        approved_at, accepted_at, document_url, format_number,
        created_at, updated_at,
        employee:employees!job_responsibilities_employee_id_fkey(
          id, employee_number, first_name, last_name, email
        ),
        department:departments(id, name, unique_code),
        approver_subgroup:subgroups(id, name),
        approved_by_employee:employees!job_responsibilities_approved_by_fkey(
          id, first_name, last_name
        ),
        accepted_by_employee:employees!job_responsibilities_accepted_by_fkey(
          id, first_name, last_name
        )
      ''')
      .eq('id', jrId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    throw NotFoundException('Job responsibility not found');
  }

  return ApiResponse.ok({'job_responsibility': result}).toResponse();
}

/// PATCH /v1/access/job-responsibilities/:id
Future<Response> jobResponsibilityUpdateHandler(Request req) async {
  final jrId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to update job responsibilities');
  }

  if (jrId == null || jrId.isEmpty) {
    throw ValidationException({'id': 'Job responsibility ID is required'});
  }

  final existing = await supabase
      .from('job_responsibilities')
      .select('id, status')
      .eq('id', jrId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Job responsibility not found');
  }

  if (existing['status'] == 'active') {
    throw ConflictException('Cannot update active job responsibility. Create a revision instead.');
  }

  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  final allowedFields = [
    'designation', 'department_id', 'reporting_to_name', 'reporting_to_designation',
    'authorized_deputy_name', 'authorized_deputy_designation', 'job_responsibility',
    'key_result_areas', 'competencies_required', 'qualification', 'previous_experience',
    'relevant_training', 'external_certificates', 'approver_subgroup_id'
  ];

  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updates[field] = body[field];
    }
  }

  final result = await supabase
      .from('job_responsibilities')
      .update(updates)
      .eq('id', jrId)
      .select()
      .single();

  return ApiResponse.ok({
    'job_responsibility': result,
    'message': 'Job responsibility updated successfully',
  }).toResponse();
}

/// POST /v1/access/job-responsibilities/:id/submit
Future<Response> jobResponsibilitySubmitHandler(Request req) async {
  final jrId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (jrId == null || jrId.isEmpty) {
    throw ValidationException({'id': 'Job responsibility ID is required'});
  }

  final existing = await supabase
      .from('job_responsibilities')
      .select('id, status, employee_id')
      .eq('id', jrId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Job responsibility not found');
  }

  if (existing['status'] != 'initiated' && existing['status'] != 'rejected') {
    throw ConflictException('Job responsibility cannot be submitted from current status');
  }

  // E-signature for submission
  final esig = body['esig'] as Map<String, dynamic>?;
  String? esigId;
  if (esig != null) {
    final esigService = EsigService(supabase);
    esigId = await esigService.createEsignature(
      employeeId: auth.employeeId,
      meaning: esig['meaning'] as String? ?? 'SUBMIT_JOB_RESPONSIBILITY',
      entityType: 'job_responsibility',
      entityId: jrId,
      reauthSessionId: esig['reauth_session_id'] as String?,
    );
  }

  final result = await supabase
      .from('job_responsibilities')
      .update({
        'status': 'pending_approval',
        'initiator_esignature_id': esigId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', jrId)
      .select()
      .single();

  return ApiResponse.ok({
    'job_responsibility': result,
    'message': 'Job responsibility submitted for approval',
    'esignature_id': esigId,
  }).toResponse();
}

/// POST /v1/access/job-responsibilities/:id/approve
Future<Response> jobResponsibilityApproveHandler(Request req) async {
  final jrId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to approve job responsibilities');
  }

  if (jrId == null || jrId.isEmpty) {
    throw ValidationException({'id': 'Job responsibility ID is required'});
  }

  final existing = await supabase
      .from('job_responsibilities')
      .select('id, status, employee_id')
      .eq('id', jrId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Job responsibility not found');
  }

  if (existing['status'] != 'pending_approval') {
    throw ConflictException('Job responsibility is not pending approval');
  }

  // E-signature for approval
  final esig = body['esig'] as Map<String, dynamic>?;
  String? esigId;
  if (esig != null) {
    final esigService = EsigService(supabase);
    esigId = await esigService.createEsignature(
      employeeId: auth.employeeId,
      meaning: esig['meaning'] as String? ?? 'APPROVE_JOB_RESPONSIBILITY',
      entityType: 'job_responsibility',
      entityId: jrId,
      reauthSessionId: esig['reauth_session_id'] as String?,
    );
  }

  final result = await supabase
      .from('job_responsibilities')
      .update({
        'status': 'pending_acceptance',
        'approved_by': auth.employeeId,
        'approved_at': DateTime.now().toUtc().toIso8601String(),
        'approver_esignature_id': esigId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', jrId)
      .select()
      .single();

  // Notify employee for acceptance
  await OutboxService(supabase).publish(
    aggregateType: 'job_responsibility',
    aggregateId: jrId,
    eventType: 'job_responsibility.approved',
    payload: {
      'employee_id': existing['employee_id'],
      'approved_by': auth.employeeId,
    },
  );

  return ApiResponse.ok({
    'job_responsibility': result,
    'message': 'Job responsibility approved. Pending employee acceptance.',
    'esignature_id': esigId,
  }).toResponse();
}

/// POST /v1/access/job-responsibilities/:id/accept
///
/// Employee accepts their job responsibility document.
Future<Response> jobResponsibilityAcceptHandler(Request req) async {
  final jrId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (jrId == null || jrId.isEmpty) {
    throw ValidationException({'id': 'Job responsibility ID is required'});
  }

  final existing = await supabase
      .from('job_responsibilities')
      .select('id, status, employee_id')
      .eq('id', jrId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Job responsibility not found');
  }

  // Only the assigned employee can accept
  if (existing['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('You can only accept your own job responsibility');
  }

  if (existing['status'] != 'pending_acceptance') {
    throw ConflictException('Job responsibility is not pending acceptance');
  }

  // E-signature for acceptance
  final esig = body['esig'] as Map<String, dynamic>?;
  String? esigId;
  if (esig != null) {
    final esigService = EsigService(supabase);
    esigId = await esigService.createEsignature(
      employeeId: auth.employeeId,
      meaning: esig['meaning'] as String? ?? 'ACCEPT_JOB_RESPONSIBILITY',
      entityType: 'job_responsibility',
      entityId: jrId,
      reauthSessionId: esig['reauth_session_id'] as String?,
    );
  }

  final result = await supabase
      .from('job_responsibilities')
      .update({
        'status': 'active',
        'accepted_by': auth.employeeId,
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
        'employee_esignature_id': esigId,
        'effective_from': DateTime.now().toUtc().toIso8601String().split('T')[0],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', jrId)
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'job_responsibility',
    aggregateId: jrId,
    eventType: 'job_responsibility.accepted',
    payload: {'employee_id': auth.employeeId},
  );

  return ApiResponse.ok({
    'job_responsibility': result,
    'message': 'Job responsibility accepted and now active',
    'esignature_id': esigId,
  }).toResponse();
}

/// POST /v1/access/job-responsibilities/:id/reject
Future<Response> jobResponsibilityRejectHandler(Request req) async {
  final jrId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to reject job responsibilities');
  }

  if (jrId == null || jrId.isEmpty) {
    throw ValidationException({'id': 'Job responsibility ID is required'});
  }

  final reason = requireString(body, 'reason');

  final existing = await supabase
      .from('job_responsibilities')
      .select('id, status')
      .eq('id', jrId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Job responsibility not found');
  }

  if (existing['status'] != 'pending_approval') {
    throw ConflictException('Job responsibility is not pending approval');
  }

  final result = await supabase
      .from('job_responsibilities')
      .update({
        'status': 'rejected',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', jrId)
      .select()
      .single();

  // Log rejection reason
  await supabase.from('audit_trails').insert({
    'entity_type': 'job_responsibility',
    'entity_id': jrId,
    'action': 'rejected',
    'actor_id': auth.employeeId,
    'organization_id': auth.orgId,
    'changes': {'reason': reason},
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });

  return ApiResponse.ok({
    'job_responsibility': result,
    'message': 'Job responsibility rejected',
  }).toResponse();
}

/// GET /v1/access/employees/:id/job-responsibility
///
/// Gets the current active job responsibility for an employee.
Future<Response> employeeJobResponsibilityHandler(Request req) async {
  final employeeId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (employeeId == null || employeeId.isEmpty) {
    throw ValidationException({'id': 'Employee ID is required'});
  }

  // Allow viewing own or if has permission
  if (employeeId != auth.employeeId && !auth.hasPermission(Permissions.viewEmployees)) {
    throw PermissionDeniedException('You do not have permission to view this job responsibility');
  }

  final result = await supabase
      .from('job_responsibilities')
      .select('''
        id, designation, date_of_joining, reporting_to_name,
        reporting_to_designation, authorized_deputy_name,
        authorized_deputy_designation, job_responsibility,
        key_result_areas, competencies_required, qualification,
        previous_experience, relevant_training, external_certificates,
        status, revision_no, effective_from, effective_until,
        approved_at, accepted_at, document_url,
        department:departments(id, name)
      ''')
      .eq('employee_id', employeeId)
      .eq('status', 'active')
      .order('revision_no', ascending: false)
      .limit(1)
      .maybeSingle();

  if (result == null) {
    return ApiResponse.ok({
      'job_responsibility': null,
      'message': 'No active job responsibility found',
    }).toResponse();
  }

  return ApiResponse.ok({'job_responsibility': result}).toResponse();
}

/// GET /v1/access/employees/:id/job-responsibility/history
///
/// Gets all job responsibility revisions for an employee.
Future<Response> employeeJobResponsibilityHistoryHandler(Request req) async {
  final employeeId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (employeeId == null || employeeId.isEmpty) {
    throw ValidationException({'id': 'Employee ID is required'});
  }

  if (employeeId != auth.employeeId && !auth.hasPermission(Permissions.viewEmployees)) {
    throw PermissionDeniedException('You do not have permission to view job responsibility history');
  }

  final result = await supabase
      .from('job_responsibilities')
      .select('''
        id, designation, status, revision_no, 
        effective_from, effective_until, created_at,
        department:departments(id, name)
      ''')
      .eq('employee_id', employeeId)
      .order('revision_no', ascending: false);

  return ApiResponse.ok({
    'employee_id': employeeId,
    'history': result,
    'count': (result as List).length,
  }).toResponse();
}
