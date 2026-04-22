import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/sessions/:id/feedback
///
/// Trainee submits post-training feedback for a session.
/// Body: { feedback_template_id, responses: [{question_id, answer}] }
/// Guard: Employee must have attended the session (session_attendance.status = 'attended')
Future<Response> sessionFeedbackSubmitHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (sessionId == null || sessionId.isEmpty) {
    throw ValidationException({'id': 'Session ID is required'});
  }

  // Check employee attended this session
  final attendance = await supabase
      .from('session_attendance')
      .select('id, status')
      .eq('session_id', sessionId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (attendance == null) {
    throw PermissionDeniedException('You are not enrolled in this session');
  }

  if (attendance['status'] != 'attended' && attendance['status'] != 'completed') {
    throw ValidationException({
      'session': 'You must complete the session before submitting feedback',
    });
  }

  // Check if feedback already submitted
  final existingFeedback = await supabase
      .from('session_feedback')
      .select('id')
      .eq('session_id', sessionId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (existingFeedback != null) {
    throw ConflictException('You have already submitted feedback for this session');
  }

  final feedbackTemplateId = requireUuid(body, 'feedback_template_id');
  final responses = body['responses'] as List<dynamic>?;
  if (responses == null || responses.isEmpty) {
    throw ValidationException({'responses': 'At least one response is required'});
  }

  // Verify template exists and is active
  final template = await supabase
      .from('feedback_templates')
      .select('id, questions, is_active')
      .eq('id', feedbackTemplateId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (template == null || template['is_active'] != true) {
    throw NotFoundException('Feedback template not found or inactive');
  }

  // Validate responses match template questions
  final templateQuestions = template['questions'] as List;
  final requiredQuestionIds = templateQuestions
      .where((q) => q['required'] == true)
      .map((q) => q['id'])
      .toSet();

  final submittedQuestionIds = responses.map((r) => r['question_id']).toSet();

  for (final requiredId in requiredQuestionIds) {
    if (!submittedQuestionIds.contains(requiredId)) {
      throw ValidationException({
        'responses': 'Missing required question: $requiredId',
      });
    }
  }

  // Insert feedback
  final feedback = await supabase
      .from('session_feedback')
      .insert({
        'session_id': sessionId,
        'employee_id': auth.employeeId,
        'feedback_template_id': feedbackTemplateId,
        'responses': responses,
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'session_feedback',
    aggregateId: feedback['id'] as String,
    eventType: 'session_feedback.submitted',
    payload: {
      'session_id': sessionId,
      'employee_id': auth.employeeId,
    },
  );

  return ApiResponse.created(feedback).toResponse();
}

/// GET /v1/train/sessions/:id/feedback
///
/// Coordinator views aggregated feedback responses for a session.
/// Returns per-question statistics and individual responses.
Future<Response> sessionFeedbackListHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (sessionId == null || sessionId.isEmpty) {
    throw ValidationException({'id': 'Session ID is required'});
  }

  final includeIndividual = req.url.queryParameters['include_individual'] == 'true';

  // Verify session exists and user has access
  final session = await supabase
      .from('training_sessions')
      .select('''
        id, session_date,
        training_schedules!inner(
          id, organization_id
        )
      ''')
      .eq('id', sessionId)
      .maybeSingle();

  if (session == null) {
    throw NotFoundException('Session not found');
  }

  final scheduleOrgId = session['training_schedules']?['organization_id'];
  if (scheduleOrgId != auth.orgId && !auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have access to this session feedback');
  }

  // Get all feedback for this session
  final feedbacks = await supabase
      .from('session_feedback')
      .select('''
        id, responses, submitted_at,
        feedback_template:feedback_templates(
          id, name, questions
        ),
        employee:employees(
          id, first_name, last_name
        )
      ''')
      .eq('session_id', sessionId)
      .order('submitted_at', ascending: false);

  // Aggregate statistics
  final stats = <String, Map<String, dynamic>>{};
  int totalResponses = 0;

  for (final feedback in feedbacks as List) {
    totalResponses++;
    final responses = feedback['responses'] as List? ?? [];
    final template = feedback['feedback_template'] as Map<String, dynamic>?;
    final questions = template?['questions'] as List? ?? [];

    for (final response in responses) {
      final questionId = response['question_id'] as String;
      final answer = response['answer'];

      // Find question details
      final question = questions.firstWhere(
        (q) => q['id'] == questionId,
        orElse: () => {'text': 'Unknown', 'type': 'unknown'},
      );

      if (!stats.containsKey(questionId)) {
        stats[questionId] = {
          'question_id': questionId,
          'question_text': question['text'],
          'question_type': question['type'],
          'responses': <dynamic>[],
          'count': 0,
        };
      }

      stats[questionId]!['responses'].add(answer);
      stats[questionId]!['count'] = (stats[questionId]!['count'] as int) + 1;
    }
  }

  // Calculate averages for rating questions
  for (final stat in stats.values) {
    if (stat['question_type'] == 'rating' || stat['question_type'] == 'scale') {
      final numericResponses = (stat['responses'] as List)
          .whereType<num>()
          .toList();
      if (numericResponses.isNotEmpty) {
        stat['average'] = numericResponses.reduce((a, b) => a + b) / numericResponses.length;
        stat['min'] = numericResponses.reduce((a, b) => a < b ? a : b);
        stat['max'] = numericResponses.reduce((a, b) => a > b ? a : b);
      }
    } else if (stat['question_type'] == 'single_choice' || stat['question_type'] == 'multiple_choice') {
      // Count option selections
      final optionCounts = <String, int>{};
      for (final response in stat['responses'] as List) {
        if (response is String) {
          optionCounts[response] = (optionCounts[response] ?? 0) + 1;
        } else if (response is List) {
          for (final option in response) {
            optionCounts[option.toString()] = (optionCounts[option.toString()] ?? 0) + 1;
          }
        }
      }
      stat['option_counts'] = optionCounts;
    }

    // Remove raw responses unless requested
    if (!includeIndividual) {
      stat.remove('responses');
    }
  }

  final result = <String, dynamic>{
    'session_id': sessionId,
    'total_responses': totalResponses,
    'question_statistics': stats.values.toList(),
  };

  if (includeIndividual) {
    result['individual_responses'] = feedbacks;
  }

  return ApiResponse.ok(result).toResponse();
}

/// GET /v1/train/sessions/:id/feedback/my
///
/// Employee views their own submitted feedback for a session.
Future<Response> sessionFeedbackMyHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (sessionId == null || sessionId.isEmpty) {
    throw ValidationException({'id': 'Session ID is required'});
  }

  final feedback = await supabase
      .from('session_feedback')
      .select('''
        id, responses, submitted_at,
        feedback_template:feedback_templates(
          id, name, questions
        )
      ''')
      .eq('session_id', sessionId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (feedback == null) {
    return ApiResponse.ok({
      'submitted': false,
      'feedback': null,
    }).toResponse();
  }

  return ApiResponse.ok({
    'submitted': true,
    'feedback': feedback,
  }).toResponse();
}
