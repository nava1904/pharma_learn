import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';
import '../../../utils/query_parser.dart';

/// GET /v1/topics
///
/// Lists all topics for the organization.
/// URS Alfa §5.4.2 - Master data management for topics
///
/// Query params:
/// - status: Filter by status
/// - plant_id: Filter by plant
/// - search: Search by name or code
Future<Response> topicsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final params = req.url.queryParameters;
  final q = QueryParams.fromRequest(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCourses,
    jwtPermissions: auth.permissions,
  );

  final offset = (q.page - 1) * q.perPage;

  var query = supabase
      .from('topics')
      .select('''
        id, organization_id, plant_id, name, unique_code, description,
        objectives, duration_minutes, status, revision_no,
        created_at, updated_at, created_by, approved_at, approved_by,
        plants(id, name, code)
      ''')
      .eq('organization_id', auth.orgId);

  // Apply filters
  if (params['status'] != null) {
    query = query.eq('status', params['status']!);
  }
  if (params['plant_id'] != null) {
    query = query.eq('plant_id', params['plant_id']!);
  }
  if (params['search'] != null && params['search']!.isNotEmpty) {
    query = query.or('name.ilike.%${params['search']}%,unique_code.ilike.%${params['search']}%');
  }

  final response = await query
      .order('name')
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  return ApiResponse.paginated(
    response.data,
    Pagination(
      page: q.page,
      perPage: q.perPage,
      total: response.count,
      totalPages: response.count == 0 ? 1 : (response.count / q.perPage).ceil(),
    ),
  ).toResponse();
}

/// GET /v1/topics/:id
///
/// Returns a single topic with all related data.
Future<Response> topicGetHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCourses,
    jwtPermissions: auth.permissions,
  );

  final topic = await supabase
      .from('topics')
      .select('''
        id, organization_id, plant_id, name, unique_code, description,
        objectives, duration_minutes, content_html, status, revision_no,
        created_at, updated_at, created_by, approved_at, approved_by,
        plants(id, name, code),
        employees!created_by(id, first_name, last_name),
        approver:employees!approved_by(id, first_name, last_name)
      ''')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (topic == null) {
    throw NotFoundException('Topic not found');
  }

  // Get category tags
  final categoryTags = await supabase
      .from('topic_category_tags')
      .select('category_id, categories(id, name, unique_code)')
      .eq('topic_id', id);

  // Get subject tags
  final subjectTags = await supabase
      .from('topic_subject_tags')
      .select('subject_id, subjects(id, name, unique_code)')
      .eq('topic_id', id);

  // Get linked documents
  final documentLinks = await supabase
      .from('topic_document_links')
      .select('''
        id, document_id, is_mandatory, linked_at,
        documents(id, title, doc_number, status)
      ''')
      .eq('topic_id', id);

  return ApiResponse.ok({
    ...topic,
    'category_tags': categoryTags.map((t) => t['categories']).toList(),
    'subject_tags': subjectTags.map((t) => t['subjects']).toList(),
    'document_links': documentLinks,
  }).toResponse();
}

/// POST /v1/topics
///
/// Creates a new topic.
///
/// Body:
/// ```json
/// {
///   "name": "GMP Basics",
///   "unique_code": "TOP-001",
///   "description": "Topic covering GMP basics",
///   "objectives": "Understand GMP principles",
///   "duration_minutes": 60,
///   "plant_id": "uuid",
///   "category_ids": ["uuid"],
///   "subject_ids": ["uuid"]
/// }
/// ```
Future<Response> topicCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final name = requireString(body, 'name');
  final uniqueCode = requireString(body, 'unique_code');

  // Check unique code doesn't already exist
  final existing = await supabase
      .from('topics')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('unique_code', uniqueCode)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Topic with code $uniqueCode already exists');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final topic = await supabase
      .from('topics')
      .insert({
        'organization_id': auth.orgId,
        'plant_id': body['plant_id'],
        'name': name,
        'unique_code': uniqueCode,
        'description': body['description'],
        'objectives': body['objectives'],
        'duration_minutes': body['duration_minutes'],
        'content_html': body['content_html'],
        'status': 'initiated',
        'created_by': auth.employeeId,
        'created_at': now,
        'updated_at': now,
      })
      .select()
      .single();

  final topicId = topic['id'] as String;

  // Add category tags
  final categoryIds = body['category_ids'] as List?;
  if (categoryIds != null && categoryIds.isNotEmpty) {
    await supabase.from('topic_category_tags').insert(
      categoryIds.map((cid) => {'topic_id': topicId, 'category_id': cid}).toList(),
    );
  }

  // Add subject tags
  final subjectIds = body['subject_ids'] as List?;
  if (subjectIds != null && subjectIds.isNotEmpty) {
    await supabase.from('topic_subject_tags').insert(
      subjectIds.map((sid) => {'topic_id': topicId, 'subject_id': sid}).toList(),
    );
  }

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'topic',
    'entity_id': topicId,
    'action': 'create',
    'new_values': topic,
    'employee_id': auth.employeeId,
    'created_at': now,
  });

  return ApiResponse.created(topic).toResponse();
}

/// PUT /v1/topics/:id
///
/// Updates an existing topic.
Future<Response> topicUpdateHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  // Get existing topic
  final existing = await supabase
      .from('topics')
      .select('*')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Topic not found');
  }

  // Check for approved status
  if (existing['status'] == 'approved') {
    throw ConflictException('Approved topics cannot be edited directly. Create a new revision.');
  }

  // Verify unique_code uniqueness if changing
  if (body['unique_code'] != null && body['unique_code'] != existing['unique_code']) {
    final duplicate = await supabase
        .from('topics')
        .select('id')
        .eq('organization_id', auth.orgId)
        .eq('unique_code', body['unique_code'])
        .neq('id', id)
        .maybeSingle();

    if (duplicate != null) {
      throw ConflictException('Topic with code ${body['unique_code']} already exists');
    }
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final updateData = <String, dynamic>{
    'updated_at': now,
  };

  if (body['name'] != null) updateData['name'] = body['name'];
  if (body['unique_code'] != null) updateData['unique_code'] = body['unique_code'];
  if (body['description'] != null) updateData['description'] = body['description'];
  if (body['objectives'] != null) updateData['objectives'] = body['objectives'];
  if (body['duration_minutes'] != null) updateData['duration_minutes'] = body['duration_minutes'];
  if (body['content_html'] != null) updateData['content_html'] = body['content_html'];
  if (body['plant_id'] != null) updateData['plant_id'] = body['plant_id'];

  final updated = await supabase
      .from('topics')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

  // Update category tags if provided
  final categoryIds = body['category_ids'] as List?;
  if (categoryIds != null) {
    await supabase.from('topic_category_tags').delete().eq('topic_id', id);
    if (categoryIds.isNotEmpty) {
      await supabase.from('topic_category_tags').insert(
        categoryIds.map((cid) => {'topic_id': id, 'category_id': cid}).toList(),
      );
    }
  }

  // Update subject tags if provided
  final subjectIds = body['subject_ids'] as List?;
  if (subjectIds != null) {
    await supabase.from('topic_subject_tags').delete().eq('topic_id', id);
    if (subjectIds.isNotEmpty) {
      await supabase.from('topic_subject_tags').insert(
        subjectIds.map((sid) => {'topic_id': id, 'subject_id': sid}).toList(),
      );
    }
  }

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'topic',
    'entity_id': id,
    'action': 'update',
    'old_values': existing,
    'new_values': updated,
    'employee_id': auth.employeeId,
    'created_at': now,
  });

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/topics/:id
///
/// Deletes a topic (soft delete via status change).
Future<Response> topicDeleteHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('topics')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Topic not found');
  }

  if (existing['status'] == 'approved') {
    throw ConflictException('Approved topics cannot be deleted. Mark as obsolete instead.');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('topics')
      .update({
        'status': 'obsolete',
        'updated_at': now,
      })
      .eq('id', id);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'topic',
    'entity_id': id,
    'action': 'delete',
    'employee_id': auth.employeeId,
    'created_at': now,
  });

  return ApiResponse.noContent().toResponse();
}

/// POST /v1/topics/:id/submit
///
/// Submits a topic for approval.
Future<Response> topicSubmitHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('topics')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Topic not found');
  }

  if (existing['status'] != 'initiated') {
    throw ConflictException('Only draft topics can be submitted for approval');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final updated = await supabase
      .from('topics')
      .update({
        'status': 'pending_approval',
        'updated_at': now,
      })
      .eq('id', id)
      .select()
      .single();

  // Create pending approval
  await supabase.from('pending_approvals').insert({
    'organization_id': auth.orgId,
    'entity_type': 'topic',
    'entity_id': id,
    'requested_by': auth.employeeId,
    'requested_at': now,
    'status': 'pending',
  });

  // Audit
  await supabase.from('audit_trails').insert({
    'entity_type': 'topic',
    'entity_id': id,
    'action': 'submit_for_approval',
    'employee_id': auth.employeeId,
    'created_at': now,
  });

  return ApiResponse.ok(updated).toResponse();
}

/// POST /v1/topics/:id/approve
///
/// Approves a topic.
Future<Response> topicApproveHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.approveCourses,
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('topics')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Topic not found');
  }

  if (existing['status'] != 'pending_approval') {
    throw ConflictException('Only pending topics can be approved');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Handle e-signature
  final esigData = body['esignature'] as Map<String, dynamic>?;
  String? esigId;
  if (esigData != null) {
    final reauthSessionId = esigData['reauth_session_id'] as String?;
    if (reauthSessionId != null) {
      final esig = await supabase.rpc(
        'create_esignature_from_reauth',
        params: {
          'p_reauth_session_id': reauthSessionId,
          'p_employee_id': auth.employeeId,
          'p_meaning': 'APPROVE',
          'p_context_type': 'topic_approval',
          'p_context_id': id,
        },
      ) as Map<String, dynamic>;
      esigId = esig['esignature_id'] as String?;
    }
  }

  final updated = await supabase
      .from('topics')
      .update({
        'status': 'approved',
        'approved_by': auth.employeeId,
        'approved_at': now,
        'updated_at': now,
      })
      .eq('id', id)
      .select()
      .single();

  // Update pending approval
  await supabase
      .from('pending_approvals')
      .update({
        'status': 'approved',
        'approved_by': auth.employeeId,
        'approved_at': now,
        'esignature_id': esigId,
        'comments': body['comments'],
      })
      .eq('entity_type', 'topic')
      .eq('entity_id', id)
      .eq('status', 'pending');

  // Audit
  await supabase.from('audit_trails').insert({
    'entity_type': 'topic',
    'entity_id': id,
    'action': 'approve',
    'employee_id': auth.employeeId,
    'new_values': {'esignature_id': esigId},
    'created_at': now,
  });

  return ApiResponse.ok(updated).toResponse();
}

/// POST /v1/topics/:id/documents
///
/// Links a document to a topic.
Future<Response> topicLinkDocumentHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final documentId = requireString(body, 'document_id');
  final isMandatory = body['is_mandatory'] as bool? ?? true;

  // Verify topic exists
  final topic = await supabase
      .from('topics')
      .select('id')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (topic == null) {
    throw NotFoundException('Topic not found');
  }

  // Verify document exists
  final document = await supabase
      .from('documents')
      .select('id')
      .eq('id', documentId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (document == null) {
    throw NotFoundException('Document not found');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final link = await supabase
      .from('topic_document_links')
      .upsert({
        'topic_id': id,
        'document_id': documentId,
        'is_mandatory': isMandatory,
        'linked_at': now,
        'linked_by': auth.employeeId,
      }, onConflict: 'topic_id,document_id')
      .select('''
        id, topic_id, document_id, is_mandatory, linked_at,
        documents(id, title, doc_number)
      ''')
      .single();

  return ApiResponse.created(link).toResponse();
}

/// DELETE /v1/topics/:id/documents/:documentId
///
/// Unlinks a document from a topic.
Future<Response> topicUnlinkDocumentHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final documentId = parsePathUuid(req.rawPathParameters[#documentId], fieldName: 'documentId');
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  // Verify topic exists and belongs to org
  final topic = await supabase
      .from('topics')
      .select('id')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (topic == null) {
    throw NotFoundException('Topic not found');
  }

  await supabase
      .from('topic_document_links')
      .delete()
      .eq('topic_id', id)
      .eq('document_id', documentId);

  return ApiResponse.noContent().toResponse();
}
