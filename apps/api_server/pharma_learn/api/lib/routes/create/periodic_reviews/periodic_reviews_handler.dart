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
      .from('periodic_reviews')
      .select('''
        id, entity_type, entity_id, review_cycle_months, last_review_date, 
        next_review_date, status, created_at
      ''');

  if (status != null) query = query.eq('status', status);
  if (entityType != null) query = query.eq('entity_type', entityType);
  
  if (dueWithin != null) {
    final days = int.tryParse(dueWithin) ?? 30;
    final cutoff = DateTime.now().add(Duration(days: days)).toIso8601String().split('T')[0];
    query = query.lte('next_review_date', cutoff);
  }

  final reviews = await query.order('next_review_date', ascending: true);

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
      .from('periodic_reviews')
      .select('''
        *,
        periodic_review_history(
          id, review_date, reviewed_by, outcome, comments,
          employees!reviewed_by(first_name, last_name)
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
/// Body: { entity_type, entity_id, review_cycle_months, first_review_date? }
Future<Response> periodicReviewCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.createDocuments)) {
    throw PermissionDeniedException('You do not have permission to create periodic reviews');
  }

  final entityType = requireString(body, 'entity_type');
  final entityId = requireUuid(body, 'entity_id');
  final reviewCycleMonths = body['review_cycle_months'] as int? ?? 12;

  // Check not already scheduled
  final existing = await supabase
      .from('periodic_reviews')
      .select('id')
      .eq('entity_type', entityType)
      .eq('entity_id', entityId)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Periodic review already scheduled for this entity');
  }

  final now = DateTime.now();
  final firstReviewDate = body['first_review_date'] as String? ?? 
      now.add(Duration(days: reviewCycleMonths * 30)).toIso8601String().split('T')[0];

  final review = await supabase
      .from('periodic_reviews')
      .insert({
        'entity_type': entityType,
        'entity_id': entityId,
        'review_cycle_months': reviewCycleMonths,
        'next_review_date': firstReviewDate,
        'status': 'scheduled',
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
/// Body: { outcome, comments? }
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

  final existing = await supabase
      .from('periodic_reviews')
      .select('id, status, review_cycle_months')
      .eq('id', reviewId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Periodic review not found');
  }

  if (existing['status'] != 'scheduled' && existing['status'] != 'overdue') {
    throw ConflictException('Review is not pending completion');
  }

  final now = DateTime.now();
  final nowStr = now.toUtc().toIso8601String();

  // Create e-signature
  final esigResult = await supabase.rpc('create_esignature', params: {
    'p_employee_id': auth.employeeId,
    'p_reauth_session_id': esig.reauthSessionId,
    'p_entity_type': 'periodic_reviews',
    'p_entity_id': reviewId,
    'p_action': 'complete',
    'p_meaning': esig.meaning,
    'p_reason': esig.reason,
  });

  // Add history record
  await supabase.from('periodic_review_history').insert({
    'periodic_review_id': reviewId,
    'review_date': nowStr,
    'reviewed_by': auth.employeeId,
    'outcome': outcome,
    'comments': body['comments'],
    'esig_id': esigResult['id'],
  });

  // Calculate next review date
  final cycleMonths = existing['review_cycle_months'] as int;
  final nextReviewDate = now.add(Duration(days: cycleMonths * 30)).toIso8601String().split('T')[0];

  // Update review schedule
  await supabase
      .from('periodic_reviews')
      .update({
        'last_review_date': nowStr,
        'next_review_date': nextReviewDate,
        'status': 'scheduled',
        'last_reviewed_by': auth.employeeId,
      })
      .eq('id', reviewId);

  return ApiResponse.ok({
    'message': 'Periodic review completed',
    'next_review_date': nextReviewDate,
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
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  for (final field in ['review_cycle_months', 'next_review_date', 'status']) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('periodic_reviews')
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

  // Delete history first
  await supabase.from('periodic_review_history').delete().eq('periodic_review_id', reviewId);
  
  // Delete review
  await supabase.from('periodic_reviews').delete().eq('id', reviewId);

  return ApiResponse.noContent().toResponse();
}
