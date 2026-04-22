import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'scorm_player_widget.dart';
import 'scorm_repository.dart';

/// Full-screen SCORM player page.
///
/// Handles:
/// - Launching SCORM session
/// - Full-screen immersive mode
/// - Exit confirmation
/// - Commit callbacks
class ScormPlayerScreen extends StatefulWidget {
  /// SCORM package ID to launch.
  final String packageId;
  
  /// Optional training record ID (for linked training).
  final String? trainingRecordId;
  
  /// Repository for API calls.
  final ScormRepository repository;
  
  /// Callback when SCORM completes.
  final VoidCallback? onComplete;

  const ScormPlayerScreen({
    super.key,
    required this.packageId,
    required this.repository,
    this.trainingRecordId,
    this.onComplete,
  });

  @override
  State<ScormPlayerScreen> createState() => _ScormPlayerScreenState();
}

class _ScormPlayerScreenState extends State<ScormPlayerScreen> {
  ScormLaunchResult? _launchResult;
  String? _error;
  bool _isLoading = true;
  bool _hasChanges = false;
  Map<String, dynamic> _lastCmiData = {};

  @override
  void initState() {
    super.initState();
    _enterFullScreen();
    _launch();
  }

  @override
  void dispose() {
    _exitFullScreen();
    super.dispose();
  }

  void _enterFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  void _exitFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> _launch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.repository.launch(
        widget.packageId,
        trainingRecordId: widget.trainingRecordId,
      );
      
      setState(() {
        _launchResult = result;
        _lastCmiData = Map.from(result.cmiData);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<bool> _onCommit(Map<String, dynamic> cmiData) async {
    _hasChanges = true;
    _lastCmiData = Map.from(cmiData);
    
    if (_launchResult == null) return false;
    
    return await widget.repository.commit(
      packageId: widget.packageId,
      sessionId: _launchResult!.sessionId,
      cmiData: cmiData,
    );
  }

  void _onFinish(Map<String, dynamic> cmiData) {
    _lastCmiData = Map.from(cmiData);
    
    // Check if completed
    final status = cmiData['cmi.core.lesson_status'] as String? ?? '';
    if (status == 'completed' || status == 'passed') {
      widget.onComplete?.call();
    }
    
    // Pop back
    Navigator.of(context).pop(cmiData);
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit SCORM?'),
        content: const Text(
          'Your progress has been saved. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop(_lastCmiData);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(
            _launchResult?.packageInfo?['title'] as String? ?? 'SCORM Content',
            style: const TextStyle(fontSize: 16),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop(_lastCmiData);
              }
            },
          ),
          actions: [
            if (_launchResult != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    'Attempt ${_launchResult!.attemptNumber}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading SCORM content...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _launch,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_launchResult == null) {
      return const Center(
        child: Text(
          'No launch data',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ScormPlayerWidget(
      launchUrl: _launchResult!.launchUrl,
      baseUrl: _launchResult!.baseUrl,
      sessionId: _launchResult!.sessionId,
      packageId: widget.packageId,
      initialCmiData: _launchResult!.cmiData,
      onCommit: _onCommit,
      onFinish: _onFinish,
    );
  }
}
