import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Authentication service for handling user sign up, sign in, and sign out
class AuthService {
  static final _auth = SupabaseService.client.auth;

  /// Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign in with email and password
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with OAuth provider (Google, Apple, etc.)
  static Future<bool> signInWithOAuth(OAuthProvider provider) async {
    return await _auth.signInWithOAuth(provider);
  }

  /// Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send password reset email
  static Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  /// Get current session
  static Session? get currentSession => _auth.currentSession;

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Check if user is logged in
  static bool get isLoggedIn => currentUser != null;

  /// Listen to auth state changes
  static Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;
}
