import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/induction
///
/// Coordinator registers an employee for induction.
/// Body: { employee_id, induction_template_id?, start_date?, trainer_id? }
Future<Response> inductionCoordinatorCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to manage inductions');
  }

  final employeeId = requireUuid(body, 'employee_id');
  final inductionTemplateId = body['induction_template_id'] as String?;
  final startDateStr = body['start_date'] as String?;
  final trainerId = body['trainer_id'] as String?;

  // Verify employee exists and belongs to organization
  final employee = await supabase
      .from('employees')
      .select('id, organization_id, induction_completed')
      .eq('id', employeeId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  if (employee['induction_completed'] == true) {
    throw ConflictException('Employee has already completed induction');
  }

  // Check if induction already exists
  final existingInduction = await supabase
      .from('employee_induction')
      .select('id, status')
      .eq('employee_id', employeeId)
      .inFilter('status', ['pending', 'in_progress'])
      .maybeSingle();

  if (existingInduction != null) {
    throw ConflictException('Employee already has an active induction program');
  }

  // Parse start date
  DateTime startDate = DateTime.now();
  if (startDateStr != null) {
    startDate = DateTime.tryParse(startDateStr) ?? DateTime.now();
  }

  // Get or use default induction template
  String? templateId = inductionTemplateId;
  if (templateId == null) {
    final defaultTemplate = await supabase
        .from('induction_templates')
        .select('id')
        .eq('organization_id', auth.orgId)
        .eq('is_default', true)
        .maybeSingle();
    templateId = defaultTemplate?['id'] as String?;
  }

  // Insert induction record
  final induction = await supabase
      .from('employee_induction')
      .insert({
        'employee_id': employeeId,
        'organization_id': auth.orgId,
        'induction_template_id': templateId,
        'trainer_id': trainerId,
        'start_date': startDate.toIso8601String().split('T')[0],
        'status': 'pending',
        'created_by': auth.employeeId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      })
      .select()
      .single();

  // Create progress records for each module if template exists
  if (templateId != null) {
    final templateModules = await supabase
        .from('induction_template_modules')
        .select('id, module_id, sequence_order')
        .eq('template_id', templateId)
        .order('sequence_order');

    for (final module in templateModules as List) {
      await supabase.from('employee_induction_progress').insert({
        'induction_id': induction['id'],
        'module_id': module['module_id'],
        'status': 'pending',
        'sequence_order': module['sequence_order'],
      });
    }
  }

  await OutboxService(supabase).publish(
    aggregateType: 'employee_induction',
    aggregateId: induction['id'] as String,
    eventType: 'induction.registered',
    payload: {
      'employee_id': employeeId,
      'trainer_id': trainerId,
      'start_date': startDate.toIso8601String(),
    },
  );

  // Notify trainer if assigned
  if (trainerId != null) {
    await supabase.functions.invoke('send-notification', body: {
      'employee_id': trainerId,
      'template_key': 'induction_trainer_assigned',
      'data': {
        'induction_id': induction['id'],
        'employee_id': employeeId,
      },
    });
  }

  return ApiResponse.created(induction).toResponse();
}

/// GET /v1/train/induction
///
/// Coordinator lists all employee inductions.
/// Query params: status, department_id, from_date, to_date, page, per_page
Future<Response> inductionCoordinatorListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to view inductions');
  }

  final params = req.url.queryParameters;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20') ?? 20;
  final statusFilter = params['status'];
  final departmentFilter = params['department_id'];
  final fromDate = params['from_date'];
  final toDate = params['to_date'];

  var query = supabase
      .from('employee_induction')
      .select('''
        id, start_date, status, trainer_confirmed, completed_at,
        employee:employees!employee_induction_employee_id_fkey(
          id, first_name, last_name, email, department_id,
          departments(id, name)
        ),
        trainer:employees!employee_induction_trainer_id_fkey(
          id, first_name, last_name
        ),
        induction_template:induction_templates(
          id, name
        )
      ''')
      .eq('organization_id', auth.orgId);

  if (statusFilter != null) {
    query = query.eq('status', statusFilter);
  }

  if (fromDate != null) {
    query = query.gte('start_date', fromDate);
  }

  if (toDate != null) {
    query = query.lte('start_date', toDate);
  }

  final results = await query
      .order('start_date', ascending: false)
      .range((page - 1) * perPage, page * perPage - 1);

  // Filter by department post-query
  List<Map<String, dynamic>> filteredResults = List<Map<String, dynamic>>.from(results);
  if (departmentFilter != null) {
    filteredResults = filteredResults
        .where((r) => r['employee']?['department_id'] == departmentFilter)
        .toList();
  }

  // Get counts by status
  final allInductions = await supabase
      .from('employee_induction')
      .select('status')
      .eq('organization_id', auth.orgId);

  final statusCounts = <String, int>{};
  for (final ind in allInductions as List) {
    final status = ind['status'] as String? ?? 'unknown';
    statusCounts[status] = (statusCounts[status] ?? 0) + 1;
  }

  return ApiResponse.ok({
    'inductions': filteredResults,
    'pagination': {
      'page': page,
      'per_page': perPage,
      'total': filteredResults.length,
    },
    'summary': statusCounts,
  }).toResponse();
}

/// GET /v1/train/induction/:id
///
/// Coordinator views specific employee induction with progress.
Future<Response> inductionCoordinatorGetHandler(Request req) async {
  final inductionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to view inductions');
  }

  if (inductionId == null || inductionId.isEmpty) {
    throw ValidationException({'id': 'Induction ID is required'});
  }

  final induction = await supabase
      .from('employee_induction')
      .select('''
        id, start_date, status, trainer_confirmed, trainer_notes,
        completed_at, created_at,
        employee:employees!employee_induction_employee_id_fkey(
          id, first_name, last_name, email, department_id,
          departments(id, name)
        ),
        trainer:employees!employee_induction_trainer_id_fkey(
          id, first_name, last_name, email
        ),
        induction_template:induction_templates(
          id, name, description
        ),
        created_by_employee:employees!employee_induction_created_by_fkey(
          id, first_name, last_name
        )
      ''')
      .eq('id', inductionId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (induction == null) {
    throw NotFoundException('Induction not found');
  }

  // Get progress details
  final progress = await supabase
      .from('employee_induction_progress')
      .select('''
        id, status, started_at, completed_at, score,
        induction_modules(
          id, name, description, module_type, duration_minutes
        )
      ''')
      .eq('induction_id', inductionId)
      .order('sequence_order');

  // Calculate overall progress
  final totalModules = (progress as List).length;
  final completedModules = progress.where((p) => p['status'] == 'completed').length;
  final progressPercent = totalModules > 0 ? (completedModules / totalModules * 100).round() : 0;

  return ApiResponse.ok({
    'induction': induction,
    'progress': progress,
    'summary': {
      'total_modules': totalModules,
      'completed_modules': completedModules,
      'progress_percent': progressPercent,
    },
  }).toResponse();
}

/// POST /v1/train/induction/:id/record
///
/// Trainer or coordinator marks induction as complete.
/// Body: { esig: { reauth_session_id, meaning }, notes? }
Future<Response> inductionRecordCompleteHandler(Request req) async {
  final inductionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (inductionId == null || inductionId.isEmpty) {
    throw ValidationException({'id': 'Induction ID is required'});
  }

  // Get induction
  final induction = await supabase
      .from('employee_induction')
      .select('id, employee_id, trainer_id, status, organization_id')
      .eq('id', inductionId)
      .maybeSingle();

  if (induction == null) {
    throw NotFoundException('Induction not found');
  }

  // Check permission - must be trainer or coordinator
  final isTrainer = induction['trainer_id'] == auth.employeeId;
  final isCoordinator = auth.hasPermission(Permissions.manageTraining);

  if (!isTrainer && !isCoordinator) {
    throw PermissionDeniedException('Only the assigned trainer or coordinator can record completion');
  }

  if (induction['status'] == 'completed') {
    throw ConflictException('Induction is already completed');
  }

  // Validate e-signature
  final esig = body['esig'] as Map<String, dynamic>?;
  if (esig == null) {
    throw ValidationException({'esig': 'E-signature is required for completion'});
  }

  final esigService = EsigService(supabase);
  final esigId = await esigService.createEsignature(
    employeeId: auth.employeeId,
    meaning: esig['meaning'] as String? ?? 'INDUCTION_COMPLETE',
    entityType: 'employee_induction',
    entityId: inductionId,
    reauthSessionId: esig['reauth_session_id'] as String,
  );

  final notes = body['notes'] as String?;
  final completedAt = DateTime.now().toUtc();

  // Update induction
  await supabase
      .from('employee_induction')
      .update({
        'status': 'completed',
        'completed_at': completedAt.toIso8601String(),
        'completed_by': auth.employeeId,
        'completion_esignature_id': esigId,
        'completion_notes': notes,
      })
      .eq('id', inductionId);

  // Update employee induction_completed flag
  await supabase
      .from('employees')
      .update({
        'induction_completed': true,
        'induction_completed_at': completedAt.toIso8601String(),
      })
      .eq('id', induction['employee_id']);

  // Create training record
  final trainingRecord = await supabase
      .from('training_records')
      .insert({
        'employee_id': induction['employee_id'],
        'organization_id': induction['organization_id'],
        'training_type': 'induction',
        'induction_id': inductionId,
        'completed_at': completedAt.toIso8601String(),
        'overall_status': 'completed',
        'recorded_by': auth.employeeId,
        'esignature_id': esigId,
      })
      .select('id')
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'employee_induction',
    aggregateId: inductionId,
    eventType: 'induction.completed',
    payload: {
      'employee_id': induction['employee_id'],
      'completed_by': auth.employeeId,
      'training_record_id': trainingRecord['id'],
    },
  );

  return ApiResponse.ok({
    'message': 'Induction completed successfully',
    'training_record_id': trainingRecord['id'],
  }).toResponse();
}
