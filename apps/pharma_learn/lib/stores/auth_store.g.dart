// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AuthStore on _AuthStoreBase, Store {
  Computed<bool>? _$isAuthenticatedComputed;

  @override
  bool get isAuthenticated => (_$isAuthenticatedComputed ??= Computed<bool>(
    () => super.isAuthenticated,
    name: '_AuthStoreBase.isAuthenticated',
  )).value;
  Computed<bool>? _$isInductionCompletedComputed;

  @override
  bool get isInductionCompleted =>
      (_$isInductionCompletedComputed ??= Computed<bool>(
        () => super.isInductionCompleted,
        name: '_AuthStoreBase.isInductionCompleted',
      )).value;
  Computed<String?>? _$employeeIdComputed;

  @override
  String? get employeeId => (_$employeeIdComputed ??= Computed<String?>(
    () => super.employeeId,
    name: '_AuthStoreBase.employeeId',
  )).value;
  Computed<String?>? _$orgIdComputed;

  @override
  String? get orgId => (_$orgIdComputed ??= Computed<String?>(
    () => super.orgId,
    name: '_AuthStoreBase.orgId',
  )).value;
  Computed<List<String>>? _$permissionsComputed;

  @override
  List<String> get permissions =>
      (_$permissionsComputed ??= Computed<List<String>>(
        () => super.permissions,
        name: '_AuthStoreBase.permissions',
      )).value;
  Computed<String>? _$displayNameComputed;

  @override
  String get displayName => (_$displayNameComputed ??= Computed<String>(
    () => super.displayName,
    name: '_AuthStoreBase.displayName',
  )).value;
  Computed<bool>? _$isReauthValidComputed;

  @override
  bool get isReauthValid => (_$isReauthValidComputed ??= Computed<bool>(
    () => super.isReauthValid,
    name: '_AuthStoreBase.isReauthValid',
  )).value;

  late final _$currentUserAtom = Atom(
    name: '_AuthStoreBase.currentUser',
    context: context,
  );

  @override
  User? get currentUser {
    _$currentUserAtom.reportRead();
    return super.currentUser;
  }

  @override
  set currentUser(User? value) {
    _$currentUserAtom.reportWrite(value, super.currentUser, () {
      super.currentUser = value;
    });
  }

  late final _$currentSessionAtom = Atom(
    name: '_AuthStoreBase.currentSession',
    context: context,
  );

  @override
  Session? get currentSession {
    _$currentSessionAtom.reportRead();
    return super.currentSession;
  }

  @override
  set currentSession(Session? value) {
    _$currentSessionAtom.reportWrite(value, super.currentSession, () {
      super.currentSession = value;
    });
  }

  late final _$userProfileAtom = Atom(
    name: '_AuthStoreBase.userProfile',
    context: context,
  );

  @override
  Map<String, dynamic>? get userProfile {
    _$userProfileAtom.reportRead();
    return super.userProfile;
  }

  @override
  set userProfile(Map<String, dynamic>? value) {
    _$userProfileAtom.reportWrite(value, super.userProfile, () {
      super.userProfile = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_AuthStoreBase.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: '_AuthStoreBase.errorMessage',
    context: context,
  );

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$lastReauthAtAtom = Atom(
    name: '_AuthStoreBase.lastReauthAt',
    context: context,
  );

  @override
  DateTime? get lastReauthAt {
    _$lastReauthAtAtom.reportRead();
    return super.lastReauthAt;
  }

  @override
  set lastReauthAt(DateTime? value) {
    _$lastReauthAtAtom.reportWrite(value, super.lastReauthAt, () {
      super.lastReauthAt = value;
    });
  }

  late final _$loginAsyncAction = AsyncAction(
    '_AuthStoreBase.login',
    context: context,
  );

  @override
  Future<bool> login(String email, String password) {
    return _$loginAsyncAction.run(() => super.login(email, password));
  }

  late final _$logoutAsyncAction = AsyncAction(
    '_AuthStoreBase.logout',
    context: context,
  );

  @override
  Future<void> logout() {
    return _$logoutAsyncAction.run(() => super.logout());
  }

  late final _$refreshSessionAsyncAction = AsyncAction(
    '_AuthStoreBase.refreshSession',
    context: context,
  );

  @override
  Future<bool> refreshSession() {
    return _$refreshSessionAsyncAction.run(() => super.refreshSession());
  }

  late final _$reauthenticateAsyncAction = AsyncAction(
    '_AuthStoreBase.reauthenticate',
    context: context,
  );

  @override
  Future<bool> reauthenticate(String password) {
    return _$reauthenticateAsyncAction.run(
      () => super.reauthenticate(password),
    );
  }

  late final _$restoreSessionAsyncAction = AsyncAction(
    '_AuthStoreBase.restoreSession',
    context: context,
  );

  @override
  Future<void> restoreSession() {
    return _$restoreSessionAsyncAction.run(() => super.restoreSession());
  }

  @override
  String toString() {
    return '''
currentUser: ${currentUser},
currentSession: ${currentSession},
userProfile: ${userProfile},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
lastReauthAt: ${lastReauthAt},
isAuthenticated: ${isAuthenticated},
isInductionCompleted: ${isInductionCompleted},
employeeId: ${employeeId},
orgId: ${orgId},
permissions: ${permissions},
displayName: ${displayName},
isReauthValid: ${isReauthValid}
    ''';
  }
}
