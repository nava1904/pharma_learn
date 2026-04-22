import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/certify/assessments/:id - Get assessment by ID
Future<Response> assessmentGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('assessments')
      .select('''
        *,
        course:courses(id, code, name),
        question_paper:question_papers(id, name, passing_score),
        employee:employees(id, employee_number, full_name)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Assessment not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/certify/assessments/:id/start - Start assessment
Future<Response> assessmentStartHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final existing = await supabase
      .from('assessments')
      .select('id, status, employee_id')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Assessment not found').toResponse();
  }

  if (existing['employee_id'] != auth.employeeId) {
    return ErrorResponse.permissionDenied('Cannot start another user\'s assessment').toResponse();
  }

  if (existing['status'] != 'pending') {
    return ErrorResponse.conflict('Assessment is not in pending status').toResponse();
  }

  final result = await supabase
      .from('assessments')
      .update({
        'status': 'in_progress',
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'assessments',
    'entity_id': id,
    'action': 'START',
    'performed_by': auth.employeeId,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/certify/assessments/:id/submit - Submit assessment answers
Future<Response> assessmentSubmitHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final existing = await supabase
      .from('assessments')
      .select('id, status, employee_id, question_paper_id')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Assessment not found').toResponse();
  }

  if (existing['employee_id'] != auth.employeeId) {
    return ErrorResponse.permissionDenied('Cannot submit another user\'s assessment').toResponse();
  }

  if (existing['status'] != 'in_progress') {
    return ErrorResponse.conflict('Assessment is not in progress').toResponse();
  }

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;
  final answers = body['answers'] as List? ?? [];

  // Store answers
  for (final answer in answers) {
    await supabase.from('assessment_answers').upsert({
      'assessment_id': id,
      'question_id': answer['question_id'],
      'selected_option_id': answer['selected_option_id'],
      'text_answer': answer['text_answer'],
      'answered_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'assessment_id,question_id');
  }

  // Calculate score
  final questionPaper = await supabase
      .from('question_papers')
      .select('passing_score')
      .eq('id', existing['question_paper_id'])
      .single();

  final answerResults = await supabase
      .from('assessment_answers')
      .select('''
        id,
        question:questions(id, correct_option_id),
        selected_option_id
      ''')
      .eq('assessment_id', id);

  var correctCount = 0;
  var totalQuestions = 0;
  for (final ans in answerResults as List) {
    totalQuestions++;
    final question = ans['question'] as Map<String, dynamic>?;
    if (question != null && ans['selected_option_id'] == question['correct_option_id']) {
      correctCount++;
    }
  }

  final scorePercent = totalQuestions > 0 ? (correctCount / totalQuestions * 100).round() : 0;
  final passingScore = questionPaper['passing_score'] as int? ?? 70;
  final passed = scorePercent >= passingScore;

  final result = await supabase
      .from('assessments')
      .update({
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'score': scorePercent,
        'passed': passed,
        'correct_answers': correctCount,
        'total_questions': totalQuestions,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  // If failed, trigger remedial training
  if (!passed) {
    await OutboxService(supabase).publish(
      aggregateType: 'assessments',
      aggregateId: id,
      eventType: 'assessment.failed',
      payload: {
        'assessment_id': id,
        'employee_id': auth.employeeId,
        'score': scorePercent,
        'passing_score': passingScore,
      },
      orgId: auth.orgId,
    );
  }

  await supabase.from('audit_trails').insert({
    'entity_type': 'assessments',
    'entity_id': id,
    'action': 'SUBMIT',
    'performed_by': auth.employeeId,
    'changes': {'score': scorePercent, 'passed': passed},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/certify/assessments/:id/evaluate - Manual evaluation [esig]
Future<Response> assessmentEvaluateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required for manual evaluation').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'assessments.evaluate',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final errors = <String, String>{};
  if (body['score'] == null) {
    errors['score'] = 'score is required';
  }
  if (body['passed'] == null) {
    errors['passed'] = 'passed is required';
  }

  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'assessments',
    'entity_id': id,
    'meaning': 'EVALUATE_ASSESSMENT',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  final result = await supabase
      .from('assessments')
      .update({
        'status': 'evaluated',
        'score': body['score'],
        'passed': body['passed'],
        'evaluator_comments': body['comments'],
        'evaluated_at': DateTime.now().toUtc().toIso8601String(),
        'evaluated_by': auth.employeeId,
        'esignature_id': esigResult['id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'assessments',
    'entity_id': id,
    'action': 'EVALUATE',
    'performed_by': auth.employeeId,
    'changes': {'score': body['score'], 'passed': body['passed'], 'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}
