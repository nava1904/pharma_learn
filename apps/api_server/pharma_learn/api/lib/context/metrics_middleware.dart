/// PharmaLearn Prometheus Metrics Middleware
/// 
/// Collects and exposes metrics for monitoring:
/// - HTTP request counts and latencies
/// - Business metrics (e-signatures, failed logins, rate limits)
/// - System metrics (events outbox pending)
library;

// ─────────────────────────────────────────────────────────────────────────────
// Metric Types
// ─────────────────────────────────────────────────────────────────────────────

/// Counter metric with labels
class Counter {
  final String name;
  final String help;
  final List<String> labelNames;
  final Map<String, int> _values = {};

  Counter({
    required this.name,
    required this.help,
    this.labelNames = const [],
  });

  void increment([Map<String, String>? labels]) {
    final key = _labelKey(labels);
    _values[key] = (_values[key] ?? 0) + 1;
  }

  void add(int value, [Map<String, String>? labels]) {
    final key = _labelKey(labels);
    _values[key] = (_values[key] ?? 0) + value;
  }

  String _labelKey(Map<String, String>? labels) {
    if (labels == null || labels.isEmpty) return '';
    final parts = labelNames.map((name) => '${name}="${labels[name] ?? ""}"');
    return '{${parts.join(',')}}';
  }

  String toPrometheus() {
    final buffer = StringBuffer();
    buffer.writeln('# HELP $name $help');
    buffer.writeln('# TYPE $name counter');
    for (final entry in _values.entries) {
      buffer.writeln('$name${entry.key} ${entry.value}');
    }
    return buffer.toString();
  }
}

/// Gauge metric with labels
class Gauge {
  final String name;
  final String help;
  final List<String> labelNames;
  final Map<String, double> _values = {};

  Gauge({
    required this.name,
    required this.help,
    this.labelNames = const [],
  });

  void set(double value, [Map<String, String>? labels]) {
    final key = _labelKey(labels);
    _values[key] = value;
  }

  void increment([Map<String, String>? labels]) {
    final key = _labelKey(labels);
    _values[key] = (_values[key] ?? 0) + 1;
  }

  void decrement([Map<String, String>? labels]) {
    final key = _labelKey(labels);
    _values[key] = (_values[key] ?? 0) - 1;
  }

  String _labelKey(Map<String, String>? labels) {
    if (labels == null || labels.isEmpty) return '';
    final parts = labelNames.map((name) => '${name}="${labels[name] ?? ""}"');
    return '{${parts.join(',')}}';
  }

  String toPrometheus() {
    final buffer = StringBuffer();
    buffer.writeln('# HELP $name $help');
    buffer.writeln('# TYPE $name gauge');
    for (final entry in _values.entries) {
      buffer.writeln('$name${entry.key} ${entry.value}');
    }
    return buffer.toString();
  }
}

/// Histogram metric for measuring distributions (e.g., response times)
class Histogram {
  final String name;
  final String help;
  final List<String> labelNames;
  final List<double> buckets;
  final Map<String, _HistogramData> _data = {};

  Histogram({
    required this.name,
    required this.help,
    this.labelNames = const [],
    this.buckets = const [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  });

  void observe(double value, [Map<String, String>? labels]) {
    final key = _labelKey(labels);
    final data = _data.putIfAbsent(key, () => _HistogramData(buckets));
    data.observe(value);
  }

  String _labelKey(Map<String, String>? labels) {
    if (labels == null || labels.isEmpty) return '';
    final parts = labelNames.map((name) => '${name}="${labels[name] ?? ""}"');
    return '{${parts.join(',')}}';
  }

  String toPrometheus() {
    final buffer = StringBuffer();
    buffer.writeln('# HELP $name $help');
    buffer.writeln('# TYPE $name histogram');
    
    for (final entry in _data.entries) {
      final labelPrefix = entry.key.isEmpty ? '' : entry.key.replaceAll('}', ',');
      final data = entry.value;
      
      for (var i = 0; i < buckets.length; i++) {
        final le = buckets[i];
        final leLabel = entry.key.isEmpty 
            ? '{le="$le"}' 
            : '${labelPrefix}le="$le"}';
        buffer.writeln('${name}_bucket$leLabel ${data.bucketCounts[i]}');
      }
      
      final infLabel = entry.key.isEmpty 
          ? '{le="+Inf"}' 
          : '${labelPrefix}le="+Inf"}';
      buffer.writeln('${name}_bucket$infLabel ${data.count}');
      
      final sumLabel = entry.key.isEmpty ? '' : entry.key;
      buffer.writeln('${name}_sum$sumLabel ${data.sum}');
      buffer.writeln('${name}_count$sumLabel ${data.count}');
    }
    return buffer.toString();
  }
}

class _HistogramData {
  final List<double> buckets;
  late final List<int> bucketCounts;
  double sum = 0;
  int count = 0;

  _HistogramData(this.buckets) {
    bucketCounts = List.filled(buckets.length, 0);
  }

  void observe(double value) {
    sum += value;
    count++;
    for (var i = 0; i < buckets.length; i++) {
      if (value <= buckets[i]) {
        bucketCounts[i]++;
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metrics Registry
// ─────────────────────────────────────────────────────────────────────────────

/// Global metrics registry for PharmaLearn
class MetricsRegistry {
  static final MetricsRegistry instance = MetricsRegistry._();
  
  MetricsRegistry._();

  // ───────────────────────────────────────────────────────────────────────────
  // HTTP Metrics
  // ───────────────────────────────────────────────────────────────────────────
  
  /// Total HTTP requests counter
  final pharmaApiRequestsTotal = Counter(
    name: 'pharma_api_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status'],
  );

  /// HTTP response time histogram (in milliseconds)
  final pharmaApiResponseMs = Histogram(
    name: 'pharma_api_response_ms',
    help: 'HTTP response time in milliseconds',
    labelNames: ['route'],
    buckets: [5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000],
  );

  // ───────────────────────────────────────────────────────────────────────────
  // Business Metrics
  // ───────────────────────────────────────────────────────────────────────────

  /// Events outbox pending gauge
  final pharmaEventsOutboxPending = Gauge(
    name: 'pharma_events_outbox_pending',
    help: 'Number of events pending in outbox',
  );

  /// Failed login attempts counter
  final pharmaFailedLoginsTotal = Counter(
    name: 'pharma_failed_logins_total',
    help: 'Total number of failed login attempts',
  );

  /// E-signature operations counter
  final pharmaEsigOperationsTotal = Counter(
    name: 'pharma_esig_operations_total',
    help: 'Total number of e-signature operations',
    labelNames: ['meaning'],
  );

  /// Rate limit hits counter
  final pharmaRateLimitHitsTotal = Counter(
    name: 'pharma_rate_limit_hits_total',
    help: 'Total number of rate limit hits',
    labelNames: ['endpoint'],
  );

  // ───────────────────────────────────────────────────────────────────────────
  // Additional System Metrics
  // ───────────────────────────────────────────────────────────────────────────

  /// Active connections gauge
  final pharmaActiveConnections = Gauge(
    name: 'pharma_active_connections',
    help: 'Number of active HTTP connections',
  );

  /// Database query time histogram
  final pharmaDatabaseQueryMs = Histogram(
    name: 'pharma_database_query_ms',
    help: 'Database query time in milliseconds',
    labelNames: ['operation'],
    buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000],
  );

  /// SCORM packages uploaded counter
  final pharmaScormPackagesTotal = Counter(
    name: 'pharma_scorm_packages_total',
    help: 'Total number of SCORM packages uploaded',
    labelNames: ['status'],
  );

  /// Training completions counter
  final pharmaTrainingCompletionsTotal = Counter(
    name: 'pharma_training_completions_total',
    help: 'Total number of training completions',
    labelNames: ['content_type'],
  );

  /// Export metrics to Prometheus format
  String export() {
    final buffer = StringBuffer();
    
    // HTTP metrics
    buffer.write(pharmaApiRequestsTotal.toPrometheus());
    buffer.write(pharmaApiResponseMs.toPrometheus());
    
    // Business metrics
    buffer.write(pharmaEventsOutboxPending.toPrometheus());
    buffer.write(pharmaFailedLoginsTotal.toPrometheus());
    buffer.write(pharmaEsigOperationsTotal.toPrometheus());
    buffer.write(pharmaRateLimitHitsTotal.toPrometheus());
    
    // System metrics
    buffer.write(pharmaActiveConnections.toPrometheus());
    buffer.write(pharmaDatabaseQueryMs.toPrometheus());
    buffer.write(pharmaScormPackagesTotal.toPrometheus());
    buffer.write(pharmaTrainingCompletionsTotal.toPrometheus());
    
    return buffer.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Request Recording Functions
// ─────────────────────────────────────────────────────────────────────────────

/// Record an HTTP request for metrics.
/// Call at the end of each request handler.
void recordHttpRequest({
  required String method,
  required String path,
  required int statusCode,
  required int durationMs,
}) {
  final registry = MetricsRegistry.instance;
  final route = _normalizeRoute(path);
  
  // Record request count
  registry.pharmaApiRequestsTotal.increment({
    'method': method,
    'route': route,
    'status': statusCode.toString(),
  });

  // Record response time
  registry.pharmaApiResponseMs.observe(durationMs.toDouble(), {
    'route': route,
  });
}

/// Normalize route by replacing dynamic segments
String _normalizeRoute(String path) {
  // Replace UUIDs
  var normalized = path.replaceAll(
    RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'),
    ':id',
  );
  // Replace numeric IDs
  normalized = normalized.replaceAll(RegExp(r'/\d+(?=/|$)'), '/:id');
  return normalized;
}

// ─────────────────────────────────────────────────────────────────────────────
// Convenience Functions
// ─────────────────────────────────────────────────────────────────────────────

/// Record a failed login attempt
void recordFailedLogin() {
  MetricsRegistry.instance.pharmaFailedLoginsTotal.increment();
}

/// Record an e-signature operation
void recordEsigOperation(String meaning) {
  MetricsRegistry.instance.pharmaEsigOperationsTotal.increment({
    'meaning': meaning,
  });
}

/// Record a rate limit hit
void recordRateLimitHit(String endpoint) {
  MetricsRegistry.instance.pharmaRateLimitHitsTotal.increment({
    'endpoint': endpoint,
  });
}

/// Update events outbox pending count
void updateEventsOutboxPending(int count) {
  MetricsRegistry.instance.pharmaEventsOutboxPending.set(count.toDouble());
}

/// Record database query time
void recordDatabaseQuery(String operation, int durationMs) {
  MetricsRegistry.instance.pharmaDatabaseQueryMs.observe(
    durationMs.toDouble(),
    {'operation': operation},
  );
}

/// Record SCORM package upload
void recordScormUpload(String status) {
  MetricsRegistry.instance.pharmaScormPackagesTotal.increment({
    'status': status,
  });
}

/// Record training completion
void recordTrainingCompletion(String contentType) {
  MetricsRegistry.instance.pharmaTrainingCompletionsTotal.increment({
    'content_type': contentType,
  });
}

/// Get metrics export string in Prometheus format
String getMetricsExport() {
  return MetricsRegistry.instance.export();
}
