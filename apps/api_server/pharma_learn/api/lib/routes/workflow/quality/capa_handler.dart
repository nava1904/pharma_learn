import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/quality/capas
Future<Response> capasListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;
  final status = req.url.queryParameters['status'];
  final offset = (page - 1) * perPage;

  var query = supabase
      .from('capas')
      .select('''
        id, capa_number, title, description, capa_type, status,
        due_date, completed_at, created_at,
        deviation:deviations!capas_deviation_id_fkey (
          id, deviation_number, title
        ),
        assignee:employees!capas_assigned_to_fkey (
          id, full_name, employee_number
        )
      ''')
      .eq('organization_id', auth.orgId);

  if (status != null && status.isNotEmpty) {
    query = query.eq('status', status);
  }

  final capas = await query
      .order('due_date', ascending: true)
      .range(offset, offset + perPage - 1);

  return ApiResponse.ok({'capas': capas}).toResponse();
}

/// POST /v1/quality/capas
Future<Response> capaCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (!auth.hasPermission('capas.create')) {
    throw PermissionDeniedException('You do not have permission to create CAPAs');
  }

  final title = body['title'] as String?;
  final capaType = body['capa_type'] as String? ?? 'corrective';

  if (title == null || title.isEmpty) {
    throw ValidationException({'title': 'Title is required'});
  }

  final year = DateTime.now().year;
  final capaNumber = 'CAPA-$year-${DateTime.now().millisecondsSinceEpoch}';
  final now = DateTime.now().toUtc().toIso8601String();

  final capa = await supabase
      .from('capas')
      .insert({
        'capa_number': capaNumber,
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

  // Fire training trigger for CAPA
  await _fireCapaTrainingTrigger(supabase, auth.orgId, capa['id'], capaType);

  return ApiResponse.created({'capa': capa}).toResponse();
}

/// GET /v1/quality/capas/:id
Future<Response> capaGetHandler(Request req) async {
  final capaId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (capaId == null) throw ValidationException({'id': 'CAPA ID is required'});

  final capa = await supabase
      .from('capas')
      .select('''
        *,
        deviation:deviations!capas_deviation_id_fkey (
          id, deviation_number, title, status
        ),
        assignee:employees!capas_assigned_to_fkey (
          id, full_name, employee_number
        ),
        closer:employees!capas_closed_by_fkey (
          id, full_name, employee_number
        )
      ''')
      .eq('id', capaId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (capa == null) throw NotFoundException('CAPA not found');

  return ApiResponse.ok({'capa': capa}).toResponse();
}

/// PATCH /v1/quality/capas/:id
Future<Response> capaUpdateHandler(Request req) async {
  final capaId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (capaId == null) throw ValidationException({'id': 'CAPA ID is required'});

  if (!auth.hasPermission('capas.update')) {
    throw PermissionDeniedException('You do not have permission to update CAPAs');
  }

  final allowedFields = ['title', 'description', 'capa_type', 'status', 
                         'assigned_to', 'due_date', 'root_cause_analysis',
                         'action_taken', 'effectiveness_check'];
  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updates[field] = body[field];
    }
  }

  final updated = await supabase
      .from('capas')
      .update(updates)
      .eq('id', capaId)
      .eq('organization_id', auth.orgId)
      .select()
      .maybeSingle();

  if (updated == null) throw NotFoundException('CAPA not found');

  return ApiResponse.ok({'capa': updated}).toResponse();
}

/// POST /v1/quality/capas/:id/close [esig]
///
/// Closes a CAPA with e-signature.
/// Requires effectiveness check completed.
Future<Response> capaCloseHandler(Request req) async {
  final capaId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final esig = RequestContext.esig;

  if (capaId == null) throw ValidationException({'id': 'CAPA ID is required'});

  // Verify CAPA exists and is not already closed
  final capa = await supabase
      .from('capas')
      .select('id, status, effectiveness_check')
      .eq('id', capaId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (capa == null) throw NotFoundException('CAPA not found');
  if (capa['status'] == 'closed') {
    throw ConflictException('CAPA is already closed');
  }
  if (capa['effectiveness_check'] == null) {
    throw ValidationException({'effectiveness_check': 'Effectiveness check must be completed before closing'});
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Create e-signature
  final esigId = await EsigService(supabase).createEsignature(
    employeeId: auth.employeeId,
    meaning: 'CAPA_CLOSE',
    entityType: 'capa',
    entityId: capaId,
    reauthSessionId: esig?.reauthSessionId,
    reason: body['closure_reason'] as String? ?? 'CAPA objectives achieved',
  );

  // Close the CAPA
  await supabase
      .from('capas')
      .update({
        'status': 'closed',
        'closed_by': auth.employeeId,
        'closed_at': now,
        'esignature_id': esigId,
        'closure_summary': body['closure_summary'],
      })
      .eq('id', capaId);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'capa',
    'entity_id': capaId,
    'action': 'CAPA_CLOSED',
    'event_category': 'QUALITY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({
      'esignature_id': esigId,
      'closure_reason': body['closure_reason'],
    }),
  });

  return ApiResponse.ok({
    'message': 'CAPA closed successfully',
    'capa_id': capaId,
    'esignature_id': esigId,
    'closed_at': now,
  }).toResponse();
}

/// Fires training trigger for CAPA events.
Future<void> _fireCapaTrainingTrigger(
  dynamic supabase,
  String orgId,
  String capaId,
  String capaType,
) async {
  try {
    await supabase.rpc(
      'process_training_trigger',
      params: {
        'p_event_source': 'capa',
        'p_entity_id': capaId,
        'p_org_id': orgId,
        'p_entity_type': 'capa_records',
        'p_metadata': {'capa_type': capaType},
      },
    );
  } catch (e) {
    // Log but don't fail the main operation
    print('Warning: Failed to fire CAPA training trigger: $e');
  }
}
