import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import '../repositories/training_repository.dart';

part 'dashboard_store.g.dart';

/// Dashboard state for employee's training overview.
/// Displays obligations, upcoming sessions, compliance status.
@singleton
class DashboardStore = _DashboardStoreBase with _$DashboardStore;

abstract class _DashboardStoreBase with Store {
  final TrainingRepository _trainingRepository;
  
  _DashboardStoreBase(this._trainingRepository);
  
  // ---------------------------------------------------------------------------
  // Observable State
  // ---------------------------------------------------------------------------
  
  @observable
  bool isLoading = false;
  
  @observable
  String? errorMessage;
  
  @observable
  DateTime? lastRefreshed;
  
  @observable
  DashboardData? data;
  
  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------
  
  @computed
  int get pendingCount => data?.pendingObligations ?? 0;
  
  @computed
  int get overdueCount => data?.overdueObligations ?? 0;
  
  @computed
  double get compliancePercent => data?.compliancePercent ?? 0.0;
  
  @computed
  List<UpcomingSession> get upcomingSessions => 
      data?.upcomingSessions ?? [];
  
  @computed
  List<TrainingObligation> get urgentObligations {
    final obligs = data?.obligations ?? [];
    return obligs.where((o) => o.isUrgent).take(5).toList();
  }
  
  @computed
  bool get needsRefresh {
    if (lastRefreshed == null) return true;
    return DateTime.now().difference(lastRefreshed!).inMinutes > 5;
  }
  
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  @action
  Future<void> loadDashboard({bool forceRefresh = false}) async {
    if (isLoading) return;
    if (!forceRefresh && !needsRefresh && data != null) return;
    
    isLoading = true;
    errorMessage = null;
    
    try {
      data = await _trainingRepository.getDashboard();
      lastRefreshed = DateTime.now();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  void clearError() {
    errorMessage = null;
  }
}

// ---------------------------------------------------------------------------
// Dashboard Models
// ---------------------------------------------------------------------------

class DashboardData {
  final int pendingObligations;
  final int overdueObligations;
  final int completedThisMonth;
  final double compliancePercent;
  final List<TrainingObligation> obligations;
  final List<UpcomingSession> upcomingSessions;
  final List<RecentCompletion> recentCompletions;
  
  DashboardData({
    required this.pendingObligations,
    required this.overdueObligations,
    required this.completedThisMonth,
    required this.compliancePercent,
    required this.obligations,
    required this.upcomingSessions,
    required this.recentCompletions,
  });
  
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      pendingObligations: json['pending_obligations'] ?? 0,
      overdueObligations: json['overdue_obligations'] ?? 0,
      completedThisMonth: json['completed_this_month'] ?? 0,
      compliancePercent: (json['compliance_percent'] as num?)?.toDouble() ?? 0.0,
      obligations: (json['obligations'] as List?)
          ?.map((o) => TrainingObligation.fromJson(o))
          .toList() ?? [],
      upcomingSessions: (json['upcoming_sessions'] as List?)
          ?.map((s) => UpcomingSession.fromJson(s))
          .toList() ?? [],
      recentCompletions: (json['recent_completions'] as List?)
          ?.map((c) => RecentCompletion.fromJson(c))
          .toList() ?? [],
    );
  }
}

class TrainingObligation {
  final String id;
  final String courseId;
  final String courseTitle;
  final String type;
  final DateTime? dueDate;
  final String status;
  final int? daysRemaining;
  
  TrainingObligation({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.type,
    this.dueDate,
    required this.status,
    this.daysRemaining,
  });
  
  bool get isUrgent => 
      daysRemaining != null && daysRemaining! <= 7 && daysRemaining! >= 0;
  
  bool get isOverdue => daysRemaining != null && daysRemaining! < 0;
  
  factory TrainingObligation.fromJson(Map<String, dynamic> json) {
    return TrainingObligation(
      id: json['id'],
      courseId: json['course_id'],
      courseTitle: json['course_title'] ?? json['courses']?['title'] ?? '',
      type: json['obligation_type'] ?? 'required',
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      status: json['status'] ?? 'pending',
      daysRemaining: json['days_remaining'],
    );
  }
}

class UpcomingSession {
  final String id;
  final String courseTitle;
  final String? venueName;
  final DateTime scheduledAt;
  final String? trainerName;
  final bool isEnrolled;
  
  UpcomingSession({
    required this.id,
    required this.courseTitle,
    this.venueName,
    required this.scheduledAt,
    this.trainerName,
    required this.isEnrolled,
  });
  
  factory UpcomingSession.fromJson(Map<String, dynamic> json) {
    return UpcomingSession(
      id: json['id'],
      courseTitle: json['course_title'] ?? json['courses']?['title'] ?? '',
      venueName: json['venue_name'] ?? json['venues']?['name'],
      scheduledAt: DateTime.parse(json['scheduled_at']),
      trainerName: json['trainer_name'],
      isEnrolled: json['is_enrolled'] ?? false,
    );
  }
}

class RecentCompletion {
  final String id;
  final String courseTitle;
  final DateTime completedAt;
  final double? score;
  
  RecentCompletion({
    required this.id,
    required this.courseTitle,
    required this.completedAt,
    this.score,
  });
  
  factory RecentCompletion.fromJson(Map<String, dynamic> json) {
    return RecentCompletion(
      id: json['id'],
      courseTitle: json['course_title'] ?? json['courses']?['title'] ?? '',
      completedAt: DateTime.parse(json['completed_at']),
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}
