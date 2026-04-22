import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/certify/assessments/:id/submit
/// 
/// Submits assessment for grading. Auto-grades MCQ/T-F/matching.
/// Creates certificate on pass, remedial training on final fail.
Future<Response> assessmentSubmitHandler(Request req) async {
  final attemptId = req.rawPathParameters[#id]!;
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Get attempt with question paper details
  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        id, employee_id, status, attempt_number, employee_assignment_id,
        question_paper:question_papers(
          id, pass_mark, total_marks,
          questions:question_paper_questions(
            question:questions(
              id, question_type, marks,
              options:question_options(id, is_correct)
            )
          )
        )
      ''')
      .eq('id', attemptId)
      .maybeSingle();

  if (attempt == null) {
    throw NotFoundException('Assessment attempt not found');
  }

  if (attempt['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('Not your assessment');
  }

  if (attempt['status'] != 'in_progress') {
    throw ConflictException('Assessment is not in progress');
  }

  // Get all responses
  final responses = await supabase
      .from('assessment_responses')
      .select('*')
      .eq('attempt_id', attemptId);

  final responseMap = <String, Map<String, dynamic>>{};
  for (final r in responses) {
    responseMap[r['question_id'] as String] = r;
  }

  // Auto-grade
  var totalMarks = 0.0;
  var obtainedMarks = 0.0;
  var manualReviewNeeded = false;

  final questionPaper = attempt['question_paper'] as Map<String, dynamic>;
  final questions = questionPaper['questions'] as List? ?? [];

  for (final q in questions) {
    final question = q['question'] as Map<String, dynamic>;
    final qId = question['id'] as String;
    final qType = question['question_type'] as String;
    final qMarks = (question['marks'] as num?)?.toDouble() ?? 1.0;
    totalMarks += qMarks;

    final response = responseMap[qId];
    if (response == null) continue;

    if (['mcq', 'true_false', 'matching'].contains(qType)) {
      // Auto-grade objective questions
      final options = question['options'] as List? ?? [];
      final correctIds = options
          .where((o) => o['is_correct'] == true)
          .map((o) => o['id'] as String)
          .toSet();
      
      final selectedIds = (response['selected_option_ids'] as List?)
          ?.map((e) => e.toString())
          .toSet() ?? <String>{};
      
      final isCorrect = correctIds.length == selectedIds.length &&
          correctIds.every(selectedIds.contains);
      
      if (isCorrect) {
        obtainedMarks += qMarks;
      }

      await supabase.from('assessment_responses').update({
        'marks_awarded': isCorrect ? qMarks : 0,
        'is_correct': isCorrect,
      }).eq('id', response['id']);
    } else {
      // Essay/short answer needs manual review
      manualReviewNeeded = true;
    }
  }

  final percentage = totalMarks > 0 ? (obtainedMarks / totalMarks) * 100 : 0.0;
  final passMark = (questionPaper['pass_mark'] as num?)?.toDouble() ?? 70.0;
  final isPassed = !manualReviewNeeded && percentage >= passMark;
  final now = DateTime.now().toUtc();

  // Update attempt
  await supabase.from('assessment_attempts').update({
    'status': manualReviewNeeded ? 'pending_review' : 'graded',
    'total_marks': totalMarks,
    'obtained_marks': obtainedMarks,
    'percentage': percentage,
    'is_passed': isPassed,
    'submitted_at': now.toIso8601String(),
  }).eq('id', attemptId);

  // If passed, update obligation and generate certificate
  if (isPassed) {
    final obligationId = attempt['employee_assignment_id'] as String?;
    if (obligationId != null) {
      await supabase.from('employee_assignments').update({
        'status': 'completed',
        'completed_at': now.toIso8601String(),
      }).eq('id', obligationId);
    }

    // Publish event for certificate generation
    await EventPublisher.publish(
      supabase,
      eventType: 'assessment.passed',
      aggregateType: 'assessment_attempt',
      aggregateId: attemptId,
      orgId: auth.orgId,
      payload: {
        'employee_id': auth.employeeId,
        'percentage': percentage,
        'obligation_id': obligationId,
      },
    );
  } else if (!manualReviewNeeded) {
    // Check if max attempts reached for remedial training
    final obligationId = attempt['employee_assignment_id'] as String?;
    if (obligationId != null) {
      final obligation = await supabase
          .from('employee_assignments')
          .select('id, training_assignments!inner(courses!inner(max_attempts))')
          .eq('id', obligationId)
          .maybeSingle();
      
      final maxAttempts = obligation?['training_assignments']?['courses']?['max_attempts'] as int? ?? 3;
      final attemptNumber = attempt['attempt_number'] as int? ?? 1;
      
      if (attemptNumber >= maxAttempts) {
        // Create remedial training
        await supabase.from('training_remedials').insert({
          'employee_id': auth.employeeId,
          'original_assignment_id': obligationId,
          'reason': 'Failed assessment after $maxAttempts attempts',
          'status': 'pending',
          'organization_id': auth.orgId,
        });
      }
    }

    await EventPublisher.publish(
      supabase,
      eventType: 'assessment.failed',
      aggregateType: 'assessment_attempt',
      aggregateId: attemptId,
      orgId: auth.orgId,
      payload: {
        'employee_id': auth.employeeId,
        'percentage': percentage,
        'attempt_number': attempt['attempt_number'],
      },
    );
  }

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'assessment_attempt',
    'entity_id': attemptId,
    'action': 'ASSESSMENT_SUBMITTED',
    'event_category': 'CERTIFY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': {
      'percentage': percentage,
      'is_passed': isPassed,
      'manual_review_needed': manualReviewNeeded,
    },
  });

  return ApiResponse.ok({
    'attempt_id': attemptId,
    'status': manualReviewNeeded ? 'pending_review' : 'graded',
    'total_marks': totalMarks,
    'obtained_marks': obtainedMarks,
    'percentage': percentage,
    'is_passed': isPassed,
    'requires_manual_review': manualReviewNeeded,
  }).toResponse();
}
