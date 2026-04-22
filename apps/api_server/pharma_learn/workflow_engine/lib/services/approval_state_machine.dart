import 'package:supabase/supabase.dart';
import 'package:logger/logger.dart';

/// Approval State Machine
///
/// Core FSM for multi-step approval workflows.
/// Reference: plan.md — workflow_engine services
///
/// Flow:
/// 1. Load approval_matrices row for {entity_type, organization_id}
/// 2. Find current approval_steps row where status = 'PENDING' and lowest step_order
/// 3. Mark step APPROVED (with esig_id from event payload)
/// 4. Check if more steps remain → if YES: notify next approver
/// 5. If NO more steps: update entity status to 'EFFECTIVE' + publish approved event
class ApprovalStateMachine {
  final SupabaseClient _supabase;
  final Logger _logger = Logger();

  ApprovalStateMachine(this._supabase);

  /// Initialize approval workflow for an entity.
  /// Seeds approval_steps from the matching approval_matrix.
  /// Returns the number of steps created and matrix info.
  Future<SeedResult> seedApprovalSteps({
    required String entityType,
    required String entityId,
    required String organizationId,
    String? plantId,
  }) async {
    // Call RPC to seed steps (idempotent)
    final result = await _supabase.rpc(
      'seed_approval_steps',
      params: {
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_organization_id': organizationId,
        'p_plant_id': plantId,
      },
    );

    if ((result as List).isEmpty) {
      return SeedResult(
        stepsCreated: 0,
        matrixId: null,
        isSerial: true,
        requiresApproval: false,
      );
    }

    final row = result[0];
    return SeedResult(
      stepsCreated: row['steps_created'] as int? ?? 0,
      matrixId: row['matrix_id'] as String?,
      isSerial: row['is_serial'] as bool? ?? true,
      requiresApproval: row['matrix_id'] != null,
    );
  }

  /// Get the current state of the workflow.
  Future<WorkflowState> getWorkflowState({
    required String entityType,
    required String entityId,
  }) async {
    // Get all steps for this entity
    final steps = await _supabase
        .from('approval_steps')
        .select('''
          id, step_order, step_name, approver_role, status,
          approved_by, approved_at, rejected_by, rejected_at,
          rejection_reason, esignature_id, requires_esig,
          escalation_level, last_escalation_at
        ''')
        .eq('entity_type', entityType)
        .eq('entity_id', entityId)
        .order('step_order');

    if ((steps as List).isEmpty) {
      return WorkflowState(
        entityType: entityType,
        entityId: entityId,
        status: WorkflowStatus.noApprovalRequired,
        steps: [],
        currentStep: null,
        completedSteps: 0,
        totalSteps: 0,
      );
    }

    final stepsList = steps.map((s) => ApprovalStep.fromJson(s)).toList();
    final pendingSteps = stepsList.where((s) => s.status == 'pending').toList();
    final approvedSteps = stepsList.where((s) => s.status == 'approved').toList();
    final rejectedSteps = stepsList.where((s) => s.status == 'rejected').toList();

    WorkflowStatus status;
    ApprovalStep? currentStep;

    if (rejectedSteps.isNotEmpty) {
      status = WorkflowStatus.rejected;
      currentStep = rejectedSteps.first;
    } else if (pendingSteps.isEmpty) {
      status = WorkflowStatus.completed;
      currentStep = null;
    } else {
      status = WorkflowStatus.pending;
      currentStep = pendingSteps.first;
    }

    return WorkflowState(
      entityType: entityType,
      entityId: entityId,
      status: status,
      steps: stepsList,
      currentStep: currentStep,
      completedSteps: approvedSteps.length,
      totalSteps: stepsList.length,
    );
  }

  /// Approve the current pending step.
  /// Returns the updated workflow state.
  Future<ApprovalResult> approveStep({
    required String stepId,
    required String approverId,
    String? esignatureId,
    String? comments,
  }) async {
    // Get the step
    final stepData = await _supabase
        .from('approval_steps')
        .select('*, entity_type, entity_id')
        .eq('id', stepId)
        .single();

    final step = ApprovalStep.fromJson(stepData);

    // Validate step is pending
    if (step.status != 'pending') {
      return ApprovalResult(
        success: false,
        error: 'Step is not pending (current status: ${step.status})',
        errorCode: 'step_not_pending',
      );
    }

    // Check if e-signature is required but not provided
    if (step.requiresEsig && esignatureId == null) {
      return ApprovalResult(
        success: false,
        error: 'E-signature is required for this approval step',
        errorCode: 'esig_required',
      );
    }

    // Update the step
    await _supabase.from('approval_steps').update({
      'status': 'approved',
      'approved_by': approverId,
      'approved_at': DateTime.now().toUtc().toIso8601String(),
      'esignature_id': esignatureId,
      'comments': comments,
    }).eq('id', stepId);

    // Log audit trail
    await _logAuditTrail(
      entityType: stepData['entity_type'],
      entityId: stepData['entity_id'],
      action: 'APPROVE_STEP',
      performedBy: approverId,
      details: {
        'step_id': stepId,
        'step_name': step.stepName,
        'step_order': step.stepOrder,
        'esignature_id': esignatureId,
      },
    );

    // Get updated workflow state
    final state = await getWorkflowState(
      entityType: stepData['entity_type'],
      entityId: stepData['entity_id'],
    );

    return ApprovalResult(
      success: true,
      workflowState: state,
      nextStep: state.currentStep,
      isComplete: state.status == WorkflowStatus.completed,
    );
  }

  /// Reject the workflow at the current step.
  Future<ApprovalResult> rejectWorkflow({
    required String stepId,
    required String rejectorId,
    required String reason,
    String? esignatureId,
  }) async {
    // Get the step
    final stepData = await _supabase
        .from('approval_steps')
        .select('*, entity_type, entity_id')
        .eq('id', stepId)
        .single();

    final step = ApprovalStep.fromJson(stepData);

    // Validate step is pending
    if (step.status != 'pending') {
      return ApprovalResult(
        success: false,
        error: 'Step is not pending (current status: ${step.status})',
        errorCode: 'step_not_pending',
      );
    }

    // Update the step
    await _supabase.from('approval_steps').update({
      'status': 'rejected',
      'rejected_by': rejectorId,
      'rejected_at': DateTime.now().toUtc().toIso8601String(),
      'rejection_reason': reason,
      'esignature_id': esignatureId,
    }).eq('id', stepId);

    // Cancel remaining steps
    await _supabase
        .from('approval_steps')
        .update({'status': 'cancelled'})
        .eq('entity_type', stepData['entity_type'])
        .eq('entity_id', stepData['entity_id'])
        .eq('status', 'waiting');

    // Update entity status
    await _updateEntityStatus(
      entityType: stepData['entity_type'],
      entityId: stepData['entity_id'],
      status: 'rejected',
    );

    // Log audit trail
    await _logAuditTrail(
      entityType: stepData['entity_type'],
      entityId: stepData['entity_id'],
      action: 'REJECT_WORKFLOW',
      performedBy: rejectorId,
      details: {
        'step_id': stepId,
        'step_name': step.stepName,
        'reason': reason,
      },
    );

    final state = await getWorkflowState(
      entityType: stepData['entity_type'],
      entityId: stepData['entity_id'],
    );

    return ApprovalResult(
      success: true,
      workflowState: state,
      isComplete: true,
      wasRejected: true,
    );
  }

  /// Complete the workflow after all steps are approved.
  Future<void> completeWorkflow({
    required String entityType,
    required String entityId,
    required String organizationId,
  }) async {
    // Verify all steps are approved
    final state = await getWorkflowState(
      entityType: entityType,
      entityId: entityId,
    );

    if (state.status != WorkflowStatus.completed) {
      throw StateError('Cannot complete workflow - not all steps approved');
    }

    // Update entity to effective/approved status
    await _updateEntityStatus(
      entityType: entityType,
      entityId: entityId,
      status: 'effective',
    );

    // Log audit trail
    await _logAuditTrail(
      entityType: entityType,
      entityId: entityId,
      action: 'COMPLETE_WORKFLOW',
      performedBy: 'system',
      details: {
        'total_steps': state.totalSteps,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    _logger.i('Workflow completed: $entityType/$entityId');
  }

  /// Escalate a step that has exceeded its SLA.
  Future<void> escalateStep({
    required String stepId,
  }) async {
    final stepData = await _supabase
        .from('approval_steps')
        .select()
        .eq('id', stepId)
        .single();

    final currentLevel = stepData['escalation_level'] as int? ?? 0;

    await _supabase.from('approval_steps').update({
      'escalation_level': currentLevel + 1,
      'last_escalation_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', stepId);

    // Log escalation
    await _logAuditTrail(
      entityType: stepData['entity_type'],
      entityId: stepData['entity_id'],
      action: 'ESCALATE_STEP',
      performedBy: 'system',
      details: {
        'step_id': stepId,
        'new_escalation_level': currentLevel + 1,
      },
    );
  }

  /// Get pending steps for a specific approver role.
  Future<List<Map<String, dynamic>>> getPendingStepsForRole({
    required String approverRole,
    required String organizationId,
  }) async {
    final steps = await _supabase
        .from('approval_steps')
        .select('''
          id, step_order, step_name, entity_type, entity_id,
          created_at, escalation_level
        ''')
        .eq('approver_role', approverRole)
        .eq('status', 'pending')
        .order('escalation_level', ascending: false) // Escalated first
        .order('created_at');

    return List<Map<String, dynamic>>.from(steps as List);
  }

  /// Update entity status based on workflow outcome.
  Future<void> _updateEntityStatus({
    required String entityType,
    required String entityId,
    required String status,
  }) async {
    final table = _getTableForEntityType(entityType);
    final statusField = status == 'effective' ? 'effective' : status;
    final now = DateTime.now().toUtc().toIso8601String();

    final updates = <String, dynamic>{'status': statusField};

    if (status == 'effective') {
      updates['effective_at'] = now;
      updates['approved_at'] = now;
    } else if (status == 'rejected') {
      updates['rejected_at'] = now;
    }

    await _supabase.from(table).update(updates).eq('id', entityId);
  }

  String _getTableForEntityType(String entityType) {
    switch (entityType) {
      case 'document':
        return 'documents';
      case 'course':
        return 'courses';
      case 'curriculum':
        return 'curricula';
      case 'gtp':
        return 'group_training_plans';
      case 'question_paper':
        return 'question_papers';
      case 'trainer':
        return 'trainers';
      case 'schedule':
        return 'training_schedules';
      default:
        return '${entityType}s'; // Naive pluralization
    }
  }

  Future<void> _logAuditTrail({
    required String entityType,
    required String entityId,
    required String action,
    required String performedBy,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _supabase.from('audit_trails').insert({
        'entity_type': entityType,
        'entity_id': entityId,
        'action': action,
        'performed_by': performedBy,
        'details': details,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      _logger.e('Failed to log audit trail: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Data Classes
// ---------------------------------------------------------------------------

class SeedResult {
  final int stepsCreated;
  final String? matrixId;
  final bool isSerial;
  final bool requiresApproval;

  SeedResult({
    required this.stepsCreated,
    required this.matrixId,
    required this.isSerial,
    required this.requiresApproval,
  });
}

enum WorkflowStatus {
  noApprovalRequired,
  pending,
  completed,
  rejected,
}

class WorkflowState {
  final String entityType;
  final String entityId;
  final WorkflowStatus status;
  final List<ApprovalStep> steps;
  final ApprovalStep? currentStep;
  final int completedSteps;
  final int totalSteps;

  WorkflowState({
    required this.entityType,
    required this.entityId,
    required this.status,
    required this.steps,
    required this.currentStep,
    required this.completedSteps,
    required this.totalSteps,
  });

  double get progressPercent =>
      totalSteps > 0 ? (completedSteps / totalSteps) * 100 : 100;

  bool get isComplete => status == WorkflowStatus.completed;
  bool get isRejected => status == WorkflowStatus.rejected;
  bool get isPending => status == WorkflowStatus.pending;
}

class ApprovalStep {
  final String id;
  final int stepOrder;
  final String stepName;
  final String approverRole;
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String? esignatureId;
  final bool requiresEsig;
  final int escalationLevel;
  final DateTime? lastEscalationAt;

  ApprovalStep({
    required this.id,
    required this.stepOrder,
    required this.stepName,
    required this.approverRole,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionReason,
    this.esignatureId,
    required this.requiresEsig,
    required this.escalationLevel,
    this.lastEscalationAt,
  });

  factory ApprovalStep.fromJson(Map<String, dynamic> json) {
    return ApprovalStep(
      id: json['id'] as String,
      stepOrder: json['step_order'] as int,
      stepName: json['step_name'] as String,
      approverRole: json['approver_role'] as String,
      status: json['status'] as String,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'])
          : null,
      rejectedBy: json['rejected_by'] as String?,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.parse(json['rejected_at'])
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      esignatureId: json['esignature_id'] as String?,
      requiresEsig: json['requires_esig'] as bool? ?? false,
      escalationLevel: json['escalation_level'] as int? ?? 0,
      lastEscalationAt: json['last_escalation_at'] != null
          ? DateTime.parse(json['last_escalation_at'])
          : null,
    );
  }
}

class ApprovalResult {
  final bool success;
  final String? error;
  final String? errorCode;
  final WorkflowState? workflowState;
  final ApprovalStep? nextStep;
  final bool isComplete;
  final bool wasRejected;

  ApprovalResult({
    required this.success,
    this.error,
    this.errorCode,
    this.workflowState,
    this.nextStep,
    this.isComplete = false,
    this.wasRejected = false,
  });
}
