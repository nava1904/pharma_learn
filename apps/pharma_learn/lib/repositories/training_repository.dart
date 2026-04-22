import 'package:injectable/injectable.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../stores/dashboard_store.dart';

/// Repository for training-related API operations.
@singleton
class TrainingRepository {
  final ApiClient _api;
  
  TrainingRepository(this._api);
  
  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------
  
  Future<DashboardData> getDashboard() async {
    try {
      final response = await _api.get('/v1/train/me/dashboard');
      final data = response.data as Map<String, dynamic>;
      return DashboardData.fromJson(data['data'] ?? data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Training History
  // ---------------------------------------------------------------------------
  
  Future<List<TrainingRecord>> getTrainingHistory({
    int page = 1,
    int perPage = 20,
    String? status,
    String? courseId,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (status != null) params['status'] = status;
      if (courseId != null) params['course_id'] = courseId;
      
      final response = await _api.get(
        '/v1/train/me/training-history',
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      final records = data['data']?['records'] ?? data['records'] ?? [];
      return (records as List)
          .map((r) => TrainingRecord.fromJson(r))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Obligations
  // ---------------------------------------------------------------------------
  
  Future<List<Obligation>> getObligations({
    String? status,
    bool? overdue,
  }) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      if (overdue != null) params['overdue'] = overdue.toString();
      
      final response = await _api.get(
        '/v1/train/obligations',
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      final obligations = data['data']?['obligations'] ?? data['obligations'] ?? [];
      return (obligations as List)
          .map((o) => Obligation.fromJson(o))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<Obligation> getObligation(String id) async {
    try {
      final response = await _api.get('/v1/train/obligations/$id');
      final data = response.data as Map<String, dynamic>;
      return Obligation.fromJson(data['data'] ?? data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------
  
  Future<List<Session>> getSessions({
    String? status,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (status != null) params['status'] = status;
      if (from != null) params['from'] = from.toIso8601String();
      if (to != null) params['to'] = to.toIso8601String();
      
      final response = await _api.get(
        '/v1/train/sessions',
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      final sessions = data['data']?['sessions'] ?? data['sessions'] ?? [];
      return (sessions as List)
          .map((s) => Session.fromJson(s))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<Session> getSession(String id) async {
    try {
      final response = await _api.get('/v1/train/sessions/$id');
      final data = response.data as Map<String, dynamic>;
      return Session.fromJson(data['data'] ?? data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<CheckInResult> checkIn(String sessionId, {String? qrToken}) async {
    try {
      final response = await _api.post(
        '/v1/train/sessions/$sessionId/check-in',
        data: qrToken != null ? {'qr_token': qrToken} : null,
      );
      final data = response.data as Map<String, dynamic>;
      return CheckInResult.fromJson(data['data'] ?? data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<void> checkOut(String sessionId) async {
    try {
      await _api.post('/v1/train/sessions/$sessionId/check-out');
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Induction
  // ---------------------------------------------------------------------------
  
  Future<InductionStatus> getInductionStatus() async {
    try {
      final response = await _api.get('/v1/train/induction/status');
      final data = response.data as Map<String, dynamic>;
      return InductionStatus.fromJson(data['data'] ?? data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<List<InductionModule>> getInductionModules() async {
    try {
      final response = await _api.get('/v1/train/induction/modules');
      final data = response.data as Map<String, dynamic>;
      final modules = data['data']?['modules'] ?? data['modules'] ?? [];
      return (modules as List)
          .map((m) => InductionModule.fromJson(m))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<InductionModule> getInductionModule(String moduleId) async {
    try {
      final response = await _api.get('/v1/train/induction/modules/$moduleId');
      final data = response.data as Map<String, dynamic>;
      return InductionModule.fromJson(data['data'] ?? data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<void> completeInductionModule(String moduleId) async {
    try {
      await _api.post('/v1/train/induction/modules/$moduleId/complete');
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<void> completeInduction({
    required String esigPassword,
    required String meaning,
  }) async {
    try {
      await _api.post(
        '/v1/train/induction/complete',
        data: {
          'esig_password': esigPassword,
          'meaning': meaning,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Self Learning
  // ---------------------------------------------------------------------------
  
  Future<void> startSelfLearning(String obligationId) async {
    try {
      await _api.post('/v1/train/self-learning/$obligationId/start');
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<void> updateSelfLearningProgress(
    String obligationId,
    double progress,
  ) async {
    try {
      await _api.post(
        '/v1/train/self-learning/$obligationId/progress',
        data: {'progress': progress},
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<void> completeSelfLearning(
    String obligationId, {
    required String esigPassword,
    required String meaning,
  }) async {
    try {
      await _api.post(
        '/v1/train/self-learning/$obligationId/complete',
        data: {
          'esig_password': esigPassword,
          'meaning': meaning,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Waivers
  // ---------------------------------------------------------------------------
  
  Future<void> submitWaiver({
    required String obligationId,
    required String reason,
    required String justification,
  }) async {
    try {
      await _api.post(
        '/v1/train/waivers',
        data: {
          'obligation_id': obligationId,
          'reason': reason,
          'justification': justification,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<List<WaiverRequest>> getMyWaivers() async {
    try {
      final response = await _api.get('/v1/certify/waivers/my');
      final data = response.data as Map<String, dynamic>;
      final waivers = data['data'] ?? data;
      return (waivers as List)
          .map((w) => WaiverRequest.fromJson(w))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------
  
  Exception _handleError(dynamic e) {
    if (e is ApiException) return e;
    return ApiException(message: e.toString());
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class TrainingRecord {
  final String id;
  final String courseId;
  final String courseTitle;
  final String status;
  final DateTime? completedAt;
  final double? score;
  final String? certificateId;
  
  TrainingRecord({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.status,
    this.completedAt,
    this.score,
    this.certificateId,
  });
  
  factory TrainingRecord.fromJson(Map<String, dynamic> json) {
    return TrainingRecord(
      id: json['id'],
      courseId: json['course_id'],
      courseTitle: json['course_title'] ?? json['courses']?['title'] ?? '',
      status: json['status'] ?? 'pending',
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      score: (json['score'] as num?)?.toDouble(),
      certificateId: json['certificate_id'],
    );
  }
}

class Obligation {
  final String id;
  final String courseId;
  final String courseTitle;
  final String type;
  final String status;
  final DateTime? dueDate;
  final DateTime? assignedAt;
  final int? daysRemaining;
  
  Obligation({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.type,
    required this.status,
    this.dueDate,
    this.assignedAt,
    this.daysRemaining,
  });
  
  /// Returns true if obligation needs urgent attention (due within 7 days or overdue)
  bool get isUrgent {
    if (status == 'overdue') return true;
    if (dueDate == null) return false;
    return dueDate!.difference(DateTime.now()).inDays <= 7;
  }
  
  factory Obligation.fromJson(Map<String, dynamic> json) {
    return Obligation(
      id: json['id'],
      courseId: json['course_id'],
      courseTitle: json['course_title'] ?? json['courses']?['title'] ?? '',
      type: json['obligation_type'] ?? 'required',
      status: json['status'] ?? 'pending',
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      assignedAt: json['assigned_at'] != null ? DateTime.parse(json['assigned_at']) : null,
      daysRemaining: json['days_remaining'],
    );
  }
}

class Session {
  final String id;
  final String courseId;
  final String courseTitle;
  final String? venueId;
  final String? venueName;
  final DateTime scheduledAt;
  final DateTime? endAt;
  final String status;
  final String? trainerId;
  final String? trainerName;
  final bool isEnrolled;
  final String? attendanceStatus;
  
  Session({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    this.venueId,
    this.venueName,
    required this.scheduledAt,
    this.endAt,
    required this.status,
    this.trainerId,
    this.trainerName,
    required this.isEnrolled,
    this.attendanceStatus,
  });
  
  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      courseId: json['course_id'],
      courseTitle: json['course_title'] ?? json['courses']?['title'] ?? '',
      venueId: json['venue_id'],
      venueName: json['venue_name'] ?? json['venues']?['name'],
      scheduledAt: DateTime.parse(json['scheduled_at']),
      endAt: json['end_at'] != null ? DateTime.parse(json['end_at']) : null,
      status: json['status'] ?? 'scheduled',
      trainerId: json['trainer_id'],
      trainerName: json['trainer_name'],
      isEnrolled: json['is_enrolled'] ?? false,
      attendanceStatus: json['attendance_status'],
    );
  }
}

class CheckInResult {
  final String attendanceId;
  final DateTime checkedInAt;
  final bool success;
  
  CheckInResult({
    required this.attendanceId,
    required this.checkedInAt,
    required this.success,
  });
  
  factory CheckInResult.fromJson(Map<String, dynamic> json) {
    return CheckInResult(
      attendanceId: json['attendance_id'] ?? json['id'],
      checkedInAt: json['checked_in_at'] != null 
          ? DateTime.parse(json['checked_in_at']) 
          : DateTime.now(),
      success: json['success'] ?? true,
    );
  }
}

class InductionStatus {
  final bool isCompleted;
  final int completedModules;
  final int totalModules;
  final double progress;
  final DateTime? completedAt;
  
  InductionStatus({
    required this.isCompleted,
    required this.completedModules,
    required this.totalModules,
    required this.progress,
    this.completedAt,
  });
  
  factory InductionStatus.fromJson(Map<String, dynamic> json) {
    return InductionStatus(
      isCompleted: json['is_completed'] ?? false,
      completedModules: json['completed_modules'] ?? 0,
      totalModules: json['total_modules'] ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
    );
  }
}

class InductionModule {
  final String id;
  final String title;
  final String? description;
  final int order;
  final bool isCompleted;
  final String type;
  final String? contentUrl;
  
  InductionModule({
    required this.id,
    required this.title,
    this.description,
    required this.order,
    required this.isCompleted,
    required this.type,
    this.contentUrl,
  });
  
  factory InductionModule.fromJson(Map<String, dynamic> json) {
    return InductionModule(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      order: json['order'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      type: json['type'] ?? 'document',
      contentUrl: json['content_url'],
    );
  }
}

class WaiverRequest {
  final String id;
  final String obligationId;
  final String reason;
  final String justification;
  final String status;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  
  WaiverRequest({
    required this.id,
    required this.obligationId,
    required this.reason,
    required this.justification,
    required this.status,
    required this.requestedAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
  });
  
  factory WaiverRequest.fromJson(Map<String, dynamic> json) {
    return WaiverRequest(
      id: json['id'],
      obligationId: json['obligation_id'] ?? json['assignment_id'] ?? '',
      reason: json['reason'] ?? json['waiver_reason'] ?? '',
      justification: json['justification'] ?? '',
      status: json['status'] ?? 'pending_approval',
      requestedAt: json['requested_at'] != null 
          ? DateTime.parse(json['requested_at'])
          : DateTime.now(),
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at'])
          : null,
      rejectedAt: json['rejected_at'] != null 
          ? DateTime.parse(json['rejected_at'])
          : null,
      rejectionReason: json['rejection_reason'],
    );
  }
}
