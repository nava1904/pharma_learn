import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/question-papers/:id - Get question paper by ID
Future<Response> questionPaperGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('question_papers')
      .select('*, question_paper_items(*, questions(*))')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Question paper not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/question-papers/:id - Update question paper
Future<Response> questionPaperUpdateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'question_papers.update',
    jwtPermissions: auth.permissions,
  );

  // Check if paper is in draft status
  final existing = await supabase
      .from('question_papers')
      .select('id, status')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Question paper not found').toResponse();
  }

  if (existing['status'] != 'draft') {
    return ErrorResponse.conflict('Only draft question papers can be edited').toResponse();
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
  if (body['time_limit_minutes'] != null) updateData['time_limit_minutes'] = body['time_limit_minutes'];
  if (body['pass_mark'] != null) updateData['pass_mark'] = body['pass_mark'];
  if (body['max_attempts'] != null) updateData['max_attempts'] = body['max_attempts'];
  if (body['shuffle_questions'] != null) updateData['shuffle_questions'] = body['shuffle_questions'];
  if (body['shuffle_options'] != null) updateData['shuffle_options'] = body['shuffle_options'];

  final result = await supabase
      .from('question_papers')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'question_papers',
    'entity_id': id,
    'action': 'UPDATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/question-papers/:id/publish - Publish question paper [esig]
Future<Response> questionPaperPublishHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to publish question paper').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'question_papers.publish',
    jwtPermissions: auth.permissions,
  );

  // Verify paper exists and is in draft status
  final existing = await supabase
      .from('question_papers')
      .select('id, status, name')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Question paper not found').toResponse();
  }

  if (existing['status'] != 'draft') {
    return ErrorResponse.conflict('Only draft question papers can be published').toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'question_papers',
    'entity_id': id,
    'meaning': 'PUBLISH',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  // Update question paper status
  final result = await supabase
      .from('question_papers')
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
    'entity_type': 'question_papers',
    'entity_id': id,
    'action': 'PUBLISH',
    'performed_by': auth.employeeId,
    'changes': {'status': 'published', 'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// GET /v1/question-papers/:id/items - List items in question paper
Future<Response> questionPaperItemsListHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;

  final result = await supabase
      .from('question_paper_items')
      .select('*, questions(*)')
      .eq('question_paper_id', id)
      .order('sequence_number');

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/question-papers/:id/items - Add items to question paper
Future<Response> questionPaperItemsAddHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'question_papers.update',
    jwtPermissions: auth.permissions,
  );

  // Verify paper is in draft status
  final existing = await supabase
      .from('question_papers')
      .select('id, status')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Question paper not found').toResponse();
  }

  if (existing['status'] != 'draft') {
    return ErrorResponse.conflict('Can only add items to draft question papers').toResponse();
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
      .from('question_paper_items')
      .select('sequence_number')
      .eq('question_paper_id', id)
      .order('sequence_number', ascending: false)
      .limit(1)
      .maybeSingle();

  int nextSeq = (maxSeqResult?['sequence_number'] as int? ?? 0) + 1;

  final insertData = items.map((item) {
    final data = {
      'question_paper_id': id,
      'question_id': item['question_id'],
      'sequence_number': item['sequence_number'] ?? nextSeq++,
      'marks': item['marks'],
    };
    return data;
  }).toList();

  final result = await supabase
      .from('question_paper_items')
      .insert(insertData)
      .select('*, questions(*)');

  await supabase.from('audit_trails').insert({
    'entity_type': 'question_papers',
    'entity_id': id,
    'action': 'ADD_ITEMS',
    'performed_by': auth.employeeId,
    'changes': {'added_count': items.length},
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}
