import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_store.g.dart';

/// Authentication state and operations.
/// Handles login, logout, session management, and reauth for e-signatures.
@singleton
class AuthStore = _AuthStoreBase with _$AuthStore;

abstract class _AuthStoreBase with Store {
  final SupabaseClient _supabase;
  final FlutterSecureStorage _secureStorage;
  
  _AuthStoreBase(this._supabase, this._secureStorage) {
    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen(_onAuthStateChange);
  }
  
  // ---------------------------------------------------------------------------
  // Observable State
  // ---------------------------------------------------------------------------
  
  @observable
  User? currentUser;
  
  @observable
  Session? currentSession;
  
  @observable
  Map<String, dynamic>? userProfile;
  
  @observable
  bool isLoading = false;
  
  @observable
  String? errorMessage;
  
  @observable
  DateTime? lastReauthAt;
  
  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------
  
  @computed
  bool get isAuthenticated => currentUser != null && currentSession != null;
  
  @computed
  bool get isInductionCompleted => 
      userProfile?['induction_completed'] as bool? ?? false;
  
  @computed
  String? get employeeId => userProfile?['employee_id'] as String?;
  
  @computed
  String? get orgId => userProfile?['org_id'] as String?;
  
  @computed
  List<String> get permissions {
    final perms = userProfile?['permissions'] as List?;
    return perms?.cast<String>() ?? [];
  }
  
  @computed
  String get displayName {
    if (userProfile == null) return 'User';
    final firstName = userProfile!['first_name'] as String? ?? '';
    final lastName = userProfile!['last_name'] as String? ?? '';
    return '$firstName $lastName'.trim();
  }
  
  /// Returns true if reauth is valid (within 30-minute window).
  @computed
  bool get isReauthValid {
    if (lastReauthAt == null) return false;
    return DateTime.now().difference(lastReauthAt!).inMinutes < 30;
  }
  
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  @action
  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      currentUser = response.user;
      currentSession = response.session;
      
      if (currentUser != null) {
        await _loadUserProfile();
      }
      
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      errorMessage = 'An unexpected error occurred. Please try again.';
      return false;
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<void> logout() async {
    isLoading = true;
    try {
      await _supabase.auth.signOut();
      _clearState();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<bool> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();
      currentSession = response.session;
      currentUser = response.user;
      return currentSession != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Re-authenticate for e-signature operations.
  /// Validates password without creating a new session.
  @action
  Future<bool> reauthenticate(String password) async {
    if (currentUser?.email == null) return false;
    
    isLoading = true;
    errorMessage = null;
    
    try {
      // Verify password by attempting login
      await _supabase.auth.signInWithPassword(
        email: currentUser!.email!,
        password: password,
      );
      
      lastReauthAt = DateTime.now();
      await _secureStorage.write(
        key: 'last_reauth_at',
        value: lastReauthAt!.toIso8601String(),
      );
      
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      errorMessage = 'Authentication failed. Please try again.';
      return false;
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<void> restoreSession() async {
    isLoading = true;
    try {
      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;
      
      if (session != null && user != null) {
        currentSession = session;
        currentUser = user;
        await _loadUserProfile();
        
        // Restore last reauth time
        final reauthStr = await _secureStorage.read(key: 'last_reauth_at');
        if (reauthStr != null) {
          lastReauthAt = DateTime.tryParse(reauthStr);
        }
      }
    } finally {
      isLoading = false;
    }
  }
  
  // ---------------------------------------------------------------------------
  // Permission Helpers
  // ---------------------------------------------------------------------------
  
  bool hasPermission(String permission) => permissions.contains(permission);
  
  bool hasAnyPermission(List<String> perms) => 
      perms.any((p) => permissions.contains(p));
  
  bool hasAllPermissions(List<String> perms) => 
      perms.every((p) => permissions.contains(p));
  
  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------
  
  Future<void> _loadUserProfile() async {
    if (currentUser == null) return;
    
    try {
      // Profile is embedded in JWT claims (set by auth-hook)
      final claims = currentSession?.user.userMetadata;
      if (claims != null) {
        userProfile = Map<String, dynamic>.from(claims);
      }
      
      // Optionally fetch fresh profile from API
      // final response = await _supabase.from('employees')
      //     .select('*, roles(*), permissions(*)')
      //     .eq('auth_user_id', currentUser!.id)
      //     .single();
      // userProfile = response;
    } catch (e) {
      // Log but don't fail
      print('Failed to load user profile: $e');
    }
  }
  
  void _onAuthStateChange(AuthState state) {
    currentUser = state.session?.user;
    currentSession = state.session;
    
    if (state.event == AuthChangeEvent.signedOut) {
      _clearState();
    }
  }
  
  void _clearState() {
    currentUser = null;
    currentSession = null;
    userProfile = null;
    lastReauthAt = null;
    errorMessage = null;
    _secureStorage.delete(key: 'last_reauth_at');
  }
}
