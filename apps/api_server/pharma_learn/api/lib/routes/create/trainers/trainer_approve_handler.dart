import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/trainers/:id/approve [esig]
///
/// Approves a trainer qualification.
Future<Response> trainerApproveHandler(Request req) async {
  final trainerId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final esig = RequestContext.esig;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (trainerId == null) throw ValidationException({'id': 'Trainer ID is required'});

  if (!auth.hasPermission('trainers.approve')) {
    throw PermissionDeniedException('You do not have permission to approve trainers');
  }

  // Verify trainer exists and is pending
  final trainer = await supabase
      .from('trainers')
      .select('id, status, employee_id')
      .eq('id', trainerId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (trainer == null) throw NotFoundException('Trainer not found');
  if (trainer['status'] != 'pending') {
    throw ConflictException('Trainer is not pending approval');
  }

  // Create e-signature
  final esigId = await EsigService(supabase).createEsignature(
    employeeId: auth.employeeId,
    meaning: 'TRAINER_APPROVE',
    entityType: 'trainer',
    entityId: trainerId,
    reauthSessionId: esig?.reauthSessionId,
    reason: body['reason'] as String?,
  );

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase.from('trainers').update({
    'status': 'approved',
    'approved_by': auth.employeeId,
    'approved_at': now,
    'esignature_id': esigId,
  }).eq('id', trainerId);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'trainer',
    'entity_id': trainerId,
    'action': 'TRAINER_APPROVED',
    'event_category': 'TRAINING',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({'esignature_id': esigId}),
  });

  return ApiResponse.ok({
    'message': 'Trainer approved successfully',
    'trainer_id': trainerId,
    'esignature_id': esigId,
  }).toResponse();
}

/// GET /v1/trainers/:id/certifications
///
/// Lists trainer certifications.
Future<Response> trainerCertificationsListHandler(Request req) async {
  final trainerId = req.rawPathParameters[#id];
  // auth not needed for public read
  final supabase = RequestContext.supabase;

  if (trainerId == null) throw ValidationException({'id': 'Trainer ID is required'});

  final certifications = await supabase
      .from('trainer_certifications')
      .select('id, certification_name, issued_by, issued_date, expiry_date, status, document_url')
      .eq('trainer_id', trainerId)
      .order('expiry_date', ascending: false);

  return ApiResponse.ok({'certifications': certifications}).toResponse();
}

/// POST /v1/trainers/:id/certifications
///
/// Adds a certification to a trainer.
Future<Response> trainerCertificationAddHandler(Request req) async {
  final trainerId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (trainerId == null) throw ValidationException({'id': 'Trainer ID is required'});

  if (!auth.hasPermission('trainers.manage')) {
    throw PermissionDeniedException('You do not have permission to manage trainer certifications');
  }

  final certName = body['certification_name'] as String?;
  if (certName == null || certName.isEmpty) {
    throw ValidationException({'certification_name': 'Certification name is required'});
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final cert = await supabase
      .from('trainer_certifications')
      .insert({
        'trainer_id': trainerId,
        'certification_name': certName,
        'issued_by': body['issued_by'],
        'issued_date': body['issued_date'],
        'expiry_date': body['expiry_date'],
        'status': 'active',
        'document_url': body['document_url'],
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  return ApiResponse.created({'certification': cert}).toResponse();
}
