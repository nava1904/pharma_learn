import 'package:supabase/supabase.dart';

/// Service wrapper for password validation RPC.
/// Used for e-signature re-authentication per 21 CFR §11.200.
class PasswordService {
  final SupabaseClient _supabase;

  PasswordService(this._supabase);

  /// Validate a user's password against their stored credentials.
  ///
  /// [userId] - GoTrue user UUID
  /// [password] - Plain text password to validate
  /// Returns true if password is valid, false otherwise.
  Future<bool> validatePassword({
    required String userId,
    required String password,
  }) async {
    try {
      final result = await _supabase.rpc(
        'validate_credential',
        params: {
          'p_user_id': userId,
          'p_password': password,
        },
      );
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Validate password and get detailed result.
  ///
  /// [userId] - GoTrue user UUID
  /// [password] - Plain text password to validate
  /// Returns validation result with reason if failed.
  Future<PasswordValidationResult> validateWithDetails({
    required String userId,
    required String password,
  }) async {
    try {
      final result = await _supabase.rpc(
        'validate_credential_detailed',
        params: {
          'p_user_id': userId,
          'p_password': password,
        },
      );

      if (result == null) {
        return PasswordValidationResult(
          valid: false,
          reason: 'User not found',
        );
      }

      return PasswordValidationResult(
        valid: result['valid'] == true,
        reason: result['reason'] as String?,
        attemptsRemaining: result['attempts_remaining'] as int?,
        lockedUntil: result['locked_until'] != null
            ? DateTime.parse(result['locked_until'])
            : null,
      );
    } catch (e) {
      return PasswordValidationResult(
        valid: false,
        reason: 'Validation error: $e',
      );
    }
  }

  /// Record a failed login attempt for lockout tracking.
  ///
  /// [userId] - GoTrue user UUID
  Future<void> recordFailedAttempt(String userId) async {
    await _supabase.rpc(
      'record_failed_login',
      params: {'p_user_id': userId},
    );
  }

  /// Reset failed login attempts after successful login.
  ///
  /// [userId] - GoTrue user UUID
  Future<void> resetFailedAttempts(String userId) async {
    await _supabase.rpc(
      'reset_failed_logins',
      params: {'p_user_id': userId},
    );
  }

  /// Check if account is locked.
  ///
  /// [userId] - GoTrue user UUID
  /// Returns lock status and unlock time if locked.
  Future<AccountLockStatus> checkLockStatus(String userId) async {
    try {
      final result = await _supabase.rpc(
        'check_account_lock',
        params: {'p_user_id': userId},
      );

      if (result == null) {
        return AccountLockStatus(isLocked: false);
      }

      return AccountLockStatus(
        isLocked: result['is_locked'] == true,
        lockedUntil: result['locked_until'] != null
            ? DateTime.parse(result['locked_until'])
            : null,
        failedAttempts: result['failed_attempts'] as int? ?? 0,
      );
    } catch (e) {
      return AccountLockStatus(isLocked: false);
    }
  }

  /// Unlock a locked account (admin only).
  ///
  /// [userId] - GoTrue user UUID
  Future<void> unlockAccount(String userId) async {
    await _supabase.rpc(
      'unlock_account',
      params: {'p_user_id': userId},
    );
  }

  /// Change password for a user.
  ///
  /// [userId] - GoTrue user UUID
  /// [currentPassword] - Current password for verification
  /// [newPassword] - New password to set
  /// Returns true if password was changed successfully.
  Future<bool> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    // First validate current password
    final isValid = await validatePassword(
      userId: userId,
      password: currentPassword,
    );

    if (!isValid) {
      return false;
    }

    // Change password via GoTrue admin API
    try {
      await _supabase.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(password: newPassword),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Result of password validation.
class PasswordValidationResult {
  final bool valid;
  final String? reason;
  final int? attemptsRemaining;
  final DateTime? lockedUntil;

  const PasswordValidationResult({
    required this.valid,
    this.reason,
    this.attemptsRemaining,
    this.lockedUntil,
  });

  bool get isLocked => lockedUntil != null && lockedUntil!.isAfter(DateTime.now());
}

/// Account lock status.
class AccountLockStatus {
  final bool isLocked;
  final DateTime? lockedUntil;
  final int failedAttempts;

  const AccountLockStatus({
    required this.isLocked,
    this.lockedUntil,
    this.failedAttempts = 0,
  });

  /// Remaining lock duration.
  Duration? get remainingLockDuration {
    if (!isLocked || lockedUntil == null) return null;
    final remaining = lockedUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }
}
