/// Valid e-signature meaning values per 21 CFR §11.
const List<String> kValidEsigMeanings = [
  'APPROVE',
  'SUBMIT',
  'REVOKE',
  'SIGN',
  'WITNESS',
];

/// Incoming e-signature request payload, typically nested in the request body
/// under the `e_signature` key.
class EsigRequest {
  final String reauthSessionId;

  /// One of: APPROVE | SUBMIT | REVOKE | SIGN | WITNESS
  final String meaning;

  final String reason;
  final bool isFirstInSession;

  const EsigRequest({
    required this.reauthSessionId,
    required this.meaning,
    required this.reason,
    required this.isFirstInSession,
  });

  factory EsigRequest.fromJson(Map<String, dynamic> json) {
    return EsigRequest(
      reauthSessionId: json['reauth_session_id'] as String,
      meaning: json['meaning'] as String,
      reason: json['reason'] as String? ?? '',
      isFirstInSession: json['is_first_in_session'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'reauth_session_id': reauthSessionId,
        'meaning': meaning,
        'reason': reason,
        'is_first_in_session': isFirstInSession,
      };
}

// EsigContext is defined in context/request_context.dart — do not duplicate here.
