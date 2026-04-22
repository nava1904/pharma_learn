import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/query_parser.dart';

/// GET /v1/question-banks/:id - Get question bank by ID
Future<Response> questionBankGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('question_banks')
      .select('*, questions(count)')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Question bank not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/question-banks/:id - Update question bank
Future<Response> questionBankUpdateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'question_banks.update',
    jwtPermissions: auth.permissions,
  );

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
  if (body['category_id'] != null) updateData['category_id'] = body['category_id'];
  if (body['is_active'] != null) updateData['is_active'] = body['is_active'];

  final result = await supabase
      .from('question_banks')
      .update(updateData)
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'question_banks',
    'entity_id': id,
    'action': 'UPDATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// GET /v1/questions - List questions (with filters)
Future<Response> questionsListHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final q = QueryParams.fromRequest(req);
  final qp = req.url.queryParameters;
  final offset = (q.page - 1) * q.perPage;

  var query = supabase
      .from('questions')
      .select('*, question_banks(id, name)')
      .eq('org_id', auth.orgId);

  if (qp['question_bank_id'] != null) {
    query = query.eq('question_bank_id', qp['question_bank_id']!);
  }
  if (qp['question_type'] != null) {
    query = query.eq('question_type', qp['question_type']!);
  }
  if (qp['difficulty'] != null) {
    query = query.eq('difficulty', qp['difficulty']!);
  }
  if (q.search != null && q.search!.isNotEmpty) {
    query = query.ilike('question_text', '%${q.search}%');
  }

  final response = await query
      .order(q.sortBy ?? 'created_at', ascending: q.sortOrder == 'asc')
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  final pagination = Pagination(
    page: q.page,
    perPage: q.perPage,
    total: response.count,
    totalPages: response.count == 0 ? 1 : (response.count / q.perPage).ceil(),
  );

  return ApiResponse.paginated(response.data, pagination).toResponse();
}

/// POST /v1/questions - Create a question
Future<Response> questionsCreateHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'questions.create',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final errors = <String, String>{};
  if (body['question_bank_id'] == null) {
    errors['question_bank_id'] = 'question_bank_id is required';
  }
  if (body['question_text'] == null) {
    errors['question_text'] = 'question_text is required';
  }
  if (body['question_type'] == null) {
    errors['question_type'] = 'question_type is required';
  }

  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  final result = await supabase.from('questions').insert({
    'question_bank_id': body['question_bank_id'],
    'question_text': body['question_text'],
    'question_type': body['question_type'],
    'options': body['options'],
    'correct_answer': body['correct_answer'],
    'marks': body['marks'] ?? 1,
    'difficulty': body['difficulty'] ?? 'medium',
    'explanation': body['explanation'],
    'org_id': auth.orgId,
    'created_by': auth.employeeId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'questions',
    'entity_id': result['id'],
    'action': 'CREATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}

/// GET /v1/questions/:id - Get question by ID
Future<Response> questionGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('questions')
      .select('*, question_banks(id, name)')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Question not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/questions/:id - Update question
Future<Response> questionUpdateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'questions.update',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final updateData = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'updated_by': auth.employeeId,
  };

  if (body['question_text'] != null) updateData['question_text'] = body['question_text'];
  if (body['question_type'] != null) updateData['question_type'] = body['question_type'];
  if (body['options'] != null) updateData['options'] = body['options'];
  if (body['correct_answer'] != null) updateData['correct_answer'] = body['correct_answer'];
  if (body['marks'] != null) updateData['marks'] = body['marks'];
  if (body['difficulty'] != null) updateData['difficulty'] = body['difficulty'];
  if (body['explanation'] != null) updateData['explanation'] = body['explanation'];
  if (body['is_active'] != null) updateData['is_active'] = body['is_active'];

  final result = await supabase
      .from('questions')
      .update(updateData)
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'questions',
    'entity_id': id,
    'action': 'UPDATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// DELETE /v1/questions/:id - Delete question (soft delete)
Future<Response> questionDeleteHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'questions.delete',
    jwtPermissions: auth.permissions,
  );

  // Soft delete
  await supabase
      .from('questions')
      .update({
        'is_active': false,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'deleted_by': auth.employeeId,
      })
      .eq('id', id)
      .eq('org_id', auth.orgId);

  await supabase.from('audit_trails').insert({
    'entity_type': 'questions',
    'entity_id': id,
    'action': 'DELETE',
    'performed_by': auth.employeeId,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok({'deleted': true}).toResponse();
}
