import 'dart:async';

import 'package:relic/relic.dart';

import '../context/request_context.dart';

/// Zone key for audit context.
final _auditContextKey = Object();

/// Middleware that injects audit context into requests.
/// The actual audit trail writing is done by database triggers.
/// This middleware ensures the audit context is available for handlers
/// that need to include audit metadata.
Middleware auditMiddleware() {
  return (handler) {
    return (request) async {
      // Extract audit context from the authenticated user
      final auth = RequestContext.auth;
      
      // Extract client IP
      final clientIp = _extractClientIp(request);
      final userAgent = request.headers['user-agent']?.firstOrNull ?? 'unknown';
      
      // Create audit context
      final auditContext = AuditContext(
        userId: auth.userId,
        employeeId: auth.employeeId,
        orgId: auth.orgId,
        sessionId: auth.sessionId,
        clientIp: clientIp,
        userAgent: userAgent,
        timestamp: DateTime.now().toUtc(),
      );

      // Run handler in a zone with audit context
      return runZoned(
        () => handler(request),
        zoneValues: {_auditContextKey: auditContext},
      );
    };
  };
}

/// Get the current audit context from the zone.
AuditContext? getAuditContext() {
  return Zone.current[_auditContextKey] as AuditContext?;
}

/// Extract client IP from request headers.
/// Handles X-Forwarded-For, X-Real-IP, and direct connection IP.
String _extractClientIp(Request request) {
  // Check X-Forwarded-For (may contain multiple IPs)
  final forwardedFor = request.headers['x-forwarded-for']?.firstOrNull;
  if (forwardedFor != null && forwardedFor.isNotEmpty) {
    // Take the first IP (original client)
    return forwardedFor.split(',').first.trim();
  }

  // Check X-Real-IP
  final realIp = request.headers['x-real-ip']?.firstOrNull;
  if (realIp != null && realIp.isNotEmpty) {
    return realIp;
  }

  // Fallback
  return 'unknown';
}

/// Audit context data for the current request.
class AuditContext {
  final String userId;
  final String employeeId;
  final String orgId;
  final String sessionId;
  final String clientIp;
  final String userAgent;
  final DateTime timestamp;

  const AuditContext({
    required this.userId,
    required this.employeeId,
    required this.orgId,
    required this.sessionId,
    required this.clientIp,
    required this.userAgent,
    required this.timestamp,
  });

  /// Convert to map for database triggers.
  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'employee_id': employeeId,
    'organization_id': orgId,
    'session_id': sessionId,
    'client_ip': clientIp,
    'user_agent': userAgent,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Convert to JSON string for Supabase RLS context.
  String toJsonString() {
    return '{"user_id":"$userId","employee_id":"$employeeId",'
           '"organization_id":"$orgId","session_id":"$sessionId",'
           '"client_ip":"$clientIp","timestamp":"${timestamp.toIso8601String()}"}';
  }
}
