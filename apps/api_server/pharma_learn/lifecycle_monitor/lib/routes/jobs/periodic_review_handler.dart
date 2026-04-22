import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /jobs/periodic-review
///
/// Triggers periodic review workflows for documents, SOPs, and training plans.
/// 
/// WHO GMP §4.3.4 - Documents must be reviewed at defined intervals.
/// 21 CFR §211.68(a) - SOPs must be reviewed annually or when changes occur.
/// ICH E6(R2) §5.1.3 - Review intervals must be documented.
/// 
/// Review intervals (configurable per entity):
/// - Critical SOPs: Every 12 months (default)
/// - Training materials: Every 24 months
/// - Work instructions: Every 18 months
/// - Quality procedures: Every 12 months
/// 
/// Flow:
/// 1. Query entities approaching review due date (within lookahead window)
/// 2. Create periodic_review records for tracking
/// 3. Notify document owners and QA reviewers
/// 4. Track acknowledgment of review requirement
Future<Response> periodicReviewHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final startTime = DateTime.now();
  final now = DateTime.now().toUtc();
  
  // Lookahead window: Find items due for review within this many days
  const lookaheadDays = 30;
  final lookAheadDate = now.add(const Duration(days: lookaheadDays));
  
  var reviewsCreated = 0;
  var notificationsSent = 0;
  var alreadyScheduled = 0;
  final errors = <Map<String, dynamic>>[];
  
  // Entity types that require periodic review with their default intervals
  const reviewableEntities = <String, Map<String, dynamic>>{
    'documents': {
      'review_field': 'next_review_date',
      'status_filter': 'EFFECTIVE',
      'owner_field': 'created_by',
      'default_interval_months': 12,
    },
    'training_plans': {
      'review_field': 'next_review_date',
      'status_filter': 'EFFECTIVE',
      'owner_field': 'created_by',
      'default_interval_months': 24,
    },
    'courses': {
      'review_field': 'next_review_date',
      'status_filter': 'EFFECTIVE',
      'owner_field': 'created_by',
      'default_interval_months': 24,
    },
    'curricula': {
      'review_field': 'next_review_date',
      'status_filter': 'EFFECTIVE',
      'owner_field': 'created_by',
      'default_interval_months': 12,
    },
    'question_papers': {
      'review_field': 'next_review_date',
      'status_filter': 'EFFECTIVE',
      'owner_field': 'created_by',
      'default_interval_months': 12,
    },
  };
  
  for (final entry in reviewableEntities.entries) {
    final tableName = entry.key;
    final config = entry.value;
    final reviewField = config['review_field'] as String;
    final statusFilter = config['status_filter'] as String;
    final ownerField = config['owner_field'] as String;
    
    try {
      // Find entities due for review
      final entities = await supabase
          .from(tableName)
          .select('id, title, organization_id, $ownerField, $reviewField')
          .eq('status', statusFilter)
          .lte(reviewField, lookAheadDate.toIso8601String())
          .gte(reviewField, now.toIso8601String())
          .limit(100);
      
      for (final entity in entities) {
        final entityId = entity['id'] as String;
        final orgId = entity['organization_id'] as String;
        final ownerId = entity[ownerField] as String?;
        final reviewDate = entity[reviewField] as String?;
        
        // Check if review already scheduled
        final existing = await supabase
            .from('periodic_reviews')
            .select('id')
            .eq('entity_type', tableName.replaceAll('s', ''))  // documents -> document
            .eq('entity_id', entityId)
            .eq('status', 'pending')
            .maybeSingle();
        
        if (existing != null) {
          alreadyScheduled++;
          continue;
        }
        
        // Create periodic review record
        final review = await supabase
            .from('periodic_reviews')
            .insert({
              'entity_type': tableName.replaceAll(RegExp(r's$'), ''),  // Remove trailing 's'
              'entity_id': entityId,
              'organization_id': orgId,
              'review_due_date': reviewDate,
              'owner_employee_id': ownerId,
              'status': 'pending',
              'created_at': now.toIso8601String(),
            })
            .select()
            .single();
        
        reviewsCreated++;
        
        // Publish event for notification
        await EventPublisher.publish(
          supabase,
          eventType: 'periodic_review.due',
          aggregateType: 'periodic_review',
          aggregateId: review['id'] as String,
          orgId: orgId,
          payload: {
            'entity_type': tableName.replaceAll(RegExp(r's$'), ''),
            'entity_id': entityId,
            'entity_title': entity['title'],
            'review_due_date': reviewDate,
            'owner_employee_id': ownerId,
          },
        );
        
        notificationsSent++;
      }
    } catch (e) {
      errors.add({
        'entity_type': tableName,
        'error': e.toString(),
      });
    }
  }
  
  // Also check for overdue reviews (past due date, still pending)
  final overdueReviews = await supabase
      .from('periodic_reviews')
      .select('id, entity_type, entity_id, organization_id, owner_employee_id')
      .eq('status', 'pending')
      .lt('review_due_date', now.toIso8601String())
      .isFilter('escalated_at', null)
      .limit(50);
  
  var escalations = 0;
  for (final review in overdueReviews) {
    try {
      // Mark as escalated
      await supabase.from('periodic_reviews').update({
        'escalated_at': now.toIso8601String(),
      }).eq('id', review['id']);
      
      // Publish escalation event
      await EventPublisher.publish(
        supabase,
        eventType: 'periodic_review.overdue',
        aggregateType: 'periodic_review',
        aggregateId: review['id'] as String,
        orgId: review['organization_id'] as String,
        payload: {
          'entity_type': review['entity_type'],
          'entity_id': review['entity_id'],
          'owner_employee_id': review['owner_employee_id'],
          'escalate_to': 'qa_manager',
        },
      );
      
      escalations++;
    } catch (e) {
      errors.add({
        'review_id': review['id'],
        'action': 'escalation',
        'error': e.toString(),
      });
    }
  }
  
  final duration = DateTime.now().difference(startTime);
  
  // Log job execution
  await supabase.from('job_executions').insert({
    'job_name': 'periodic_review',
    'started_at': startTime.toUtc().toIso8601String(),
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'status': errors.isEmpty ? 'success' : 'partial',
    'result': jsonEncode({
      'reviews_created': reviewsCreated,
      'notifications_sent': notificationsSent,
      'already_scheduled': alreadyScheduled,
      'escalations': escalations,
      'errors': errors,
    }),
  });
  
  return ApiResponse.ok({
    'job': 'periodic_review',
    'reviews_created': reviewsCreated,
    'notifications_sent': notificationsSent,
    'already_scheduled': alreadyScheduled,
    'escalations': escalations,
    'duration_ms': duration.inMilliseconds,
  }).toResponse();
}
