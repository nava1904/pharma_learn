import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/quality/deviations
/// 
/// Lists deviations for the organization.
Future<Response> deviationsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;
  final status = req.url.queryParameters['status'];
  final offset = (page - 1) * perPage;

  var query = supabase
      .from('deviations')
      .select('''
        id, deviation_number, title, description, severity, status,
        root_cause, corrective_action, preventive_action,
        identified_by, identified_at, resolved_at, created_at,
        identifier:employees!deviations_identified_by_fkey (
          id, full_name, employee_number
        )
      ''')
      .eq('organization_id', auth.orgId);

  if (status != null && status.isNotEmpty) {
    query = query.eq('status', status);
  }

  final deviations = await query
      .order('created_at', ascending: false)
      .range(offset, offset + perPage - 1);

  return ApiResponse.ok({'deviations': deviations}).toResponse();
}

/// POST /v1/quality/deviations
///
/// Creates a new deviation record.
Future<Response> deviationCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (!auth.hasPermission('deviations.create')) {
    throw PermissionDeniedException('You do not have permission to create deviations');
  }

  final title = body['title'] as String?;
  final description = body['description'] as String?;
  final severity = body['severity'] as String? ?? 'minor';

  if (title == null || title.isEmpty) {
    throw ValidationException({'title': 'Title is required'});
  }

  // Generate deviation number
  final deviationNumber = await _generateDeviationNumber(supabase, auth.orgId);

  final now = DateTime.now().toUtc().toIso8601String();

  final deviation = await supabase
      .from('deviations')
      .insert({
        'deviation_number': deviationNumber,
        'title': title,
        'description': description,
        'severity': severity,
        'status': 'open',
        'identified_by': auth.employeeId,
        'identified_at': now,
        'organization_id': auth.orgId,
        'created_at': now,
      })
      .select()
      .single();

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'deviation',
    'entity_id': deviation['id'],
    'action': 'DEVIATION_CREATED',
    'event_category': 'QUALITY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({'severity': severity}),
  });

  // Fire training trigger for deviation
  await _fireDeviationTrainingTrigger(supabase, auth.orgId, deviation['id'], severity);

  return ApiResponse.created({'deviation': deviation}).toResponse();
}

/// GET /v1/quality/deviations/:id
Future<Response> deviationGetHandler(Request req) async {
  final deviationId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (deviationId == null) throw ValidationException({'id': 'Deviation ID is required'});

  final deviation = await supabase
      .from('deviations')
      .select('''
        *,
        identifier:employees!deviations_identified_by_fkey (
          id, full_name, employee_number
        ),
        capas:capas!capas_deviation_id_fkey (
          id, capa_number, title, status
        )
      ''')
      .eq('id', deviationId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (deviation == null) throw NotFoundException('Deviation not found');

  return ApiResponse.ok({'deviation': deviation}).toResponse();
}

/// PATCH /v1/quality/deviations/:id
Future<Response> deviationUpdateHandler(Request req) async {
  final deviationId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (deviationId == null) throw ValidationException({'id': 'Deviation ID is required'});

  if (!auth.hasPermission('deviations.update')) {
    throw PermissionDeniedException('You do not have permission to update deviations');
  }

  final allowedFields = ['title', 'description', 'severity', 'status', 'root_cause', 
                         'corrective_action', 'preventive_action'];
  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updates[field] = body[field];
    }
  }

  if (updates['status'] == 'resolved') {
    updates['resolved_at'] = DateTime.now().toUtc().toIso8601String();
    updates['resolved_by'] = auth.employeeId;
  }

  final updated = await supabase
      .from('deviations')
      .update(updates)
      .eq('id', deviationId)
      .eq('organization_id', auth.orgId)
      .select()
      .maybeSingle();

  if (updated == null) throw NotFoundException('Deviation not found');

  return ApiResponse.ok({'deviation': updated}).toResponse();
}

/// POST /v1/quality/deviations/:id/capa
///
/// Links a CAPA to a deviation.
Future<Response> deviationCapaHandler(Request req) async {
  final deviationId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (deviationId == null) throw ValidationException({'id': 'Deviation ID is required'});

  final title = body['title'] as String?;
  final capaType = body['capa_type'] as String? ?? 'corrective';

  if (title == null || title.isEmpty) {
    throw ValidationException({'title': 'CAPA title is required'});
  }

  // Verify deviation exists
  final deviation = await supabase
      .from('deviations')
      .select('id, deviation_number')
      .eq('id', deviationId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (deviation == null) throw NotFoundException('Deviation not found');

  // Generate CAPA number
  final capaNumber = await _generateCapaNumber(supabase, auth.orgId);
  final now = DateTime.now().toUtc().toIso8601String();

  final capa = await supabase
      .from('capas')
      .insert({
        'capa_number': capaNumber,
        'deviation_id': deviationId,
        'title': title,
        'description': body['description'],
        'capa_type': capaType,
        'status': 'open',
        'assigned_to': body['assigned_to'],
        'due_date': body['due_date'],
        'created_by': auth.employeeId,
        'organization_id': auth.orgId,
        'created_at': now,
      })
      .select()
      .single();

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'capa',
    'entity_id': capa['id'],
    'action': 'CAPA_CREATED',
    'event_category': 'QUALITY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({
      'deviation_id': deviationId,
      'capa_type': capaType,
    }),
  });

  return ApiResponse.created({'capa': capa}).toResponse();
}

// Helper functions
Future<String> _generateDeviationNumber(dynamic supabase, String orgId) async {
  final year = DateTime.now().year;
  final result = await supabase
      .from('deviations')
      .select('deviation_number')
      .eq('organization_id', orgId)
      .like('deviation_number', 'DEV-$year-%')
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();

  int nextNum = 1;
  if (result != null) {
    final lastNum = result['deviation_number'] as String;
    final parts = lastNum.split('-');
    if (parts.length == 3) {
      nextNum = (int.tryParse(parts[2]) ?? 0) + 1;
    }
  }

  return 'DEV-$year-${nextNum.toString().padLeft(4, '0')}';
}

Future<String> _generateCapaNumber(dynamic supabase, String orgId) async {
  final year = DateTime.now().year;
  final result = await supabase
      .from('capas')
      .select('capa_number')
      .eq('organization_id', orgId)
      .like('capa_number', 'CAPA-$year-%')
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();

  int nextNum = 1;
  if (result != null) {
    final lastNum = result['capa_number'] as String;
    final parts = lastNum.split('-');
    if (parts.length == 3) {
      nextNum = (int.tryParse(parts[2]) ?? 0) + 1;
    }
  }

  return 'CAPA-$year-${nextNum.toString().padLeft(4, '0')}';
}

/// Fires training trigger for deviation events.
Future<void> _fireDeviationTrainingTrigger(
  dynamic supabase,
  String orgId,
  String deviationId,
  String severity,
) async {
  try {
    await supabase.rpc(
      'process_training_trigger',
      params: {
        'p_event_source': 'deviation',
        'p_entity_id': deviationId,
        'p_org_id': orgId,
        'p_entity_type': 'deviations',
        'p_metadata': {'severity': severity},
      },
    );
  } catch (e) {
    // Log but don't fail the main operation
    // Training trigger failures should not block quality workflows
    print('Warning: Failed to fire deviation training trigger: $e');
  }
}
