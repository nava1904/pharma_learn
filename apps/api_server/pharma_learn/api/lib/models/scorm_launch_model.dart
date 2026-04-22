/// SCORM launch model for launching WBT courses.
/// 
/// Used by: GET /v1/train/wbt/:courseId/launch
/// Reference: URS-TRN-08 - WBT Integration
/// Reference: EE §5.3 - SCORM 1.2/2004 compliance

/// Request to launch a SCORM course.
class ScormLaunchRequest {
  /// Employee ID launching the course
  final String employeeId;

  /// Course ID to launch
  final String courseId;

  /// Training obligation ID (if assigned training)
  final String? obligationId;

  /// Session ID (for blended learning)
  final String? sessionId;

  /// Resume from last position
  final bool resume;

  /// Preview mode (no tracking)
  final bool previewMode;

  const ScormLaunchRequest({
    required this.employeeId,
    required this.courseId,
    this.obligationId,
    this.sessionId,
    this.resume = true,
    this.previewMode = false,
  });

  factory ScormLaunchRequest.fromJson(Map<String, dynamic> json) {
    return ScormLaunchRequest(
      employeeId: json['employee_id'] as String,
      courseId: json['course_id'] as String,
      obligationId: json['obligation_id'] as String?,
      sessionId: json['session_id'] as String?,
      resume: json['resume'] as bool? ?? true,
      previewMode: json['preview_mode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'employee_id': employeeId,
    'course_id': courseId,
    'obligation_id': obligationId,
    'session_id': sessionId,
    'resume': resume,
    'preview_mode': previewMode,
  };
}

/// Response with SCORM launch data.
class ScormLaunchResponse {
  /// Launch URL for the SCORM content
  final String launchUrl;

  /// Launch token for API authentication
  final String launchToken;

  /// Token expiration time
  final DateTime tokenExpiresAt;

  /// Learning progress ID for tracking
  final String learningProgressId;

  /// SCORM version ('1.2' or '2004')
  final String scormVersion;

  /// API endpoint for SCORM data commits
  final String apiEndpoint;

  /// Entry type ('ab-initio', 'resume')
  final String entry;

  /// Existing CMI data if resuming
  final ScormCmiData? cmiData;

  /// Course metadata
  final ScormCourseInfo courseInfo;

  /// Proctoring settings
  final ScormProctoringConfig? proctoring;

  const ScormLaunchResponse({
    required this.launchUrl,
    required this.launchToken,
    required this.tokenExpiresAt,
    required this.learningProgressId,
    required this.scormVersion,
    required this.apiEndpoint,
    required this.entry,
    this.cmiData,
    required this.courseInfo,
    this.proctoring,
  });

  Map<String, dynamic> toJson() => {
    'launch_url': launchUrl,
    'launch_token': launchToken,
    'token_expires_at': tokenExpiresAt.toIso8601String(),
    'learning_progress_id': learningProgressId,
    'scorm_version': scormVersion,
    'api_endpoint': apiEndpoint,
    'entry': entry,
    'cmi_data': cmiData?.toJson(),
    'course_info': courseInfo.toJson(),
    'proctoring': proctoring?.toJson(),
  };

  factory ScormLaunchResponse.fromJson(Map<String, dynamic> json) {
    return ScormLaunchResponse(
      launchUrl: json['launch_url'] as String,
      launchToken: json['launch_token'] as String,
      tokenExpiresAt: DateTime.parse(json['token_expires_at']),
      learningProgressId: json['learning_progress_id'] as String,
      scormVersion: json['scorm_version'] as String,
      apiEndpoint: json['api_endpoint'] as String,
      entry: json['entry'] as String,
      cmiData: json['cmi_data'] != null
          ? ScormCmiData.fromJson(json['cmi_data'])
          : null,
      courseInfo: ScormCourseInfo.fromJson(json['course_info']),
      proctoring: json['proctoring'] != null
          ? ScormProctoringConfig.fromJson(json['proctoring'])
          : null,
    );
  }
}

/// SCORM CMI data model for state persistence.
/// Reference: SCORM 1.2 and 2004 data model specifications
class ScormCmiData {
  /// Learner ID
  final String learnerId;

  /// Learner name
  final String learnerName;

  /// Lesson location (bookmark)
  final String? location;

  /// Suspend data (course state)
  final String? suspendData;

  /// Credit mode ('credit' or 'no-credit')
  final String credit;

  /// Lesson status for SCORM 1.2
  final String? lessonStatus;

  /// Completion status for SCORM 2004
  final String? completionStatus;

  /// Success status for SCORM 2004
  final String? successStatus;

  /// Score
  final ScormScore? score;

  /// Total time spent
  final String? totalTime;

  /// Session time
  final String? sessionTime;

  /// Entry mode ('ab-initio', 'resume')
  final String entry;

  /// Exit mode ('time-out', 'suspend', 'logout', '')
  final String? exit;

  /// Interactions (question responses)
  final List<ScormInteraction>? interactions;

  /// Objectives
  final List<ScormObjective>? objectives;

  /// Max time allowed
  final String? maxTimeAllowed;

  /// Time limit action
  final String? timeLimitAction;

  /// Scaled passing score (0-1 for SCORM 2004)
  final double? scaledPassingScore;

  const ScormCmiData({
    required this.learnerId,
    required this.learnerName,
    this.location,
    this.suspendData,
    this.credit = 'credit',
    this.lessonStatus,
    this.completionStatus,
    this.successStatus,
    this.score,
    this.totalTime,
    this.sessionTime,
    this.entry = 'ab-initio',
    this.exit,
    this.interactions,
    this.objectives,
    this.maxTimeAllowed,
    this.timeLimitAction,
    this.scaledPassingScore,
  });

  Map<String, dynamic> toJson() => {
    'learner_id': learnerId,
    'learner_name': learnerName,
    'location': location,
    'suspend_data': suspendData,
    'credit': credit,
    'lesson_status': lessonStatus,
    'completion_status': completionStatus,
    'success_status': successStatus,
    'score': score?.toJson(),
    'total_time': totalTime,
    'session_time': sessionTime,
    'entry': entry,
    'exit': exit,
    'interactions': interactions?.map((i) => i.toJson()).toList(),
    'objectives': objectives?.map((o) => o.toJson()).toList(),
    'max_time_allowed': maxTimeAllowed,
    'time_limit_action': timeLimitAction,
    'scaled_passing_score': scaledPassingScore,
  };

  factory ScormCmiData.fromJson(Map<String, dynamic> json) {
    return ScormCmiData(
      learnerId: json['learner_id'] as String,
      learnerName: json['learner_name'] as String,
      location: json['location'] as String?,
      suspendData: json['suspend_data'] as String?,
      credit: json['credit'] as String? ?? 'credit',
      lessonStatus: json['lesson_status'] as String?,
      completionStatus: json['completion_status'] as String?,
      successStatus: json['success_status'] as String?,
      score: json['score'] != null ? ScormScore.fromJson(json['score']) : null,
      totalTime: json['total_time'] as String?,
      sessionTime: json['session_time'] as String?,
      entry: json['entry'] as String? ?? 'ab-initio',
      exit: json['exit'] as String?,
      interactions: (json['interactions'] as List?)
          ?.map((i) => ScormInteraction.fromJson(i))
          .toList(),
      objectives: (json['objectives'] as List?)
          ?.map((o) => ScormObjective.fromJson(o))
          .toList(),
      maxTimeAllowed: json['max_time_allowed'] as String?,
      timeLimitAction: json['time_limit_action'] as String?,
      scaledPassingScore: (json['scaled_passing_score'] as num?)?.toDouble(),
    );
  }

  ScormCmiData copyWith({
    String? learnerId,
    String? learnerName,
    String? location,
    String? suspendData,
    String? credit,
    String? lessonStatus,
    String? completionStatus,
    String? successStatus,
    ScormScore? score,
    String? totalTime,
    String? sessionTime,
    String? entry,
    String? exit,
    List<ScormInteraction>? interactions,
    List<ScormObjective>? objectives,
    String? maxTimeAllowed,
    String? timeLimitAction,
    double? scaledPassingScore,
  }) {
    return ScormCmiData(
      learnerId: learnerId ?? this.learnerId,
      learnerName: learnerName ?? this.learnerName,
      location: location ?? this.location,
      suspendData: suspendData ?? this.suspendData,
      credit: credit ?? this.credit,
      lessonStatus: lessonStatus ?? this.lessonStatus,
      completionStatus: completionStatus ?? this.completionStatus,
      successStatus: successStatus ?? this.successStatus,
      score: score ?? this.score,
      totalTime: totalTime ?? this.totalTime,
      sessionTime: sessionTime ?? this.sessionTime,
      entry: entry ?? this.entry,
      exit: exit ?? this.exit,
      interactions: interactions ?? this.interactions,
      objectives: objectives ?? this.objectives,
      maxTimeAllowed: maxTimeAllowed ?? this.maxTimeAllowed,
      timeLimitAction: timeLimitAction ?? this.timeLimitAction,
      scaledPassingScore: scaledPassingScore ?? this.scaledPassingScore,
    );
  }
}

/// SCORM score object.
class ScormScore {
  /// Raw score
  final double? raw;

  /// Minimum score
  final double? min;

  /// Maximum score
  final double? max;

  /// Scaled score (0-1 for SCORM 2004)
  final double? scaled;

  const ScormScore({
    this.raw,
    this.min,
    this.max,
    this.scaled,
  });

  Map<String, dynamic> toJson() => {
    'raw': raw,
    'min': min,
    'max': max,
    'scaled': scaled,
  };

  factory ScormScore.fromJson(Map<String, dynamic> json) {
    return ScormScore(
      raw: (json['raw'] as num?)?.toDouble(),
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      scaled: (json['scaled'] as num?)?.toDouble(),
    );
  }
}

/// SCORM interaction (question/response).
class ScormInteraction {
  final String id;
  final String? type;
  final String? description;
  final List<String>? correctResponses;
  final String? learnerResponse;
  final String? result;
  final double? weighting;
  final String? latency;
  final DateTime? timestamp;

  const ScormInteraction({
    required this.id,
    this.type,
    this.description,
    this.correctResponses,
    this.learnerResponse,
    this.result,
    this.weighting,
    this.latency,
    this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'description': description,
    'correct_responses': correctResponses,
    'learner_response': learnerResponse,
    'result': result,
    'weighting': weighting,
    'latency': latency,
    'timestamp': timestamp?.toIso8601String(),
  };

  factory ScormInteraction.fromJson(Map<String, dynamic> json) {
    return ScormInteraction(
      id: json['id'] as String,
      type: json['type'] as String?,
      description: json['description'] as String?,
      correctResponses: (json['correct_responses'] as List?)?.cast<String>(),
      learnerResponse: json['learner_response'] as String?,
      result: json['result'] as String?,
      weighting: (json['weighting'] as num?)?.toDouble(),
      latency: json['latency'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : null,
    );
  }
}

/// SCORM objective.
class ScormObjective {
  final String id;
  final String? description;
  final ScormScore? score;
  final String? successStatus;
  final String? completionStatus;
  final double? progressMeasure;

  const ScormObjective({
    required this.id,
    this.description,
    this.score,
    this.successStatus,
    this.completionStatus,
    this.progressMeasure,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'score': score?.toJson(),
    'success_status': successStatus,
    'completion_status': completionStatus,
    'progress_measure': progressMeasure,
  };

  factory ScormObjective.fromJson(Map<String, dynamic> json) {
    return ScormObjective(
      id: json['id'] as String,
      description: json['description'] as String?,
      score: json['score'] != null ? ScormScore.fromJson(json['score']) : null,
      successStatus: json['success_status'] as String?,
      completionStatus: json['completion_status'] as String?,
      progressMeasure: (json['progress_measure'] as num?)?.toDouble(),
    );
  }
}

/// SCORM course metadata.
class ScormCourseInfo {
  final String courseId;
  final String courseCode;
  final String title;
  final String? description;
  final String scormVersion;
  final int? estimatedDurationMinutes;
  final int? passingScore;
  final bool allowBookmarking;
  final bool allowReview;
  final int? maxAttempts;
  final String masteryScore;

  const ScormCourseInfo({
    required this.courseId,
    required this.courseCode,
    required this.title,
    this.description,
    required this.scormVersion,
    this.estimatedDurationMinutes,
    this.passingScore,
    this.allowBookmarking = true,
    this.allowReview = true,
    this.maxAttempts,
    this.masteryScore = '80',
  });

  Map<String, dynamic> toJson() => {
    'course_id': courseId,
    'course_code': courseCode,
    'title': title,
    'description': description,
    'scorm_version': scormVersion,
    'estimated_duration_minutes': estimatedDurationMinutes,
    'passing_score': passingScore,
    'allow_bookmarking': allowBookmarking,
    'allow_review': allowReview,
    'max_attempts': maxAttempts,
    'mastery_score': masteryScore,
  };

  factory ScormCourseInfo.fromJson(Map<String, dynamic> json) {
    return ScormCourseInfo(
      courseId: json['course_id'] as String,
      courseCode: json['course_code'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      scormVersion: json['scorm_version'] as String,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      passingScore: json['passing_score'] as int?,
      allowBookmarking: json['allow_bookmarking'] as bool? ?? true,
      allowReview: json['allow_review'] as bool? ?? true,
      maxAttempts: json['max_attempts'] as int?,
      masteryScore: json['mastery_score'] as String? ?? '80',
    );
  }
}

/// Proctoring configuration for assessment mode.
/// Reference: URS-TRN-09 - Assessment with proctoring
class ScormProctoringConfig {
  /// Enable proctoring
  final bool enabled;

  /// Track tab switches
  final bool trackTabSwitches;

  /// Tab switch threshold before flagging
  final int tabSwitchThreshold;

  /// Track copy/paste events
  final bool trackCopyPaste;

  /// Track focus loss events
  final bool trackFocusLoss;

  /// Focus loss threshold before flagging
  final int focusLossThreshold;

  /// Detect rapid submission
  final bool detectRapidSubmission;

  /// Minimum expected completion time (minutes)
  final int? minCompletionTimeMinutes;

  /// Capture screenshots periodically
  final bool captureScreenshots;

  /// Screenshot interval (seconds)
  final int? screenshotIntervalSeconds;

  /// Require webcam
  final bool requireWebcam;

  /// Allow calculator
  final bool allowCalculator;

  /// Allow notes
  final bool allowNotes;

  /// Lock browser (fullscreen mode)
  final bool lockBrowser;

  const ScormProctoringConfig({
    required this.enabled,
    this.trackTabSwitches = true,
    this.tabSwitchThreshold = 3,
    this.trackCopyPaste = true,
    this.trackFocusLoss = true,
    this.focusLossThreshold = 2,
    this.detectRapidSubmission = true,
    this.minCompletionTimeMinutes,
    this.captureScreenshots = false,
    this.screenshotIntervalSeconds,
    this.requireWebcam = false,
    this.allowCalculator = false,
    this.allowNotes = false,
    this.lockBrowser = false,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'track_tab_switches': trackTabSwitches,
    'tab_switch_threshold': tabSwitchThreshold,
    'track_copy_paste': trackCopyPaste,
    'track_focus_loss': trackFocusLoss,
    'focus_loss_threshold': focusLossThreshold,
    'detect_rapid_submission': detectRapidSubmission,
    'min_completion_time_minutes': minCompletionTimeMinutes,
    'capture_screenshots': captureScreenshots,
    'screenshot_interval_seconds': screenshotIntervalSeconds,
    'require_webcam': requireWebcam,
    'allow_calculator': allowCalculator,
    'allow_notes': allowNotes,
    'lock_browser': lockBrowser,
  };

  factory ScormProctoringConfig.fromJson(Map<String, dynamic> json) {
    return ScormProctoringConfig(
      enabled: json['enabled'] as bool,
      trackTabSwitches: json['track_tab_switches'] as bool? ?? true,
      tabSwitchThreshold: json['tab_switch_threshold'] as int? ?? 3,
      trackCopyPaste: json['track_copy_paste'] as bool? ?? true,
      trackFocusLoss: json['track_focus_loss'] as bool? ?? true,
      focusLossThreshold: json['focus_loss_threshold'] as int? ?? 2,
      detectRapidSubmission: json['detect_rapid_submission'] as bool? ?? true,
      minCompletionTimeMinutes: json['min_completion_time_minutes'] as int?,
      captureScreenshots: json['capture_screenshots'] as bool? ?? false,
      screenshotIntervalSeconds: json['screenshot_interval_seconds'] as int?,
      requireWebcam: json['require_webcam'] as bool? ?? false,
      allowCalculator: json['allow_calculator'] as bool? ?? false,
      allowNotes: json['allow_notes'] as bool? ?? false,
      lockBrowser: json['lock_browser'] as bool? ?? false,
    );
  }
}

/// SCORM commit request from the LMS runtime.
class ScormCommitRequest {
  /// Learning progress ID
  final String learningProgressId;

  /// Launch token for authentication
  final String launchToken;

  /// CMI data to persist
  final Map<String, dynamic> cmiData;

  /// Timestamp of the commit
  final DateTime timestamp;

  /// Is this the final commit (Terminate called)
  final bool isFinal;

  const ScormCommitRequest({
    required this.learningProgressId,
    required this.launchToken,
    required this.cmiData,
    required this.timestamp,
    this.isFinal = false,
  });

  factory ScormCommitRequest.fromJson(Map<String, dynamic> json) {
    return ScormCommitRequest(
      learningProgressId: json['learning_progress_id'] as String,
      launchToken: json['launch_token'] as String,
      cmiData: json['cmi_data'] as Map<String, dynamic>,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      isFinal: json['is_final'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'learning_progress_id': learningProgressId,
    'launch_token': launchToken,
    'cmi_data': cmiData,
    'timestamp': timestamp.toIso8601String(),
    'is_final': isFinal,
  };
}

/// SCORM commit response.
class ScormCommitResponse {
  final bool success;
  final String? error;
  final DateTime? serverTimestamp;

  const ScormCommitResponse({
    required this.success,
    this.error,
    this.serverTimestamp,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'error': error,
    'server_timestamp': serverTimestamp?.toIso8601String(),
  };

  factory ScormCommitResponse.fromJson(Map<String, dynamic> json) {
    return ScormCommitResponse(
      success: json['success'] as bool,
      error: json['error'] as String?,
      serverTimestamp: json['server_timestamp'] != null
          ? DateTime.parse(json['server_timestamp'])
          : null,
    );
  }
}
