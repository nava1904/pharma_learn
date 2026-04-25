import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/documents/:id
Future<Response> documentGetHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewDocuments,
    jwtPermissions: auth.permissions,
  );

  final document = await supabase
      .from('documents')
      .select(
        '*, '
        'employees!owner_id ( id, first_name, last_name ), '
        'departments ( id, name )',
      )
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (document == null) throw NotFoundException('Document not found');

  return ApiResponse.ok({'document': document}).toResponse();
}

/// PATCH /v1/documents/:id
///
/// Allowed only when status ∈ {draft, initiated, returned}.
/// Body: `{name?, description?, department_id?, owner_id?, storage_url?,
///         effective_from?, effective_until?, next_review?, sop_number?}`
Future<Response> documentPatchHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editDocuments,
    jwtPermissions: auth.permissions,
  );

  final document = await supabase
      .from('documents')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (document == null) throw NotFoundException('Document not found');

  final status = document['status'] as String? ?? '';
  if (!['draft', 'initiated', 'returned'].contains(status)) {
    throw ConflictException(
      'Document cannot be edited in status "$status". '
      'Only draft, initiated, or returned documents may be modified.',
    );
  }

  final body = await readJson(req);
  final updates = <String, dynamic>{};

  final editableFields = [
    'name', 'description', 'department_id', 'owner_id',
    'storage_url', 'file_name', 'file_size_bytes', 'mime_type',
    'effective_from', 'effective_until', 'next_review', 'sop_number',
  ];

  for (final field in editableFields) {
    if (body.containsKey(field)) {
      updates[field] = body[field];
    }
  }

  if (updates.isEmpty) {
    return ApiResponse.ok({'document': document}).toResponse();
  }

  final updated = await supabase
      .from('documents')
      .update(updates)
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .select()
      .single();

  return ApiResponse.ok({'document': updated}).toResponse();
}

/// DELETE /v1/documents/:id
///
/// Only `draft` documents may be deleted.
Future<Response> documentDeleteHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.deleteDocuments,
    jwtPermissions: auth.permissions,
  );

  final document = await supabase
      .from('documents')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (document == null) throw NotFoundException('Document not found');

  final status = document['status'] as String? ?? '';
  if (status != 'draft') {
    throw ImmutableRecordException(
      'Only draft documents may be deleted. Current status: "$status".',
    );
  }

  await supabase
      .from('documents')
      .delete()
      .eq('id', id)
      .eq('organization_id', auth.orgId);

  return ApiResponse.noContent().toResponse();
}
