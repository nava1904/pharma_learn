import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/categories
///
/// Lists course/document categories.
Future<Response> categoriesListHandler(Request req) async {
  final supabase = RequestContext.supabase;

  final params = req.url.queryParameters;
  final entityType = params['entity_type']; // 'course', 'document', etc.

  var query = supabase
      .from('categories')
      .select('id, name, description, entity_type, parent_id, sort_order, is_active');

  if (entityType != null) {
    query = query.eq('entity_type', entityType);
  }

  final categories = await query
      .order('sort_order', ascending: true)
      .order('name', ascending: true);

  return ApiResponse.ok(categories).toResponse();
}

/// GET /v1/categories/:id
Future<Response> categoryGetHandler(Request req) async {
  final categoryId = req.rawPathParameters[#id];
  final supabase = RequestContext.supabase;

  if (categoryId == null || categoryId.isEmpty) {
    throw ValidationException({'id': 'Category ID is required'});
  }

  final category = await supabase
      .from('categories')
      .select('*, children:categories!parent_id(id, name)')
      .eq('id', categoryId)
      .maybeSingle();

  if (category == null) {
    throw NotFoundException('Category not found');
  }

  return ApiResponse.ok(category).toResponse();
}

/// POST /v1/categories
Future<Response> categoryCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to create categories');
  }

  final name = requireString(body, 'name');
  final entityType = requireString(body, 'entity_type');

  final now = DateTime.now().toUtc().toIso8601String();

  final category = await supabase
      .from('categories')
      .insert({
        'name': name,
        'description': body['description'],
        'entity_type': entityType,
        'parent_id': body['parent_id'],
        'sort_order': body['sort_order'] ?? 0,
        'is_active': true,
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  return ApiResponse.created(category).toResponse();
}

/// PATCH /v1/categories/:id
Future<Response> categoryUpdateHandler(Request req) async {
  final categoryId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (categoryId == null || categoryId.isEmpty) {
    throw ValidationException({'id': 'Category ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to update categories');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  for (final field in ['name', 'description', 'parent_id', 'sort_order', 'is_active']) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('categories')
      .update(updateData)
      .eq('id', categoryId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/categories/:id
Future<Response> categoryDeleteHandler(Request req) async {
  final categoryId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (categoryId == null || categoryId.isEmpty) {
    throw ValidationException({'id': 'Category ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to delete categories');
  }

  // Check for children
  final children = await supabase
      .from('categories')
      .select('id')
      .eq('parent_id', categoryId)
      .limit(1);

  if (children.isNotEmpty) {
    throw ConflictException('Cannot delete category with sub-categories');
  }

  await supabase.from('categories').delete().eq('id', categoryId);

  return ApiResponse.noContent().toResponse();
}
