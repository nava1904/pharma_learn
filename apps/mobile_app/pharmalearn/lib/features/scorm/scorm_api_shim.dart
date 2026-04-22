/// SCORM 1.2 API JavaScript shim for flutter_inappwebview.
///
/// Injects `window.API` object that implements SCORM 1.2 RTE functions.
/// All calls are bridged to Dart via postMessage/JavaScriptHandler.

/// JavaScript code to inject into SCORM content WebView.
///
/// This creates a `window.API` object that:
/// 1. Implements all SCORM 1.2 RTE functions
/// 2. Bridges calls to Flutter via `window.flutter_inappwebview.callHandler()`
/// 3. Maintains local CMI data model for immediate Get/Set operations
/// 4. Queues commits for batch processing
const String scormApiShimJs = r'''
(function() {
  'use strict';
  
  // Prevent double injection
  if (window.__PHARMALEARN_SCORM_INJECTED) return;
  window.__PHARMALEARN_SCORM_INJECTED = true;
  
  // ---------------------------------------------------------------------------
  // SCORM 1.2 Error Codes
  // ---------------------------------------------------------------------------
  var ERROR_CODES = {
    NO_ERROR: '0',
    GENERAL_EXCEPTION: '101',
    INVALID_ARGUMENT_ERROR: '201',
    ELEMENT_CANNOT_HAVE_CHILDREN: '202',
    ELEMENT_NOT_AN_ARRAY: '203',
    NOT_INITIALIZED: '301',
    NOT_IMPLEMENTED: '401',
    INVALID_SET_VALUE: '402',
    ELEMENT_IS_READ_ONLY: '403',
    ELEMENT_IS_WRITE_ONLY: '404',
    INCORRECT_DATA_TYPE: '405'
  };
  
  // ---------------------------------------------------------------------------
  // CMI Data Model
  // ---------------------------------------------------------------------------
  var _initialized = false;
  var _terminated = false;
  var _lastError = ERROR_CODES.NO_ERROR;
  var _commitPending = false;
  
  // CMI data - populated on LMSInitialize from server
  var _cmiData = {
    'cmi.core.lesson_status': 'not attempted',
    'cmi.core.lesson_location': '',
    'cmi.core.entry': 'ab-initio',
    'cmi.core.score.raw': '',
    'cmi.core.score.min': '',
    'cmi.core.score.max': '',
    'cmi.core.total_time': '0000:00:00',
    'cmi.core.session_time': '0000:00:00',
    'cmi.suspend_data': '',
    'cmi.core.credit': 'credit',
    'cmi.core.lesson_mode': 'normal',
    'cmi.core.student_id': '',
    'cmi.core.student_name': '',
    'cmi.launch_data': '',
    'cmi.comments': '',
    'cmi.comments_from_lms': ''
  };
  
  // Read-only elements
  var READ_ONLY = [
    'cmi.core.student_id',
    'cmi.core.student_name',
    'cmi.core.credit',
    'cmi.core.lesson_mode',
    'cmi.core.entry',
    'cmi.core.total_time',
    'cmi.launch_data',
    'cmi.comments_from_lms',
    'cmi._version'
  ];
  
  // Write-only elements
  var WRITE_ONLY = [
    'cmi.core.exit',
    'cmi.core.session_time'
  ];
  
  // ---------------------------------------------------------------------------
  // SCORM 1.2 API Implementation
  // ---------------------------------------------------------------------------
  window.API = {
    
    LMSInitialize: function(param) {
      console.log('[SCORM] LMSInitialize called');
      
      if (param !== '') {
        _lastError = ERROR_CODES.INVALID_ARGUMENT_ERROR;
        return 'false';
      }
      
      if (_initialized) {
        _lastError = ERROR_CODES.NO_ERROR;
        return 'true';
      }
      
      if (_terminated) {
        _lastError = ERROR_CODES.GENERAL_EXCEPTION;
        return 'false';
      }
      
      // Synchronously request CMI data from Flutter
      try {
        var result = window.flutter_inappwebview.callHandler('scormInitialize', {});
        if (result && result.success) {
          // Merge server CMI data
          if (result.cmi_data) {
            for (var key in result.cmi_data) {
              _cmiData[key] = result.cmi_data[key];
            }
          }
          _initialized = true;
          _lastError = ERROR_CODES.NO_ERROR;
          console.log('[SCORM] Initialized successfully');
          return 'true';
        }
      } catch (e) {
        console.error('[SCORM] Initialize error:', e);
      }
      
      // Fallback: initialize locally
      _initialized = true;
      _lastError = ERROR_CODES.NO_ERROR;
      return 'true';
    },
    
    LMSFinish: function(param) {
      console.log('[SCORM] LMSFinish called');
      
      if (param !== '') {
        _lastError = ERROR_CODES.INVALID_ARGUMENT_ERROR;
        return 'false';
      }
      
      if (!_initialized) {
        _lastError = ERROR_CODES.NOT_INITIALIZED;
        return 'false';
      }
      
      // Commit any pending data
      this.LMSCommit('');
      
      // Notify Flutter
      try {
        window.flutter_inappwebview.callHandler('scormFinish', {
          cmi_data: _cmiData
        });
      } catch (e) {
        console.error('[SCORM] Finish error:', e);
      }
      
      _terminated = true;
      _initialized = false;
      _lastError = ERROR_CODES.NO_ERROR;
      console.log('[SCORM] Finished successfully');
      return 'true';
    },
    
    LMSGetValue: function(element) {
      if (!_initialized) {
        _lastError = ERROR_CODES.NOT_INITIALIZED;
        return '';
      }
      
      if (!element || typeof element !== 'string') {
        _lastError = ERROR_CODES.INVALID_ARGUMENT_ERROR;
        return '';
      }
      
      // Check write-only
      if (WRITE_ONLY.indexOf(element) !== -1) {
        _lastError = ERROR_CODES.ELEMENT_IS_WRITE_ONLY;
        return '';
      }
      
      // Special handling for _count elements
      if (element.match(/_count$/)) {
        var prefix = element.replace(/_count$/, '');
        var count = 0;
        for (var key in _cmiData) {
          if (key.indexOf(prefix + '.') === 0) {
            var match = key.match(new RegExp('^' + prefix.replace('.', '\\.') + '\\.(\\d+)'));
            if (match) {
              var idx = parseInt(match[1], 10);
              if (idx >= count) count = idx + 1;
            }
          }
        }
        _lastError = ERROR_CODES.NO_ERROR;
        return count.toString();
      }
      
      // Return value if exists
      if (_cmiData.hasOwnProperty(element)) {
        _lastError = ERROR_CODES.NO_ERROR;
        return _cmiData[element];
      }
      
      // Element not found
      _lastError = ERROR_CODES.INVALID_ARGUMENT_ERROR;
      return '';
    },
    
    LMSSetValue: function(element, value) {
      if (!_initialized) {
        _lastError = ERROR_CODES.NOT_INITIALIZED;
        return 'false';
      }
      
      if (!element || typeof element !== 'string') {
        _lastError = ERROR_CODES.INVALID_ARGUMENT_ERROR;
        return 'false';
      }
      
      // Check read-only
      if (READ_ONLY.indexOf(element) !== -1) {
        _lastError = ERROR_CODES.ELEMENT_IS_READ_ONLY;
        return 'false';
      }
      
      // Validate specific elements
      if (element === 'cmi.core.lesson_status') {
        var validStatuses = ['passed', 'completed', 'failed', 'incomplete', 'browsed', 'not attempted'];
        if (validStatuses.indexOf(value) === -1) {
          _lastError = ERROR_CODES.INVALID_SET_VALUE;
          return 'false';
        }
      }
      
      if (element === 'cmi.core.exit') {
        var validExits = ['time-out', 'suspend', 'logout', ''];
        if (validExits.indexOf(value) === -1) {
          _lastError = ERROR_CODES.INVALID_SET_VALUE;
          return 'false';
        }
      }
      
      // Store value
      _cmiData[element] = value;
      _commitPending = true;
      _lastError = ERROR_CODES.NO_ERROR;
      
      console.log('[SCORM] SetValue:', element, '=', value);
      return 'true';
    },
    
    LMSCommit: function(param) {
      console.log('[SCORM] LMSCommit called');
      
      if (param !== '') {
        _lastError = ERROR_CODES.INVALID_ARGUMENT_ERROR;
        return 'false';
      }
      
      if (!_initialized) {
        _lastError = ERROR_CODES.NOT_INITIALIZED;
        return 'false';
      }
      
      if (!_commitPending) {
        _lastError = ERROR_CODES.NO_ERROR;
        return 'true';
      }
      
      // Send to Flutter
      try {
        window.flutter_inappwebview.callHandler('scormCommit', {
          cmi_data: _cmiData
        });
        _commitPending = false;
        _lastError = ERROR_CODES.NO_ERROR;
        console.log('[SCORM] Committed successfully');
        return 'true';
      } catch (e) {
        console.error('[SCORM] Commit error:', e);
        _lastError = ERROR_CODES.GENERAL_EXCEPTION;
        return 'false';
      }
    },
    
    LMSGetLastError: function() {
      return _lastError;
    },
    
    LMSGetErrorString: function(errorCode) {
      var errorStrings = {
        '0': 'No Error',
        '101': 'General Exception',
        '201': 'Invalid Argument Error',
        '202': 'Element Cannot Have Children',
        '203': 'Element Not An Array',
        '301': 'Not Initialized',
        '401': 'Not Implemented Error',
        '402': 'Invalid Set Value',
        '403': 'Element Is Read Only',
        '404': 'Element Is Write Only',
        '405': 'Incorrect Data Type'
      };
      return errorStrings[errorCode] || 'Unknown Error';
    },
    
    LMSGetDiagnostic: function(errorCode) {
      return this.LMSGetErrorString(errorCode);
    }
  };
  
  // ---------------------------------------------------------------------------
  // Helper to inject initial CMI data (called from Flutter before load)
  // ---------------------------------------------------------------------------
  window.__PHARMALEARN_SET_CMI_DATA = function(data) {
    if (data && typeof data === 'object') {
      for (var key in data) {
        _cmiData[key] = data[key];
      }
      console.log('[SCORM] CMI data pre-populated');
    }
  };
  
  console.log('[SCORM] PharmaLearn SCORM 1.2 API shim loaded');
})();
''';
