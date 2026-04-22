import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/sessions/:id/qr
/// 
/// Generates QR token for session check-in.
/// Only trainers or coordinators can generate QR codes.
Future<Response> sessionQrGenerateHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id]!;
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Permission check - trainer or coordinator
  final canManage = auth.hasPermission('training.sessions.manage') ||
      auth.hasPermission('training.manage');
  if (!canManage) {
    throw PermissionDeniedException('Trainer access required');
  }

  // Get session and verify it's in progress
  final session = await supabase
      .from('training_sessions')
      .select('id, status, end_time, organization_id')
      .eq('id', sessionId)
      .maybeSingle();

  if (session == null) {
    throw NotFoundException('Session not found');
  }

  if (session['status'] != 'in_progress') {
    throw ConflictException('Session must be in progress to generate QR');
  }

  // Generate QR token with HMAC
  final qrSecret = const String.fromEnvironment(
    'QR_SECRET', 
    defaultValue: 'pharmalearn-qr-secret-key-2026'
  );
  
  final expiresAt = session['end_time'] != null 
      ? DateTime.parse(session['end_time'])
      : DateTime.now().toUtc().add(const Duration(hours: 8));

  // Create payload: sessionId|expiresAt|timestamp
  final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
  final payloadData = '$sessionId|${expiresAt.toIso8601String()}|$timestamp';
  final payload = base64Url.encode(utf8.encode(payloadData));
  
  // Create HMAC signature
  final hmac = Hmac(sha256, utf8.encode(qrSecret));
  final signature = hmac.convert(utf8.encode(payload)).toString();
  final qrToken = '$payload.$signature';

  // Store token in session
  await supabase.from('training_sessions').update({
    'qr_token': qrToken,
    'qr_expires_at': expiresAt.toIso8601String(),
  }).eq('id', sessionId);

  return ApiResponse.ok({
    'qr_token': qrToken,
    'qr_expires_at': expiresAt.toIso8601String(),
    'session_id': sessionId,
  }).toResponse();
}

/// POST /v1/train/sessions/:id/qr/validate
/// 
/// Validates a QR code scanned by a trainee.
Future<Response> sessionQrValidateHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id]!;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);
  
  final qrToken = body['qr_token'] as String?;
  if (qrToken == null || qrToken.isEmpty) {
    throw ValidationException({'qr_token': 'QR token is required'});
  }

  // Parse and verify token
  final parts = qrToken.split('.');
  if (parts.length != 2) {
    throw ValidationException({'qr_token': 'Invalid QR token format'});
  }

  final payload = parts[0];
  final signature = parts[1];

  // Verify signature
  final qrSecret = const String.fromEnvironment(
    'QR_SECRET', 
    defaultValue: 'pharmalearn-qr-secret-key-2026'
  );
  final hmac = Hmac(sha256, utf8.encode(qrSecret));
  final expectedSignature = hmac.convert(utf8.encode(payload)).toString();
  
  if (signature != expectedSignature) {
    throw ValidationException({'qr_token': 'Invalid QR token signature'});
  }

  // Decode payload
  String decodedPayload;
  try {
    decodedPayload = utf8.decode(base64Url.decode(payload));
  } catch (e) {
    throw ValidationException({'qr_token': 'Invalid QR token encoding'});
  }

  final payloadParts = decodedPayload.split('|');
  if (payloadParts.length < 2) {
    throw ValidationException({'qr_token': 'Invalid QR token payload'});
  }

  final tokenSessionId = payloadParts[0];
  final expiresAtStr = payloadParts[1];

  // Verify session ID matches
  if (tokenSessionId != sessionId) {
    throw ValidationException({'qr_token': 'QR token does not match session'});
  }

  // Verify not expired
  final expiresAt = DateTime.parse(expiresAtStr);
  if (DateTime.now().toUtc().isAfter(expiresAt)) {
    throw ValidationException({'qr_token': 'QR token has expired'});
  }

  // Verify session is still in progress
  final session = await supabase
      .from('training_sessions')
      .select('id, status')
      .eq('id', sessionId)
      .maybeSingle();

  if (session == null) {
    throw NotFoundException('Session not found');
  }

  if (session['status'] != 'in_progress') {
    throw ConflictException('Session is no longer in progress');
  }

  return ApiResponse.ok({
    'valid': true,
    'session_id': sessionId,
    'expires_at': expiresAtStr,
  }).toResponse();
}
