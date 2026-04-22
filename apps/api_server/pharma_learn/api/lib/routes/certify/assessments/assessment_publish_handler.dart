import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/certify/assessments/:id/publish-results
///
/// Publishes assessment results to the employee.
/// Triggers notification and updates training record status.
/// Requires e-signature for compliance audit trail.
///
/// Body:
/// ```json
/// {
///   "esignature": {
///     "reauth_session_id": "uuid",
///     "meaning": "APPROVE"
///   },
///   "comments": "Optional reviewer comments"
/// }
/// ```
Future<Response> assessmentPublishResultsHandler(Request req) async {
  final attemptId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final esigData = body['esignature'] as Map<String, dynamic>?;
  final comments = body['comments'] as String?;

  if (esigData == null || esigData['reauth_session_id'] == null) {
    throw ValidationException({'esignature': 'E-signature is required to publish results'});
  }

  // Verify user has permission to publish assessment results
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageAssessments,
    jwtPermissions: auth.permissions,
  );

  // Get the assessment attempt with results
  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        id, status, employee_id, training_record_id,
        question_paper_id,
        assessment_results!inner(
          id, total_score, percentage, passed, published
        )
      ''')
      .eq('id', attemptId)
      .maybeSingle();

  if (attempt == null) {
    throw NotFoundException('Assessment attempt not found');
  }

  final result = attempt['assessment_results'] as Map<String, dynamic>?;
  if (result == null) {
    throw ValidationException({'attempt': 'Assessment has not been graded yet'});
  }

  if (result['published'] == true) {
    throw ConflictException('Results have already been published');
  }

  // Create e-signature
  final esig = await supabase.rpc(
    'create_esignature_from_reauth',
    params: {
      'p_reauth_session_id': esigData['reauth_session_id'],
      'p_employee_id': auth.employeeId,
      'p_meaning': 'APPROVE',
      'p_context_type': 'assessment_result_publish',
      'p_context_id': attemptId,
    },
  ) as Map<String, dynamic>;

  final now = DateTime.now().toUtc().toIso8601String();

  // Update assessment result to published
  await supabase.from('assessment_results').update({
    'published': true,
    'published_at': now,
    'published_by': auth.employeeId,
    'publish_comments': comments,
    'publish_esignature_id': esig['esignature_id'],
  }).eq('id', result['id']);

  // Update attempt status
  await supabase.from('assessment_attempts').update({
    'status': 'results_published',
  }).eq('id', attemptId);

  // Update training record based on pass/fail
  final passed = result['passed'] as bool;
  if (attempt['training_record_id'] != null) {
    await supabase.from('training_records').update({
      'status': passed ? 'completed' : 'failed',
      'completed_at': passed ? now : null,
      'assessment_passed': passed,
      'assessment_score': result['percentage'],
    }).eq('id', attempt['training_record_id']);
  }

  // Publish event for certificate generation (if passed) or remediation
  final eventType = passed ? 'assessment.passed' : 'assessment.failed';
  await supabase.rpc('publish_event', params: {
    'p_aggregate_type': 'assessment',
    'p_aggregate_id': attemptId,
    'p_event_type': eventType,
    'p_payload': {
      'attempt_id': attemptId,
      'employee_id': attempt['employee_id'],
      'training_record_id': attempt['training_record_id'],
      'score': result['percentage'],
      'passed': passed,
    },
  });

  // Send notification to employee
  await supabase.functions.invoke('send-notification', body: {
    'type': 'assessment_results_published',
    'recipient_id': attempt['employee_id'],
    'data': {
      'attempt_id': attemptId,
      'passed': passed,
      'score': result['percentage'],
    },
  });

  return ApiResponse.ok({
    'attempt_id': attemptId,
    'status': 'results_published',
    'passed': passed,
    'score': result['percentage'],
    'published_at': now,
    'esignature_id': esig['esignature_id'],
  }).toResponse();
}
