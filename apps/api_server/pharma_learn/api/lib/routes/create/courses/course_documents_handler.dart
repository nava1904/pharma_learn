import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/create/courses/:id/documents
///
/// Returns documents linked to a course (supplementary materials).
Future<Response> courseDocumentsListHandler(Request req) async {
  final courseId = parsePathUuid(req.rawPathParameters[#id]);
  final supabase = RequestContext.supabase;

  // Verify course exists
  final course = await supabase
      .from('courses')
      .select('id')
      .eq('id', courseId)
      .maybeSingle();

  if (course == null) {
    throw NotFoundException('Course not found');
  }

  // Get linked documents
  final documents = await supabase
      .from('course_documents')
      .select('''
        id, sequence_order, is_required, created_at,
        documents!inner(
          id, document_number, title, status, version,
          document_types(name)
        )
      ''')
      .eq('course_id', courseId)
      .order('sequence_order', ascending: true);

  return ApiResponse.ok(documents).toResponse();
}

/// POST /v1/create/courses/:id/documents
///
/// Links a document to a course.
///
/// Body:
/// ```json
/// {
///   "document_id": "uuid",
///   "sequence_order": 1,
///   "is_required": true
/// }
/// ```
Future<Response> courseDocumentsAddHandler(Request req) async {
  final courseId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Permission check
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final documentId = body['document_id'] as String?;
  final sequenceOrder = body['sequence_order'] as int? ?? 1;
  final isRequired = body['is_required'] as bool? ?? false;

  if (documentId == null || documentId.isEmpty) {
    throw ValidationException({'document_id': 'Required'});
  }

  // Verify course exists and is editable
  final course = await supabase
      .from('courses')
      .select('id, status')
      .eq('id', courseId)
      .maybeSingle();

  if (course == null) {
    throw NotFoundException('Course not found');
  }

  if (course['status'] == 'approved' || course['status'] == 'effective') {
    throw ConflictException('Cannot modify documents for approved/effective courses');
  }

  // Verify document exists
  final document = await supabase
      .from('documents')
      .select('id, status')
      .eq('id', documentId)
      .maybeSingle();

  if (document == null) {
    throw NotFoundException('Document not found');
  }

  // Check if already linked
  final existing = await supabase
      .from('course_documents')
      .select('id')
      .eq('course_id', courseId)
      .eq('document_id', documentId)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Document is already linked to this course');
  }

  // Create link
  final link = await supabase.from('course_documents').insert({
    'course_id': courseId,
    'document_id': documentId,
    'sequence_order': sequenceOrder,
    'is_required': isRequired,
    'created_by': auth.employeeId,
  }).select().single();

  return ApiResponse.created(link).toResponse();
}

/// DELETE /v1/create/courses/:id/documents/:documentId
///
/// Removes a document link from a course.
Future<Response> courseDocumentsRemoveHandler(Request req) async {
  final courseId = parsePathUuid(req.rawPathParameters[#id]);
  final documentId = parsePathUuid(req.rawPathParameters[#documentId], fieldName: 'documentId');
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Permission check
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  // Verify course is editable
  final course = await supabase
      .from('courses')
      .select('id, status')
      .eq('id', courseId)
      .maybeSingle();

  if (course == null) {
    throw NotFoundException('Course not found');
  }

  if (course['status'] == 'approved' || course['status'] == 'effective') {
    throw ConflictException('Cannot modify documents for approved/effective courses');
  }

  // Delete link
  final deleted = await supabase
      .from('course_documents')
      .delete()
      .eq('course_id', courseId)
      .eq('document_id', documentId)
      .select();

  if (deleted.isEmpty) {
    throw NotFoundException('Document link not found');
  }

  return ApiResponse.noContent().toResponse();
}
