import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /jobs/compliance-metrics
///
/// Computes compliance_percent for all employees.
/// G5 Migration: employees.compliance_percent column.
/// Runs every 6 hours via scheduler.
///
/// Formula: (completed + waived) / (completed + waived + overdue + assigned) × 100
/// Waived obligations are excluded from denominator per URS.
Future<Response> complianceMetricsHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final startTime = DateTime.now();

  // Get all employees
  final employees = await supabase
      .from('employees')
      .select('id, organization_id')
      .eq('employment_status', 'active');

  var updated = 0;
  final results = <Map<String, dynamic>>[];

  for (final employee in employees) {
    final employeeId = employee['id'] as String;

    // Count obligations by status
    final completed = await supabase
        .from('employee_assignments')
        .select()
        .eq('employee_id', employeeId)
        .eq('status', 'completed')
        .count();

    final waived = await supabase
        .from('employee_assignments')
        .select()
        .eq('employee_id', employeeId)
        .eq('status', 'waived')
        .count();

    final overdue = await supabase
        .from('employee_assignments')
        .select()
        .eq('employee_id', employeeId)
        .eq('status', 'overdue')
        .count();

    final assigned = await supabase
        .from('employee_assignments')
        .select()
        .eq('employee_id', employeeId)
        .eq('status', 'assigned')
        .count();

    final inProgress = await supabase
        .from('employee_assignments')
        .select()
        .eq('employee_id', employeeId)
        .eq('status', 'in_progress')
        .count();

    // Calculate compliance (waived excluded from denominator)
    final numerator = completed.count + waived.count;
    final denominator = completed.count + overdue.count + assigned.count + inProgress.count;
    
    double compliancePercent = 100.0;
    if (denominator > 0) {
      compliancePercent = (numerator / denominator * 100).clamp(0, 100);
    }

    // Round to 2 decimal places
    compliancePercent = (compliancePercent * 100).round() / 100;

    // Update employee record
    await supabase.from('employees').update({
      'compliance_percent': compliancePercent,
      'compliance_updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', employeeId);

    results.add({
      'employee_id': employeeId,
      'compliance_percent': compliancePercent,
      'completed': completed.count,
      'waived': waived.count,
      'overdue': overdue.count,
      'assigned': assigned.count,
      'in_progress': inProgress.count,
    });

    updated++;
  }

  final duration = DateTime.now().difference(startTime);

  // Calculate org-wide stats
  final totalPercent = results.isEmpty 
      ? 0.0 
      : results.fold<double>(0, (sum, e) => sum + (e['compliance_percent'] as double)) / results.length;

  final criticalCount = results.where((e) => (e['compliance_percent'] as double) < 80).length;

  // Log job execution
  await supabase.from('job_executions').insert({
    'job_name': 'compliance_metrics',
    'started_at': startTime.toUtc().toIso8601String(),
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'status': 'success',
    'result': jsonEncode({
      'employees_updated': updated,
      'avg_compliance': totalPercent.toStringAsFixed(2),
      'critical_count': criticalCount,
    }),
  });

  return ApiResponse.ok({
    'job': 'compliance_metrics',
    'employees_updated': updated,
    'avg_compliance_percent': totalPercent.toStringAsFixed(2),
    'critical_below_80_percent': criticalCount,
    'duration_ms': duration.inMilliseconds,
    'formula': '(completed + waived) / (completed + overdue + assigned + in_progress) × 100',
  }).toResponse();
}
