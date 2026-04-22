import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/batches/:id/short-term-evaluation
///
/// Supervisor submits short-term evaluation for an employee after training.
/// Body: { evaluation_template_id, employee_id, responses: [], overall_rating }
Future<Response> shortTermEvaluationCreateHandler(Request req) async {
  final batchId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (batchId == null || batchId.isEmpty) {
    throw ValidationException({'id': 'Batch ID is required'});
  }

  // Verify user is supervisor or coordinator
  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('Only supervisors and coordinators can submit evaluations');
  }

  final evaluationTemplateId = requireUuid(body, 'evaluation_template_id');
  final employeeId = requireUuid(body, 'employee_id');
  final responses = body['responses'] as List<dynamic>?;
  if (responses == null || responses.isEmpty) {
    throw ValidationException({'responses': 'At least one response is required'});
  }
  final overallRating = body['overall_rating'] as num?;
  final comments = body['comments'] as String?;

  // Verify batch exists
  final batch = await supabase
      .from('training_batches')
      .select('id, organization_id, status')
      .eq('id', batchId)
      .maybeSingle();

  if (batch == null) {
    throw NotFoundException('Training batch not found');
  }

  // Verify employee attended this batch
  final attendance = await supabase
      .from('session_attendance')
      .select('''
        id, status,
        training_sessions!inner(
          id, batch_id
        )
      ''')
      .eq('training_sessions.batch_id', batchId)
      .eq('employee_id', employeeId)
      .limit(1);

  if ((attendance as List).isEmpty) {
    throw ValidationException({
      'employee_id': 'Employee did not attend this training batch',
    });
  }

  // Check evaluation template exists
  final template = await supabase
      .from('evaluation_templates')
      .select('id, evaluation_type, is_active')
      .eq('id', evaluationTemplateId)
      .eq('evaluation_type', 'short_term')
      .maybeSingle();

  if (template == null || template['is_active'] != true) {
    throw NotFoundException('Short-term evaluation template not found or inactive');
  }

  // Check if evaluation already exists
  final existing = await supabase
      .from('short_term_evaluations')
      .select('id')
      .eq('batch_id', batchId)
      .eq('employee_id', employeeId)
      .eq('evaluator_id', auth.employeeId)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('You have already submitted an evaluation for this employee');
  }

  // Insert evaluation
  final evaluation = await supabase
      .from('short_term_evaluations')
      .insert({
        'batch_id': batchId,
        'employee_id': employeeId,
        'evaluator_id': auth.employeeId,
        'evaluation_template_id': evaluationTemplateId,
        'responses': responses,
        'overall_rating': overallRating,
        'comments': comments,
        'evaluated_at': DateTime.now().toUtc().toIso8601String(),
        'organization_id': auth.orgId,
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'short_term_evaluation',
    aggregateId: evaluation['id'] as String,
    eventType: 'short_term_evaluation.submitted',
    payload: {
      'batch_id': batchId,
      'employee_id': employeeId,
      'evaluator_id': auth.employeeId,
    },
  );

  return ApiResponse.created(evaluation).toResponse();
}

/// GET /v1/train/batches/:id/short-term-evaluation
///
/// Lists all short-term evaluations for a batch.
Future<Response> shortTermEvaluationListHandler(Request req) async {
  final batchId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (batchId == null || batchId.isEmpty) {
    throw ValidationException({'id': 'Batch ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to view evaluations');
  }

  final evaluations = await supabase
      .from('short_term_evaluations')
      .select('''
        id, overall_rating, comments, evaluated_at,
        employee:employees!short_term_evaluations_employee_id_fkey(
          id, first_name, last_name, department_id
        ),
        evaluator:employees!short_term_evaluations_evaluator_id_fkey(
          id, first_name, last_name
        ),
        evaluation_template:evaluation_templates(
          id, name
        )
      ''')
      .eq('batch_id', batchId)
      .order('evaluated_at', ascending: false);

  // Calculate summary statistics
  final ratings = (evaluations as List)
      .where((e) => e['overall_rating'] != null)
      .map((e) => (e['overall_rating'] as num).toDouble())
      .toList();

  final summary = {
    'total_evaluations': evaluations.length,
    'average_rating': ratings.isNotEmpty 
        ? ratings.reduce((a, b) => a + b) / ratings.length 
        : null,
    'min_rating': ratings.isNotEmpty 
        ? ratings.reduce((a, b) => a < b ? a : b) 
        : null,
    'max_rating': ratings.isNotEmpty 
        ? ratings.reduce((a, b) => a > b ? a : b) 
        : null,
  };

  return ApiResponse.ok({
    'batch_id': batchId,
    'summary': summary,
    'evaluations': evaluations,
  }).toResponse();
}

/// GET /v1/train/batches/:id/short-term-evaluation/:employeeId
///
/// Gets short-term evaluation detail for a specific employee.
Future<Response> shortTermEvaluationDetailHandler(Request req) async {
  final batchId = req.rawPathParameters[#id];
  final employeeId = req.rawPathParameters[#employeeId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (batchId == null || batchId.isEmpty) {
    throw ValidationException({'id': 'Batch ID is required'});
  }
  if (employeeId == null || employeeId.isEmpty) {
    throw ValidationException({'employeeId': 'Employee ID is required'});
  }

  // Check access - either own evaluation or supervisor/coordinator
  final isOwnEvaluation = employeeId == auth.employeeId;
  if (!isOwnEvaluation && !auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to view this evaluation');
  }

  final evaluation = await supabase
      .from('short_term_evaluations')
      .select('''
        id, responses, overall_rating, comments, evaluated_at,
        employee:employees!short_term_evaluations_employee_id_fkey(
          id, first_name, last_name, email
        ),
        evaluator:employees!short_term_evaluations_evaluator_id_fkey(
          id, first_name, last_name
        ),
        evaluation_template:evaluation_templates(
          id, name, questions, rating_scale
        )
      ''')
      .eq('batch_id', batchId)
      .eq('employee_id', employeeId)
      .maybeSingle();

  if (evaluation == null) {
    throw NotFoundException('Short-term evaluation not found');
  }

  return ApiResponse.ok(evaluation).toResponse();
}
