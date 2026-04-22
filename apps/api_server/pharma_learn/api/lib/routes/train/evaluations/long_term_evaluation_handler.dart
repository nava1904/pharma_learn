import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/batches/:id/long-term-evaluation
///
/// Supervisor submits long-term evaluation (3-6 months post-training).
/// Body: { evaluation_template_id, employee_id, responses: [], observation_period_months, overall_rating? }
Future<Response> longTermEvaluationCreateHandler(Request req) async {
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
  final observationPeriodRaw = body['observation_period_months'];
  if (observationPeriodRaw == null) {
    throw ValidationException({'observation_period_months': 'Required field'});
  }
  final observationPeriodMonths = (observationPeriodRaw as num).toInt();
  final overallRating = body['overall_rating'] as num?;
  final behaviorChangeObserved = body['behavior_change_observed'] as bool? ?? false;
  final skillsApplied = body['skills_applied'] as List? ?? [];
  final comments = body['comments'] as String?;

  // Validate observation period (typically 3-6 months)
  if (observationPeriodMonths < 1 || observationPeriodMonths > 12) {
    throw ValidationException({
      'observation_period_months': 'Must be between 1 and 12 months',
    });
  }

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
        id,
        training_sessions!inner(id, batch_id)
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
      .eq('evaluation_type', 'long_term')
      .maybeSingle();

  if (template == null || template['is_active'] != true) {
    throw NotFoundException('Long-term evaluation template not found or inactive');
  }

  // Insert evaluation
  final evaluation = await supabase
      .from('long_term_evaluations')
      .insert({
        'batch_id': batchId,
        'employee_id': employeeId,
        'evaluator_id': auth.employeeId,
        'evaluation_template_id': evaluationTemplateId,
        'responses': responses,
        'observation_period_months': observationPeriodMonths,
        'overall_rating': overallRating,
        'behavior_change_observed': behaviorChangeObserved,
        'skills_applied': skillsApplied,
        'comments': comments,
        'evaluated_at': DateTime.now().toUtc().toIso8601String(),
        'organization_id': auth.orgId,
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'long_term_evaluation',
    aggregateId: evaluation['id'] as String,
    eventType: 'long_term_evaluation.submitted',
    payload: {
      'batch_id': batchId,
      'employee_id': employeeId,
      'evaluator_id': auth.employeeId,
      'observation_period_months': observationPeriodMonths,
    },
  );

  return ApiResponse.created(evaluation).toResponse();
}

/// GET /v1/train/batches/:id/long-term-evaluation
///
/// Lists all long-term evaluations for a batch.
Future<Response> longTermEvaluationListHandler(Request req) async {
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
      .from('long_term_evaluations')
      .select('''
        id, overall_rating, observation_period_months, 
        behavior_change_observed, skills_applied, comments, evaluated_at,
        employee:employees!long_term_evaluations_employee_id_fkey(
          id, first_name, last_name, department_id
        ),
        evaluator:employees!long_term_evaluations_evaluator_id_fkey(
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

  final behaviorChangeCount = evaluations
      .where((e) => e['behavior_change_observed'] == true)
      .length;

  final summary = {
    'total_evaluations': evaluations.length,
    'average_rating': ratings.isNotEmpty 
        ? ratings.reduce((a, b) => a + b) / ratings.length 
        : null,
    'behavior_change_percentage': evaluations.isNotEmpty 
        ? (behaviorChangeCount / evaluations.length * 100).round()
        : null,
  };

  return ApiResponse.ok({
    'batch_id': batchId,
    'summary': summary,
    'evaluations': evaluations,
  }).toResponse();
}

/// GET /v1/train/batches/:id/long-term-evaluation/:employeeId
///
/// Gets long-term evaluation detail for a specific employee.
Future<Response> longTermEvaluationDetailHandler(Request req) async {
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

  // Check access
  final isOwnEvaluation = employeeId == auth.employeeId;
  if (!isOwnEvaluation && !auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to view this evaluation');
  }

  final evaluations = await supabase
      .from('long_term_evaluations')
      .select('''
        id, responses, overall_rating, observation_period_months,
        behavior_change_observed, skills_applied, comments, evaluated_at,
        employee:employees!long_term_evaluations_employee_id_fkey(
          id, first_name, last_name, email
        ),
        evaluator:employees!long_term_evaluations_evaluator_id_fkey(
          id, first_name, last_name
        ),
        evaluation_template:evaluation_templates(
          id, name, questions, rating_scale
        )
      ''')
      .eq('batch_id', batchId)
      .eq('employee_id', employeeId)
      .order('evaluated_at', ascending: false);

  return ApiResponse.ok({
    'batch_id': batchId,
    'employee_id': employeeId,
    'evaluations': evaluations,
    'total_evaluations': (evaluations as List).length,
  }).toResponse();
}
