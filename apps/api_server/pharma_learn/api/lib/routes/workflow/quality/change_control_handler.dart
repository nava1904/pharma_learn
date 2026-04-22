import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/quality/change-controls
/// 
/// Lists change controls for the organization.
/// ICH Q10 §3.2.4 - Change management system requirements.
Future<Response> changeControlsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;
  final status = req.url.queryParameters['status'];
  final changeType = req.url.queryParameters['change_type'];
  final offset = (page - 1) * perPage;

  var query = supabase
      .from('change_controls')
      .select('''
        id, change_number, title, description, change_type, 
        impact_assessment, risk_level, status,
        initiated_by, initiated_at, implemented_at, closed_at,
        created_at, updated_at,
        initiator:employees!change_controls_initiated_by_fkey (
          id, full_name, employee_number
        )
      ''')
      .eq('organization_id', auth.orgId);

  if (status != null && status.isNotEmpty) {
    query = query.eq('status', status);
  }
  if (changeType != null && changeType.isNotEmpty) {
    query = query.eq('change_type', changeType);
  }

  final changeControls = await query
      .order('created_at', ascending: false)
      .range(offset, offset + perPage - 1);

  return ApiResponse.ok({'change_controls': changeControls}).toResponse();
}

/// POST /v1/quality/change-controls
///
/// Initiates a new change control.
/// WHO GMP §1.4.14 - Changes must be documented, evaluated, and approved.
Future<Response> changeControlCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (!auth.hasPermission('change_controls.create')) {
    throw PermissionDeniedException('You do not have permission to create change controls');
  }

  final title = body['title'] as String?;
  final description = body['description'] as String?;
  final changeType = body['change_type'] as String? ?? 'minor';
  final impactAssessment = body['impact_assessment'] as String?;
  final riskLevel = body['risk_level'] as String? ?? 'low';
  final affectedEntities = body['affected_entities'] as List<dynamic>?;

  if (title == null || title.isEmpty) {
    throw ValidationException({'title': 'Title is required'});
  }
  if (description == null || description.isEmpty) {
    throw ValidationException({'description': 'Description is required'});
  }

  // Validate change type
  const validChangeTypes = ['minor', 'major', 'critical', 'emergency'];
  if (!validChangeTypes.contains(changeType)) {
    throw ValidationException({
      'change_type': 'Must be one of: ${validChangeTypes.join(', ')}'
    });
  }

  // Validate risk level
  const validRiskLevels = ['low', 'medium', 'high', 'critical'];
  if (!validRiskLevels.contains(riskLevel)) {
    throw ValidationException({
      'risk_level': 'Must be one of: ${validRiskLevels.join(', ')}'
    });
  }

  // Generate change control number
  final changeNumber = await _generateChangeNumber(supabase, auth.orgId);

  final now = DateTime.now().toUtc().toIso8601String();

  final changeControl = await supabase
      .from('change_controls')
      .insert({
        'change_number': changeNumber,
        'title': title,
        'description': description,
        'change_type': changeType,
        'impact_assessment': impactAssessment,
        'risk_level': riskLevel,
        'status': 'initiated',
        'initiated_by': auth.employeeId,
        'initiated_at': now,
        'affected_entities': affectedEntities != null 
            ? jsonEncode(affectedEntities) 
            : null,
        'organization_id': auth.orgId,
        'created_at': now,
      })
      .select()
      .single();

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'change_control',
    'entity_id': changeControl['id'],
    'action': 'CHANGE_CONTROL_INITIATED',
    'event_category': 'QUALITY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({
      'change_type': changeType,
      'risk_level': riskLevel,
    }),
  });

  // Publish event for approval workflow
  await EventPublisher.publish(
    supabase,
    eventType: 'change_control.submitted',
    aggregateType: 'change_control',
    aggregateId: changeControl['id'] as String,
    orgId: auth.orgId,
    payload: {
      'change_type': changeType,
      'risk_level': riskLevel,
    },
  );

  return ApiResponse.created({'change_control': changeControl}).toResponse();
}

/// GET /v1/quality/change-controls/:id
Future<Response> changeControlGetHandler(Request req) async {
  final changeControlId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (changeControlId == null) {
    throw ValidationException({'id': 'Change control ID is required'});
  }

  final changeControl = await supabase
      .from('change_controls')
      .select('''
        *,
        initiator:employees!change_controls_initiated_by_fkey (
          id, full_name, employee_number
        ),
        approval_steps:approval_steps!approval_steps_entity_id_fkey (
          id, step_name, status, approved_by, approved_at, rejection_reason
        )
      ''')
      .eq('id', changeControlId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (changeControl == null) {
    throw NotFoundException('Change control not found');
  }

  return ApiResponse.ok({'change_control': changeControl}).toResponse();
}

/// PATCH /v1/quality/change-controls/:id
/// 
/// Updates a change control (only in certain statuses).
Future<Response> changeControlUpdateHandler(Request req) async {
  final changeControlId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (changeControlId == null) {
    throw ValidationException({'id': 'Change control ID is required'});
  }

  if (!auth.hasPermission('change_controls.update')) {
    throw PermissionDeniedException('You do not have permission to update change controls');
  }

  // Get current change control
  final current = await supabase
      .from('change_controls')
      .select('status, initiated_by')
      .eq('id', changeControlId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (current == null) {
    throw NotFoundException('Change control not found');
  }

  // Can only update in initiated or under_review status
  final editableStatuses = ['initiated', 'under_review', 'pending_approval'];
  if (!editableStatuses.contains(current['status'])) {
    throw ConflictException(
      'Cannot update change control in status: ${current['status']}'
    );
  }

  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  // Allowed fields to update
  final allowedFields = [
    'title', 'description', 'impact_assessment', 
    'risk_level', 'affected_entities', 'implementation_plan'
  ];

  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      if (field == 'affected_entities' && body[field] is List) {
        updates[field] = jsonEncode(body[field]);
      } else {
        updates[field] = body[field];
      }
    }
  }

  final updated = await supabase
      .from('change_controls')
      .update(updates)
      .eq('id', changeControlId)
      .select()
      .single();

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'change_control',
    'entity_id': changeControlId,
    'action': 'CHANGE_CONTROL_UPDATED',
    'event_category': 'QUALITY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode(updates),
  });

  return ApiResponse.ok({'change_control': updated}).toResponse();
}

/// POST /v1/quality/change-controls/:id/implement
/// 
/// Marks change control as implemented (requires e-signature).
/// 21 CFR §11.50 - Signatures linked to respective electronic records.
Future<Response> changeControlImplementHandler(Request req) async {
  final changeControlId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final esig = RequestContext.esig;

  if (changeControlId == null) {
    throw ValidationException({'id': 'Change control ID is required'});
  }

  if (!auth.hasPermission('change_controls.implement')) {
    throw PermissionDeniedException('You do not have permission to implement change controls');
  }

  // Get current change control
  final current = await supabase
      .from('change_controls')
      .select('status, change_number, title')
      .eq('id', changeControlId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (current == null) {
    throw NotFoundException('Change control not found');
  }

  if (current['status'] != 'approved') {
    throw ConflictException(
      'Can only implement approved change controls. Current status: ${current['status']}'
    );
  }

  final implementationNotes = body['implementation_notes'] as String?;
  final now = DateTime.now().toUtc();

  // Update change control
  final updated = await supabase
      .from('change_controls')
      .update({
        'status': 'implemented',
        'implemented_at': now.toIso8601String(),
        'implemented_by': auth.employeeId,
        'implementation_notes': implementationNotes,
        'updated_at': now.toIso8601String(),
      })
      .eq('id', changeControlId)
      .select()
      .single();

  // Store e-signature
  await supabase.from('esignatures').insert({
    'entity_type': 'change_control',
    'entity_id': changeControlId,
    'action': 'implement',
    'signed_by': auth.employeeId,
    'signed_at': now.toIso8601String(),
    'reauth_session_id': esig?.reauthSessionId,
    'meaning': 'I confirm this change control has been implemented as planned',
    'organization_id': auth.orgId,
  });

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'change_control',
    'entity_id': changeControlId,
    'action': 'CHANGE_CONTROL_IMPLEMENTED',
    'event_category': 'QUALITY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'esignature_id': esig?.reauthSessionId,
    'details': jsonEncode({
      'implementation_notes': implementationNotes,
    }),
  });

  // Publish event
  await EventPublisher.publish(
    supabase,
    eventType: 'change_control.implemented',
    aggregateType: 'change_control',
    aggregateId: changeControlId,
    orgId: auth.orgId,
    payload: {
      'change_number': current['change_number'],
      'implemented_by': auth.employeeId,
    },
  );

  return ApiResponse.ok({'change_control': updated}).toResponse();
}

/// POST /v1/quality/change-controls/:id/close
/// 
/// Closes a change control after effectiveness check (requires e-signature).
Future<Response> changeControlCloseHandler(Request req) async {
  final changeControlId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final esig = RequestContext.esig;

  if (changeControlId == null) {
    throw ValidationException({'id': 'Change control ID is required'});
  }

  if (!auth.hasPermission('change_controls.close')) {
    throw PermissionDeniedException('You do not have permission to close change controls');
  }

  // Get current change control
  final current = await supabase
      .from('change_controls')
      .select('status, change_number')
      .eq('id', changeControlId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (current == null) {
    throw NotFoundException('Change control not found');
  }

  if (current['status'] != 'implemented') {
    throw ConflictException(
      'Can only close implemented change controls. Current status: ${current['status']}'
    );
  }

  final effectivenessNotes = body['effectiveness_notes'] as String?;
  final effectivenessVerified = body['effectiveness_verified'] as bool? ?? false;

  if (!effectivenessVerified) {
    throw ValidationException({
      'effectiveness_verified': 'Effectiveness must be verified before closing'
    });
  }

  final now = DateTime.now().toUtc();

  // Update change control
  final updated = await supabase
      .from('change_controls')
      .update({
        'status': 'closed',
        'closed_at': now.toIso8601String(),
        'closed_by': auth.employeeId,
        'effectiveness_notes': effectivenessNotes,
        'effectiveness_verified': effectivenessVerified,
        'updated_at': now.toIso8601String(),
      })
      .eq('id', changeControlId)
      .select()
      .single();

  // Store e-signature
  await supabase.from('esignatures').insert({
    'entity_type': 'change_control',
    'entity_id': changeControlId,
    'action': 'close',
    'signed_by': auth.employeeId,
    'signed_at': now.toIso8601String(),
    'reauth_session_id': esig?.reauthSessionId,
    'meaning': 'I confirm this change control has been verified as effective and is now closed',
    'organization_id': auth.orgId,
  });

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'change_control',
    'entity_id': changeControlId,
    'action': 'CHANGE_CONTROL_CLOSED',
    'event_category': 'QUALITY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'esignature_id': esig?.reauthSessionId,
    'details': jsonEncode({
      'effectiveness_notes': effectivenessNotes,
      'effectiveness_verified': effectivenessVerified,
    }),
  });

  // Publish event
  await EventPublisher.publish(
    supabase,
    eventType: 'change_control.closed',
    aggregateType: 'change_control',
    aggregateId: changeControlId,
    orgId: auth.orgId,
    payload: {
      'change_number': current['change_number'],
      'closed_by': auth.employeeId,
    },
  );

  return ApiResponse.ok({'change_control': updated}).toResponse();
}

/// Generates a unique change control number (CC-YYYY-NNNN format).
Future<String> _generateChangeNumber(dynamic supabase, String orgId) async {
  final year = DateTime.now().year;
  final prefix = 'CC-$year-';
  
  final lastRecord = await supabase
      .from('change_controls')
      .select('change_number')
      .eq('organization_id', orgId)
      .like('change_number', '$prefix%')
      .order('change_number', ascending: false)
      .limit(1)
      .maybeSingle();
  
  if (lastRecord != null) {
    final lastNumber = lastRecord['change_number'] as String;
    final sequence = int.tryParse(lastNumber.split('-').last) ?? 0;
    return '$prefix${(sequence + 1).toString().padLeft(4, '0')}';
  }
  
  return '${prefix}0001';
}
