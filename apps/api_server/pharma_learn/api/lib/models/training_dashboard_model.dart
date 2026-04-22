/// Training dashboard model for the employee's personal training view.
/// 
/// Used by: GET /v1/train/me/dashboard
/// Reference: EE §5.1.7 - graphical progress display
class TrainingDashboardModel {
  /// Overall completion percentage across all assigned training
  final double overallCompletionPercent;

  /// Count of pending training obligations
  final int pendingCount;

  /// Count of overdue training obligations
  final int overdueCount;

  /// Count of completed training in current period
  final int completedCount;

  /// Count of blocked training (waiting for prerequisites)
  final int blockedCount;

  /// Days until next training is due (null if none)
  final int? daysUntilNextDue;

  /// Next training item due
  final TrainingItemSummary? nextDue;

  /// Upcoming sessions the employee is enrolled in
  final List<UpcomingSessionSummary> upcomingSessions;

  /// Recently completed training
  final List<CompletedTrainingSummary> recentlyCompleted;

  /// Compliance status by category
  final List<ComplianceCategorySummary> complianceByCategory;

  /// Induction progress (if not completed)
  final InductionProgressSummary? inductionProgress;

  /// Expiring certifications (within 30 days)
  final List<ExpiringCertSummary> expiringCertificates;

  const TrainingDashboardModel({
    required this.overallCompletionPercent,
    required this.pendingCount,
    required this.overdueCount,
    required this.completedCount,
    required this.blockedCount,
    this.daysUntilNextDue,
    this.nextDue,
    required this.upcomingSessions,
    required this.recentlyCompleted,
    required this.complianceByCategory,
    this.inductionProgress,
    required this.expiringCertificates,
  });

  Map<String, dynamic> toJson() => {
    'overall_completion_percent': overallCompletionPercent,
    'pending_count': pendingCount,
    'overdue_count': overdueCount,
    'completed_count': completedCount,
    'blocked_count': blockedCount,
    'days_until_next_due': daysUntilNextDue,
    'next_due': nextDue?.toJson(),
    'upcoming_sessions': upcomingSessions.map((s) => s.toJson()).toList(),
    'recently_completed': recentlyCompleted.map((c) => c.toJson()).toList(),
    'compliance_by_category': complianceByCategory.map((c) => c.toJson()).toList(),
    'induction_progress': inductionProgress?.toJson(),
    'expiring_certificates': expiringCertificates.map((c) => c.toJson()).toList(),
  };

  factory TrainingDashboardModel.fromJson(Map<String, dynamic> json) {
    return TrainingDashboardModel(
      overallCompletionPercent: (json['overall_completion_percent'] as num).toDouble(),
      pendingCount: json['pending_count'] as int,
      overdueCount: json['overdue_count'] as int,
      completedCount: json['completed_count'] as int,
      blockedCount: json['blocked_count'] as int,
      daysUntilNextDue: json['days_until_next_due'] as int?,
      nextDue: json['next_due'] != null 
          ? TrainingItemSummary.fromJson(json['next_due']) 
          : null,
      upcomingSessions: (json['upcoming_sessions'] as List?)
          ?.map((s) => UpcomingSessionSummary.fromJson(s))
          .toList() ?? [],
      recentlyCompleted: (json['recently_completed'] as List?)
          ?.map((c) => CompletedTrainingSummary.fromJson(c))
          .toList() ?? [],
      complianceByCategory: (json['compliance_by_category'] as List?)
          ?.map((c) => ComplianceCategorySummary.fromJson(c))
          .toList() ?? [],
      inductionProgress: json['induction_progress'] != null
          ? InductionProgressSummary.fromJson(json['induction_progress'])
          : null,
      expiringCertificates: (json['expiring_certificates'] as List?)
          ?.map((c) => ExpiringCertSummary.fromJson(c))
          .toList() ?? [],
    );
  }
}

/// Summary of a training item for dashboard display.
class TrainingItemSummary {
  final String id;
  final String title;
  final String courseCode;
  final String type; // 'classroom', 'wbt', 'ojt', 'blended'
  final String status; // 'pending', 'overdue', 'in_progress', 'blocked'
  final DateTime? dueDate;
  final int? estimatedDurationMinutes;

  const TrainingItemSummary({
    required this.id,
    required this.title,
    required this.courseCode,
    required this.type,
    required this.status,
    this.dueDate,
    this.estimatedDurationMinutes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'course_code': courseCode,
    'type': type,
    'status': status,
    'due_date': dueDate?.toIso8601String(),
    'estimated_duration_minutes': estimatedDurationMinutes,
  };

  factory TrainingItemSummary.fromJson(Map<String, dynamic> json) {
    return TrainingItemSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      courseCode: json['course_code'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
    );
  }
}

/// Summary of an upcoming session.
class UpcomingSessionSummary {
  final String sessionId;
  final String scheduleName;
  final String courseName;
  final DateTime sessionDate;
  final String? startTime;
  final String? endTime;
  final String? venueName;
  final String? trainerName;
  final String trainingMethod; // 'classroom', 'online', 'blended'

  const UpcomingSessionSummary({
    required this.sessionId,
    required this.scheduleName,
    required this.courseName,
    required this.sessionDate,
    this.startTime,
    this.endTime,
    this.venueName,
    this.trainerName,
    required this.trainingMethod,
  });

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'schedule_name': scheduleName,
    'course_name': courseName,
    'session_date': sessionDate.toIso8601String().split('T').first,
    'start_time': startTime,
    'end_time': endTime,
    'venue_name': venueName,
    'trainer_name': trainerName,
    'training_method': trainingMethod,
  };

  factory UpcomingSessionSummary.fromJson(Map<String, dynamic> json) {
    return UpcomingSessionSummary(
      sessionId: json['session_id'] as String,
      scheduleName: json['schedule_name'] as String,
      courseName: json['course_name'] as String,
      sessionDate: DateTime.parse(json['session_date']),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      venueName: json['venue_name'] as String?,
      trainerName: json['trainer_name'] as String?,
      trainingMethod: json['training_method'] as String,
    );
  }
}

/// Summary of completed training.
class CompletedTrainingSummary {
  final String trainingRecordId;
  final String courseName;
  final String courseCode;
  final DateTime completedAt;
  final int? score;
  final String? certificateId;

  const CompletedTrainingSummary({
    required this.trainingRecordId,
    required this.courseName,
    required this.courseCode,
    required this.completedAt,
    this.score,
    this.certificateId,
  });

  Map<String, dynamic> toJson() => {
    'training_record_id': trainingRecordId,
    'course_name': courseName,
    'course_code': courseCode,
    'completed_at': completedAt.toIso8601String(),
    'score': score,
    'certificate_id': certificateId,
  };

  factory CompletedTrainingSummary.fromJson(Map<String, dynamic> json) {
    return CompletedTrainingSummary(
      trainingRecordId: json['training_record_id'] as String,
      courseName: json['course_name'] as String,
      courseCode: json['course_code'] as String,
      completedAt: DateTime.parse(json['completed_at']),
      score: json['score'] as int?,
      certificateId: json['certificate_id'] as String?,
    );
  }
}

/// Compliance summary by category.
class ComplianceCategorySummary {
  final String categoryId;
  final String categoryName;
  final int totalRequired;
  final int completed;
  final int overdue;
  final double compliancePercent;

  const ComplianceCategorySummary({
    required this.categoryId,
    required this.categoryName,
    required this.totalRequired,
    required this.completed,
    required this.overdue,
    required this.compliancePercent,
  });

  Map<String, dynamic> toJson() => {
    'category_id': categoryId,
    'category_name': categoryName,
    'total_required': totalRequired,
    'completed': completed,
    'overdue': overdue,
    'compliance_percent': compliancePercent,
  };

  factory ComplianceCategorySummary.fromJson(Map<String, dynamic> json) {
    return ComplianceCategorySummary(
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      totalRequired: json['total_required'] as int,
      completed: json['completed'] as int,
      overdue: json['overdue'] as int,
      compliancePercent: (json['compliance_percent'] as num).toDouble(),
    );
  }
}

/// Induction progress summary.
class InductionProgressSummary {
  final String programId;
  final String programName;
  final int totalItems;
  final int completedItems;
  final double progressPercent;
  final DateTime? startedAt;
  final DateTime? dueDate;

  const InductionProgressSummary({
    required this.programId,
    required this.programName,
    required this.totalItems,
    required this.completedItems,
    required this.progressPercent,
    this.startedAt,
    this.dueDate,
  });

  Map<String, dynamic> toJson() => {
    'program_id': programId,
    'program_name': programName,
    'total_items': totalItems,
    'completed_items': completedItems,
    'progress_percent': progressPercent,
    'started_at': startedAt?.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
  };

  factory InductionProgressSummary.fromJson(Map<String, dynamic> json) {
    return InductionProgressSummary(
      programId: json['program_id'] as String,
      programName: json['program_name'] as String,
      totalItems: json['total_items'] as int,
      completedItems: json['completed_items'] as int,
      progressPercent: (json['progress_percent'] as num).toDouble(),
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
    );
  }
}

/// Expiring certificate summary.
class ExpiringCertSummary {
  final String certificateId;
  final String certificateNumber;
  final String courseName;
  final DateTime validUntil;
  final int daysRemaining;

  const ExpiringCertSummary({
    required this.certificateId,
    required this.certificateNumber,
    required this.courseName,
    required this.validUntil,
    required this.daysRemaining,
  });

  Map<String, dynamic> toJson() => {
    'certificate_id': certificateId,
    'certificate_number': certificateNumber,
    'course_name': courseName,
    'valid_until': validUntil.toIso8601String().split('T').first,
    'days_remaining': daysRemaining,
  };

  factory ExpiringCertSummary.fromJson(Map<String, dynamic> json) {
    return ExpiringCertSummary(
      certificateId: json['certificate_id'] as String,
      certificateNumber: json['certificate_number'] as String,
      courseName: json['course_name'] as String,
      validUntil: DateTime.parse(json['valid_until']),
      daysRemaining: json['days_remaining'] as int,
    );
  }
}
