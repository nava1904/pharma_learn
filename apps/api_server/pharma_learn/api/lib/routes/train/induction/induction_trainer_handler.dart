import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/induction/:id/trainer-respond
///
/// Trainer accepts or declines induction assignment.
/// Body: { accepted: bool, notes? }
Future<Response> inductionTrainerRespondHandler(Request req) async {
  final inductionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (inductionId == null || inductionId.isEmpty) {
    throw ValidationException({'id': 'Induction ID is required'});
  }

  final accepted = body['accepted'] as bool?;
  if (accepted == null) {
    throw ValidationException({'accepted': 'Must specify whether accepted or declined'});
  }

  final notes = body['notes'] as String?;

  // Get induction
  final induction = await supabase
      .from('employee_induction')
      .select('''
        id, trainer_id, trainer_confirmed, status,
        employee:employees!employee_induction_employee_id_fkey(
          id, first_name, last_name
        )
      ''')
      .eq('id', inductionId)
      .maybeSingle();

  if (induction == null) {
    throw NotFoundException('Induction not found');
  }

  // Verify requester is the assigned trainer
  if (induction['trainer_id'] != auth.employeeId) {
    throw PermissionDeniedException('You are not the assigned trainer for this induction');
  }

  if (induction['trainer_confirmed'] == true) {
    throw ConflictException('You have already responded to this assignment');
  }

  if (accepted) {
    // Accept assignment
    await supabase
        .from('employee_induction')
        .update({
          'trainer_confirmed': true,
          'trainer_confirmed_at': DateTime.now().toUtc().toIso8601String(),
          'trainer_notes': notes,
          'status': 'in_progress', // Move to in_progress when trainer accepts
        })
        .eq('id', inductionId);

    await OutboxService(supabase).publish(
      aggregateType: 'employee_induction',
      aggregateId: inductionId,
      eventType: 'induction.trainer_accepted',
      payload: {
        'trainer_id': auth.employeeId,
        'employee_id': induction['employee']?['id'],
      },
    );

    // Notify employee
    await supabase.functions.invoke('send-notification', body: {
      'employee_id': induction['employee']?['id'],
      'template_key': 'induction_trainer_confirmed',
      'data': {
        'induction_id': inductionId,
        'trainer_id': auth.employeeId,
      },
    });

    return ApiResponse.ok({
      'message': 'Induction assignment accepted',
      'status': 'in_progress',
    }).toResponse();
  } else {
    // Decline assignment - clear trainer and notify coordinator
    await supabase
        .from('employee_induction')
        .update({
          'trainer_id': null,
          'trainer_confirmed': false,
          'trainer_decline_reason': notes,
          'trainer_declined_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', inductionId);

    await OutboxService(supabase).publish(
      aggregateType: 'employee_induction',
      aggregateId: inductionId,
      eventType: 'induction.trainer_declined',
      payload: {
        'trainer_id': auth.employeeId,
        'reason': notes,
      },
    );

    return ApiResponse.ok({
      'message': 'Induction assignment declined. A new trainer will need to be assigned.',
      'trainer_reassignment_required': true,
    }).toResponse();
  }
}

/// GET /v1/train/induction/trainer/pending
///
/// Trainer views their pending induction assignments.
Future<Response> inductionTrainerPendingHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final inductions = await supabase
      .from('employee_induction')
      .select('''
        id, start_date, status, trainer_confirmed,
        employee:employees!employee_induction_employee_id_fkey(
          id, first_name, last_name, email, department_id,
          departments(id, name)
        ),
        induction_template:induction_templates(
          id, name
        )
      ''')
      .eq('trainer_id', auth.employeeId)
      .inFilter('status', ['pending', 'in_progress'])
      .order('start_date', ascending: true);

  // Separate into pending response and in-progress
  final pendingResponse = (inductions as List)
      .where((i) => i['trainer_confirmed'] != true)
      .toList();
  final inProgress = inductions
      .where((i) => i['trainer_confirmed'] == true && i['status'] == 'in_progress')
      .toList();

  return ApiResponse.ok({
    'pending_response': pendingResponse,
    'in_progress': inProgress,
    'summary': {
      'awaiting_response': pendingResponse.length,
      'active_inductions': inProgress.length,
    },
  }).toResponse();
}

/// POST /v1/train/induction/:id/trainer-reassign
///
/// Coordinator reassigns induction to a different trainer.
/// Body: { trainer_id }
Future<Response> inductionTrainerReassignHandler(Request req) async {
  final inductionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to reassign trainers');
  }

  if (inductionId == null || inductionId.isEmpty) {
    throw ValidationException({'id': 'Induction ID is required'});
  }

  final newTrainerId = requireUuid(body, 'trainer_id');

  // Get induction
  final induction = await supabase
      .from('employee_induction')
      .select('id, trainer_id, status')
      .eq('id', inductionId)
      .maybeSingle();

  if (induction == null) {
    throw NotFoundException('Induction not found');
  }

  if (induction['status'] == 'completed') {
    throw ConflictException('Cannot reassign trainer for completed induction');
  }

  // Verify new trainer exists
  final trainer = await supabase
      .from('employees')
      .select('id')
      .eq('id', newTrainerId)
      .maybeSingle();

  if (trainer == null) {
    throw NotFoundException('New trainer not found');
  }

  final oldTrainerId = induction['trainer_id'];

  await supabase
      .from('employee_induction')
      .update({
        'trainer_id': newTrainerId,
        'trainer_confirmed': false,
        'previous_trainer_id': oldTrainerId,
        'reassigned_at': DateTime.now().toUtc().toIso8601String(),
        'reassigned_by': auth.employeeId,
      })
      .eq('id', inductionId);

  // Notify new trainer
  await supabase.functions.invoke('send-notification', body: {
    'employee_id': newTrainerId,
    'template_key': 'induction_trainer_assigned',
    'data': {
      'induction_id': inductionId,
    },
  });

  await OutboxService(supabase).publish(
    aggregateType: 'employee_induction',
    aggregateId: inductionId,
    eventType: 'induction.trainer_reassigned',
    payload: {
      'old_trainer_id': oldTrainerId,
      'new_trainer_id': newTrainerId,
      'reassigned_by': auth.employeeId,
    },
  );

  return ApiResponse.ok({
    'message': 'Trainer reassigned successfully',
    'new_trainer_id': newTrainerId,
  }).toResponse();
}
