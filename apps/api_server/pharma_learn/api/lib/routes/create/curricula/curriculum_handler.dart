import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/curricula/:id - Get curriculum by ID
Future<Response> curriculumGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('curricula')
      .select('*, curriculum_items(*, courses(id, code, name))')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Curriculum not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/curricula/:id - Update curriculum
Future<Response> curriculumUpdateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'curricula.update',
    jwtPermissions: auth.permissions,
  );

  // Check if curriculum is in draft status
  final existing = await supabase
      .from('curricula')
      .select('id, status')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Curriculum not found').toResponse();
  }

  if (existing['status'] != 'draft') {
    return ErrorResponse.conflict('Only draft curricula can be edited').toResponse();
  }

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final updateData = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'updated_by': auth.employeeId,
  };

  if (body['name'] != null) updateData['name'] = body['name'];
  if (body['description'] != null) updateData['description'] = body['description'];
  if (body['target_roles'] != null) updateData['target_roles'] = body['target_roles'];
  if (body['validity_months'] != null) updateData['validity_months'] = body['validity_months'];

  final result = await supabase
      .from('curricula')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'curricula',
    'entity_id': id,
    'action': 'UPDATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/curricula/:id/publish - Publish curriculum [esig]
Future<Response> curriculumPublishHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to publish curriculum').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'curricula.publish',
    jwtPermissions: auth.permissions,
  );

  // Verify curriculum exists and is in draft status
  final existing = await supabase
      .from('curricula')
      .select('id, status, name')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Curriculum not found').toResponse();
  }

  if (existing['status'] != 'draft') {
    return ErrorResponse.conflict('Only draft curricula can be published').toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'curricula',
    'entity_id': id,
    'meaning': 'PUBLISH',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  // Update curriculum status
  final result = await supabase
      .from('curricula')
      .update({
        'status': 'published',
        'published_at': DateTime.now().toUtc().toIso8601String(),
        'published_by': auth.employeeId,
        'esignature_id': esigResult['id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'curricula',
    'entity_id': id,
    'action': 'PUBLISH',
    'performed_by': auth.employeeId,
    'changes': {'status': 'published', 'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  // Publish event for lifecycle_monitor to process
  await OutboxService(supabase).publish(
    aggregateType: 'curricula',
    aggregateId: id,
    eventType: 'curriculum.published',
    payload: {
      'curriculum_id': id,
      'name': existing['name'],
      'org_id': auth.orgId,
    },
    orgId: auth.orgId,
  );

  return ApiResponse.ok(result).toResponse();
}

/// GET /v1/curricula/:id/items - List curriculum items
Future<Response> curriculumItemsListHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;

  final result = await supabase
      .from('curriculum_items')
      .select('*, courses(id, code, name, course_type)')
      .eq('curriculum_id', id)
      .order('sequence_number');

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/curricula/:id/items - Add items to curriculum
Future<Response> curriculumItemsAddHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'curricula.update',
    jwtPermissions: auth.permissions,
  );

  // Verify curriculum is in draft status
  final existing = await supabase
      .from('curricula')
      .select('id, status')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Curriculum not found').toResponse();
  }

  if (existing['status'] != 'draft') {
    return ErrorResponse.conflict('Can only add items to draft curricula').toResponse();
  }

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;
  final items = body['items'] as List? ?? [];

  if (items.isEmpty) {
    return ErrorResponse.validation({'items': 'items array is required'}).toResponse();
  }

  // Get current max sequence number
  final maxSeqResult = await supabase
      .from('curriculum_items')
      .select('sequence_number')
      .eq('curriculum_id', id)
      .order('sequence_number', ascending: false)
      .limit(1)
      .maybeSingle();

  int nextSeq = (maxSeqResult?['sequence_number'] as int? ?? 0) + 1;

  final insertData = items.map((item) {
    return {
      'curriculum_id': id,
      'course_id': item['course_id'],
      'sequence_number': item['sequence_number'] ?? nextSeq++,
      'is_mandatory': item['is_mandatory'] ?? true,
    };
  }).toList();

  final result = await supabase
      .from('curriculum_items')
      .insert(insertData)
      .select('*, courses(id, code, name)');

  await supabase.from('audit_trails').insert({
    'entity_type': 'curricula',
    'entity_id': id,
    'action': 'ADD_ITEMS',
    'performed_by': auth.employeeId,
    'changes': {'added_count': items.length},
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}
