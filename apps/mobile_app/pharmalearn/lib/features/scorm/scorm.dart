/// SCORM 1.2 feature for PharmaLearn mobile app.
///
/// Provides:
/// - [ScormPlayerWidget] - WebView-based SCORM content player
/// - [ScormPlayerScreen] - Full-screen SCORM player page
/// - [ScormRepository] - API communication and offline sync
/// - [scormApiShimJs] - JavaScript shim for SCORM API injection
library scorm;

export 'scorm_api_shim.dart';
export 'scorm_player_screen.dart';
export 'scorm_player_widget.dart';
export 'scorm_repository.dart';
