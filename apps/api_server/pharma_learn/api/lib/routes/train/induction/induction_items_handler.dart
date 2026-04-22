import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/induction/:programId/items - List induction items
Future<Response> inductionItemsListHandler(Request req, String programId) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('induction_items')
      .select('*, course:courses(id, code, name, course_type)')
      .eq('program_id', programId)
      .order('sequence_number');

  // Get completion status for current employee
  final completions = await supabase
      .from('induction_completions')
      .select('item_id, completed_at')
      .eq('employee_id', auth.employeeId)
      .eq('program_id', programId);

  final completionMap = <String, String>{};
  for (final c in completions) {
    completionMap[c['item_id'] as String] = c['completed_at'] as String;
  }

  // Enrich items with completion status
  final enrichedItems = (result as List).map((item) {
    final itemId = item['id'] as String;
    return {
      ...item,
      'completed_at': completionMap[itemId],
      'is_completed': completionMap.containsKey(itemId),
    };
  }).toList();

  return ApiResponse.ok(enrichedItems).toResponse();
}

/// POST /v1/train/induction/:programId/items/:itemId/complete - Complete induction item
Future<Response> inductionItemCompleteHandler(Request req, String programId, String itemId) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  // Verify item exists
  final item = await supabase
      .from('induction_items')
      .select('id, program_id, course_id')
      .eq('id', itemId)
      .eq('program_id', programId)
      .maybeSingle();

  if (item == null) {
    return ErrorResponse.notFound('Induction item not found').toResponse();
  }

  // Check if already completed
  final existing = await supabase
      .from('induction_completions')
      .select('id')
      .eq('employee_id', auth.employeeId)
      .eq('item_id', itemId)
      .maybeSingle();

  if (existing != null) {
    return ErrorResponse.conflict('Item already completed').toResponse();
  }

  // Check prerequisites (if any previous items must be completed first)
  final itemResult = await supabase
      .from('induction_items')
      .select('sequence_number')
      .eq('id', itemId)
      .single();

  final currentSeq = itemResult['sequence_number'] as int;

  if (currentSeq > 1) {
    final previousItems = await supabase
        .from('induction_items')
        .select('id')
        .eq('program_id', programId)
        .lt('sequence_number', currentSeq);

    final previousIds = (previousItems as List).map((i) => i['id'] as String).toList();

    if (previousIds.isNotEmpty) {
      final completedCount = await supabase
          .from('induction_completions')
          .select('id')
          .eq('employee_id', auth.employeeId)
          .inFilter('item_id', previousIds);

      if ((completedCount as List).length < previousIds.length) {
        return ErrorResponse.validation({
          'prerequisite': 'Previous induction items must be completed first'
        }).toResponse();
      }
    }
  }

  // Record completion
  final result = await supabase.from('induction_completions').insert({
    'employee_id': auth.employeeId,
    'program_id': programId,
    'item_id': itemId,
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'induction_completions',
    'entity_id': result['id'],
    'action': 'COMPLETE_ITEM',
    'performed_by': auth.employeeId,
    'changes': {'item_id': itemId, 'program_id': programId},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/train/induction/complete - Complete full induction [esig]
/// Reference: EE §5.1.6 — induction gate completion
Future<Response> inductionCompleteHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to complete induction').toResponse();
  }

  // Get employee's assigned induction program
  final assignment = await supabase
      .from('employee_induction')
      .select('id, program_id, status')
      .eq('employee_id', auth.employeeId)
      .eq('status', 'in_progress')
      .maybeSingle();

  if (assignment == null) {
    return ErrorResponse.notFound('No active induction program found').toResponse();
  }

  final programId = assignment['program_id'] as String;

  // Check all items are completed
  final totalItems = await supabase
      .from('induction_items')
      .select('id')
      .eq('program_id', programId);

  final completedItems = await supabase
      .from('induction_completions')
      .select('id')
      .eq('employee_id', auth.employeeId)
      .eq('program_id', programId);

  if ((completedItems as List).length < (totalItems as List).length) {
    return ErrorResponse.validation({
      'completion': 'All induction items must be completed first'
    }).toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'employee_induction',
    'entity_id': assignment['id'],
    'meaning': 'COMPLETE_INDUCTION',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  // Update induction status
  await supabase
      .from('employee_induction')
      .update({
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'esignature_id': esigResult['id'],
      })
      .eq('id', assignment['id']);

  // Update employee record
  await supabase
      .from('employees')
      .update({
        'induction_completed': true,
        'induction_completed_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', auth.employeeId);

  await supabase.from('audit_trails').insert({
    'entity_type': 'employee_induction',
    'entity_id': assignment['id'],
    'action': 'COMPLETE_INDUCTION',
    'performed_by': auth.employeeId,
    'changes': {'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok({
    'induction_completed': true,
    'completed_at': DateTime.now().toUtc().toIso8601String(),
  }).toResponse();
}
