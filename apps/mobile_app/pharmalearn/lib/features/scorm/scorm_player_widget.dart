import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';

import 'scorm_api_shim.dart';

/// SCORM 1.2 player widget using flutter_inappwebview.
///
/// Injects the SCORM API shim and handles CMI data communication.
/// Supports offline buffering via Hive.
class ScormPlayerWidget extends StatefulWidget {
  /// Launch URL from server (signed Supabase Storage URL).
  final String launchUrl;
  
  /// Base URL for resolving relative paths.
  final String baseUrl;
  
  /// Session ID for CMI commits.
  final String sessionId;
  
  /// Package ID for offline buffering.
  final String packageId;
  
  /// Initial CMI data from server.
  final Map<String, dynamic> initialCmiData;
  
  /// Callback when SCORM session finishes.
  final void Function(Map<String, dynamic> finalCmiData)? onFinish;
  
  /// Callback for commit (return true if successful).
  final Future<bool> Function(Map<String, dynamic> cmiData)? onCommit;
  
  /// Whether to show loading indicator.
  final bool showLoading;

  const ScormPlayerWidget({
    super.key,
    required this.launchUrl,
    required this.baseUrl,
    required this.sessionId,
    required this.packageId,
    required this.initialCmiData,
    this.onFinish,
    this.onCommit,
    this.showLoading = true,
  });

  @override
  State<ScormPlayerWidget> createState() => _ScormPlayerWidgetState();
}

class _ScormPlayerWidgetState extends State<ScormPlayerWidget> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  String? _error;
  
  // Offline buffer box
  late Box<Map> _offlineBuffer;
  static const String _bufferBoxName = 'scorm_offline_commits';
  
  @override
  void initState() {
    super.initState();
    _initOfflineBuffer();
  }
  
  Future<void> _initOfflineBuffer() async {
    if (!Hive.isBoxOpen(_bufferBoxName)) {
      _offlineBuffer = await Hive.openBox<Map>(_bufferBoxName);
    } else {
      _offlineBuffer = Hive.box<Map>(_bufferBoxName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.launchUrl)),
          initialSettings: InAppWebViewSettings(
            // Enable JavaScript
            javaScriptEnabled: true,
            // Allow mixed content (http in https)
            mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            // Enable DOM storage
            domStorageEnabled: true,
            // Allow file access
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
            // User agent
            userAgent: 'PharmaLearn SCORM Player/1.0',
            // Disable zooming for consistent SCORM display
            supportZoom: false,
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
            _setupJavaScriptHandlers(controller);
          },
          onLoadStart: (controller, url) {
            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onLoadStop: (controller, url) async {
            // Inject SCORM API shim
            await controller.evaluateJavascript(source: scormApiShimJs);
            
            // Pre-populate CMI data
            final cmiJson = jsonEncode(widget.initialCmiData);
            await controller.evaluateJavascript(
              source: 'window.__PHARMALEARN_SET_CMI_DATA($cmiJson);',
            );
            
            setState(() => _isLoading = false);
          },
          onLoadError: (controller, url, code, message) {
            setState(() {
              _isLoading = false;
              _error = 'Failed to load SCORM content: $message';
            });
          },
          onLoadHttpError: (controller, url, statusCode, description) {
            setState(() {
              _isLoading = false;
              _error = 'HTTP Error $statusCode: $description';
            });
          },
          onConsoleMessage: (controller, consoleMessage) {
            // Log SCORM messages for debugging
            if (consoleMessage.message.contains('[SCORM]')) {
              debugPrint('SCORM: ${consoleMessage.message}');
            }
          },
        ),
        
        // Loading overlay
        if (_isLoading && widget.showLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        
        // Error overlay
        if (_error != null)
          Container(
            color: Colors.white,
            child: Center(
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
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  void _setupJavaScriptHandlers(InAppWebViewController controller) {
    // Handle LMSInitialize
    controller.addJavaScriptHandler(
      handlerName: 'scormInitialize',
      callback: (args) {
        debugPrint('[ScormPlayer] Initialize called');
        return {
          'success': true,
          'cmi_data': widget.initialCmiData,
        };
      },
    );
    
    // Handle LMSCommit
    controller.addJavaScriptHandler(
      handlerName: 'scormCommit',
      callback: (args) async {
        debugPrint('[ScormPlayer] Commit called');
        
        if (args.isEmpty) return {'success': false};
        
        final data = args[0] as Map<String, dynamic>;
        final cmiData = data['cmi_data'] as Map<String, dynamic>?;
        
        if (cmiData == null) return {'success': false};
        
        // Try online commit
        if (widget.onCommit != null) {
          try {
            final success = await widget.onCommit!(cmiData);
            if (success) {
              return {'success': true};
            }
          } catch (e) {
            debugPrint('[ScormPlayer] Online commit failed: $e');
          }
        }
        
        // Buffer offline
        await _bufferCommit(cmiData);
        return {'success': true, 'buffered': true};
      },
    );
    
    // Handle LMSFinish
    controller.addJavaScriptHandler(
      handlerName: 'scormFinish',
      callback: (args) {
        debugPrint('[ScormPlayer] Finish called');
        
        if (args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>;
          final cmiData = data['cmi_data'] as Map<String, dynamic>?;
          
          if (cmiData != null) {
            widget.onFinish?.call(cmiData);
          }
        }
        
        return {'success': true};
      },
    );
  }
  
  /// Buffers CMI commit in Hive for later sync.
  Future<void> _bufferCommit(Map<String, dynamic> cmiData) async {
    final key = '${widget.sessionId}_${DateTime.now().millisecondsSinceEpoch}';
    await _offlineBuffer.put(key, {
      'session_id': widget.sessionId,
      'package_id': widget.packageId,
      'cmi_data': cmiData,
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('[ScormPlayer] Buffered commit: $key');
  }
  
  void _retry() {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    _webViewController?.reload();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}
