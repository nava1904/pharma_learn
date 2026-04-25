import 'dart:convert';

/// Lightweight JWT utility for decoding token payloads.
///
/// NOTE: This implementation decodes without cryptographic signature
/// verification.  Full RS256 / JWKS verification should be added via
/// `dart_jsonwebtoken` once a JWKS cache strategy is in place.
class JwtService {
  JwtService._();

  /// Decodes the payload of a JWT without verifying the signature.
  ///
  /// Throws [FormatException] if [token] is not a well-formed JWT.
  static Map<String, dynamic> decode(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid JWT: expected 3 dot-separated parts.');
    }

    final payload = _decodeBase64(parts[1]);
    final decoded = jsonDecode(utf8.decode(payload));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JWT: payload is not a JSON object.');
    }

    return decoded;
  }

  /// Decodes the header of a JWT without verifying the signature.
  static Map<String, dynamic> decodeHeader(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid JWT: expected 3 dot-separated parts.');
    }

    final header = _decodeBase64(parts[0]);
    final decoded = jsonDecode(utf8.decode(header));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JWT: header is not a JSON object.');
    }

    return decoded;
  }

  /// Returns true if the JWT's `exp` claim is in the past.
  static bool isExpired(Map<String, dynamic> payload) {
    final exp = payload['exp'];
    if (exp == null) return false;

    final expSeconds = exp is int ? exp : int.tryParse(exp.toString()) ?? 0;
    final expiry = DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000, isUtc: true);
    return DateTime.now().toUtc().isAfter(expiry);
  }

  static List<int> _decodeBase64(String segment) {
    // Base64url strings may not be padded — normalize before decoding.
    return base64Url.decode(base64Url.normalize(segment));
  }
}
