import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/periodic-reviews
///
/// Lists periodic reviews with filters.
Future<Response> periodicReviewsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.viewDocuments)) {
    throw PermissionDeniedException('You do not have permission to view periodic reviews');
  }

  final params = req.url.queryParameters;
  final status = params['status'];
  final entityType = params['entity_type'];
  final dueWithin = params['due_within_days'];

  var query = supabase
      .from('periodic_review_schedules')
      .select('''
        id, entity_type, entity_id, entity_name, review_interval_months, 
        last_reviewed_at, next_review_due, status, created_at
      ''');

  if (status != null) query = query.eq('status', status);
  if (entityType != null) query = query.eq('entity_type', entityType);
  
  if (dueWithin != null) {
    final days = int.tryParse(dueWithin) ?? 30;
    final cutoff = DateTime.now().add(Duration(days: days)).toIso8601String();
    query = query.lte('next_review_due', cutoff);
  }

  final reviews = await query.order('next_review_due', ascending: true);

  return ApiResponse.ok(reviews).toResponse();
}

/// GET /v1/periodic-reviews/:id
Future<Response> periodicReviewGetHandler(Request req) async {
  final reviewId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (reviewId == null || reviewId.isEmpty) {
    throw ValidationException({'id': 'Review ID is required'});
  }

  if (!auth.hasPermission(Permissions.viewDocuments)) {
    throw PermissionDeniedException('You do not have permission to view periodic reviews');
  }

  final review = await supabase
      .from('periodic_review_schedules')
      .select('''
        *,
        periodic_review_log(
          id, reviewed_at, reviewed_by, outcome, notes,
          reviewer:employees!periodic_review_log_reviewed_by_fkey(first_name, last_name)
        )
      ''')
      .eq('id', reviewId)
      .maybeSingle();

  if (review == null) {
    throw NotFoundException('Periodic review not found');
  }

  return ApiResponse.ok(review).toResponse();
}

/// POST /v1/periodic-reviews
///
/// Creates a periodic review schedule.
/// Body: { entity_type, entity_id, entity_name, review_interval_months?, reviewer_role_id? }
Future<Response> periodicReviewCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.createDocuments)) {
    throw PermissionDeniedException('You do not have permission to create periodic reviews');
  }

  final entityType = requireString(body, 'entity_type');
  final entityId = requireUuid(body, 'entity_id');
  final entityName = requireString(body, 'entity_name');
  final reviewIntervalMonths = body['review_interval_months'] as int? ?? 12;
  final reviewerRoleId = body['reviewer_role_id'] as String?;

  // Validate entity_type
  final validEntityTypes = [
    'course', 'document', 'gtp', 'training_matrix',
    'curriculum', 'assessment_question_paper', 'job_responsibility'
  ];
  if (!validEntityTypes.contains(entityType)) {
    throw ValidationException({
      'entity_type': 'Must be one of: ${validEntityTypes.join(", ")}',
    });
  }

  // Check not already scheduled
  final existing = await supabase
      .from('periodic_review_schedules')
      .select('id')
      .eq('entity_type', entityType)
      .eq('entity_id', entityId)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Periodic review already scheduled for this entity');
  }

  final now = DateTime.now();
  final nextReviewDue = now.add(Duration(days: reviewIntervalMonths * 30));

  final review = await supabase
      .from('periodic_review_schedules')
      .insert({
        'entity_type': entityType,
        'entity_id': entityId,
        'entity_name': entityName,
        'review_interval_months': reviewIntervalMonths,
        'next_review_due': nextReviewDue.toUtc().toIso8601String(),
        'reviewer_role_id': reviewerRoleId,
        'status': 'PENDING',
        'created_by': auth.employeeId,
        'created_at': now.toUtc().toIso8601String(),
      })
      .select()
      .single();

  return ApiResponse.created(review).toResponse();
}

/// POST /v1/periodic-reviews/:id/complete [esig]
///
/// Completes a periodic review.
/// Body: { outcome, notes? }
Future<Response> periodicReviewCompleteHandler(Request req) async {
  final reviewId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (reviewId == null || reviewId.isEmpty) {
    throw ValidationException({'id': 'Review ID is required'});
  }

  if (esig == null) {
    throw EsigRequiredException('E-signature required to complete periodic review');
  }

  if (!auth.hasPermission(Permissions.approveDocuments)) {
    throw PermissionDeniedException('You do not have permission to complete periodic reviews');
  }

  final outcome = requireString(body, 'outcome');

  // Validate outcome
  final validOutcomes = ['NO_CHANGE', 'MINOR_UPDATE', 'MAJOR_REVISION', 'WITHDRAWN', 'DEFERRED'];
  if (!validOutcomes.contains(outcome)) {
    throw ValidationException({
      'outcome': 'Must be one of: ${validOutcomes.join(", ")}',
    });
  }

  final existing = await supabase
      .from('periodic_review_schedules')
      .select('id, status, review_interval_months')
      .eq('id', reviewId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Periodic review not found');
  }

  if (existing['status'] != 'PENDING' && existing['status'] != 'OVERDUE' && existing['status'] != 'IN_REVIEW') {
    throw ConflictException('Review is not pending completion');
  }

  final now = DateTime.now();
  final nowStr = now.toUtc().toIso8601String();

  // Create e-signature
  final esigService = EsigService(supabase);
  final esigId = await esigService.createEsignature(
    employeeId: auth.employeeId,
    meaning: esig.meaning,
    entityType: 'periodic_review_schedule',
    entityId: reviewId,
    reauthSessionId: esig.reauthSessionId,
  );

  // Add log record (immutable)
  await supabase.from('periodic_review_log').insert({
    'schedule_id': reviewId,
    'reviewed_at': nowStr,
    'reviewed_by': auth.employeeId,
    'outcome': outcome,
    'notes': body['notes'],
    'esignature_id': esigId,
  });

  // Calculate next review date
  final intervalMonths = existing['review_interval_months'] as int;
  final nextReviewDue = now.add(Duration(days: intervalMonths * 30));

  // Update review schedule
  await supabase
      .from('periodic_review_schedules')
      .update({
        'last_reviewed_at': nowStr,
        'last_reviewed_by': auth.employeeId,
        'last_review_outcome': outcome,
        'last_review_notes': body['notes'],
        'next_review_due': nextReviewDue.toUtc().toIso8601String(),
        'status': 'COMPLETED',
        'updated_at': nowStr,
      })
      .eq('id', reviewId);

  return ApiResponse.ok({
    'message': 'Periodic review completed',
    'next_review_due': nextReviewDue.toUtc().toIso8601String(),
    'esignature_id': esigId,
  }).toResponse();
}

/// PATCH /v1/periodic-reviews/:id
///
/// Updates a periodic review schedule.
Future<Response> periodicReviewUpdateHandler(Request req) async {
  final reviewId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (reviewId == null || reviewId.isEmpty) {
    throw ValidationException({'id': 'Review ID is required'});
  }

  if (!auth.hasPermission(Permissions.editDocuments)) {
    throw PermissionDeniedException('You do not have permission to update periodic reviews');
  }

  final updateData = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  final allowedFields = [
    'review_interval_months', 'next_review_due', 'status',
    'reviewer_role_id', 'assigned_reviewer_id', 'entity_name'
  ];
  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('periodic_review_schedules')
      .update(updateData)
      .eq('id', reviewId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/periodic-reviews/:id
Future<Response> periodicReviewDeleteHandler(Request req) async {
  final reviewId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (reviewId == null || reviewId.isEmpty) {
    throw ValidationException({'id': 'Review ID is required'});
  }

  if (!auth.hasPermission(Permissions.deleteDocuments)) {
    throw PermissionDeniedException('You do not have permission to delete periodic reviews');
  }

  // Note: periodic_review_log is immutable, CASCADE will handle it
  await supabase.from('periodic_review_schedules').delete().eq('id', reviewId);

  return ApiResponse.noContent().toResponse();
}
