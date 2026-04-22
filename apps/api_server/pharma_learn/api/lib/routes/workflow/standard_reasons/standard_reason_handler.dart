import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/standard-reasons
///
/// Lists standard reasons for actions (rejection, waiver, revocation, etc.)
Future<Response> standardReasonsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final category = req.url.queryParameters['category'];

  var query = supabase
      .from('standard_reasons')
      .select('id, code, category, description, is_active, display_order')
      .eq('organization_id', auth.orgId)
      .eq('is_active', true);

  if (category != null && category.isNotEmpty) {
    query = query.eq('category', category);
  }

  final reasons = await query.order('display_order', ascending: true);

  return ApiResponse.ok({'reasons': reasons}).toResponse();
}

/// POST /v1/standard-reasons
///
/// Creates a new standard reason.
Future<Response> standardReasonCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (!auth.hasPermission('standard_reasons.manage')) {
    throw PermissionDeniedException('You do not have permission to manage standard reasons');
  }

  final code = body['code'] as String?;
  final category = body['category'] as String?;
  final description = body['description'] as String?;

  if (code == null || code.isEmpty) {
    throw ValidationException({'code': 'Code is required'});
  }
  if (category == null || category.isEmpty) {
    throw ValidationException({'category': 'Category is required'});
  }
  if (description == null || description.isEmpty) {
    throw ValidationException({'description': 'Description is required'});
  }

  // Validate category
  final validCategories = ['rejection', 'waiver', 'revocation', 'correction', 'deviation', 'other'];
  if (!validCategories.contains(category)) {
    throw ValidationException({
      'category': 'Category must be one of: ${validCategories.join(", ")}'
    });
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final reason = await supabase
      .from('standard_reasons')
      .insert({
        'code': code.toUpperCase(),
        'category': category,
        'description': description,
        'is_active': true,
        'display_order': body['display_order'] ?? 0,
        'organization_id': auth.orgId,
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  return ApiResponse.created({'reason': reason}).toResponse();
}

/// GET /v1/standard-reasons/:id
Future<Response> standardReasonGetHandler(Request req) async {
  final reasonId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (reasonId == null) throw ValidationException({'id': 'Reason ID is required'});

  final reason = await supabase
      .from('standard_reasons')
      .select('*')
      .eq('id', reasonId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (reason == null) throw NotFoundException('Standard reason not found');

  return ApiResponse.ok({'reason': reason}).toResponse();
}

/// PATCH /v1/standard-reasons/:id
Future<Response> standardReasonUpdateHandler(Request req) async {
  final reasonId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (reasonId == null) throw ValidationException({'id': 'Reason ID is required'});

  if (!auth.hasPermission('standard_reasons.manage')) {
    throw PermissionDeniedException('You do not have permission to manage standard reasons');
  }

  final allowedFields = ['description', 'is_active', 'display_order'];
  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updates[field] = body[field];
    }
  }

  final updated = await supabase
      .from('standard_reasons')
      .update(updates)
      .eq('id', reasonId)
      .eq('organization_id', auth.orgId)
      .select()
      .maybeSingle();

  if (updated == null) throw NotFoundException('Standard reason not found');

  return ApiResponse.ok({'reason': updated}).toResponse();
}
