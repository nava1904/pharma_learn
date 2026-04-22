// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$NotificationStore on _NotificationStoreBase, Store {
  Computed<List<AppNotification>>? _$unreadNotificationsComputed;

  @override
  List<AppNotification> get unreadNotifications =>
      (_$unreadNotificationsComputed ??= Computed<List<AppNotification>>(
        () => super.unreadNotifications,
        name: '_NotificationStoreBase.unreadNotifications',
      )).value;
  Computed<bool>? _$hasUnreadComputed;

  @override
  bool get hasUnread => (_$hasUnreadComputed ??= Computed<bool>(
    () => super.hasUnread,
    name: '_NotificationStoreBase.hasUnread',
  )).value;
  Computed<List<AppNotification>>? _$recentNotificationsComputed;

  @override
  List<AppNotification> get recentNotifications =>
      (_$recentNotificationsComputed ??= Computed<List<AppNotification>>(
        () => super.recentNotifications,
        name: '_NotificationStoreBase.recentNotifications',
      )).value;

  late final _$isLoadingAtom = Atom(
    name: '_NotificationStoreBase.isLoading',
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
    name: '_NotificationStoreBase.errorMessage',
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

  late final _$notificationsAtom = Atom(
    name: '_NotificationStoreBase.notifications',
    context: context,
  );

  @override
  ObservableList<AppNotification> get notifications {
    _$notificationsAtom.reportRead();
    return super.notifications;
  }

  @override
  set notifications(ObservableList<AppNotification> value) {
    _$notificationsAtom.reportWrite(value, super.notifications, () {
      super.notifications = value;
    });
  }

  late final _$unreadCountAtom = Atom(
    name: '_NotificationStoreBase.unreadCount',
    context: context,
  );

  @override
  int get unreadCount {
    _$unreadCountAtom.reportRead();
    return super.unreadCount;
  }

  @override
  set unreadCount(int value) {
    _$unreadCountAtom.reportWrite(value, super.unreadCount, () {
      super.unreadCount = value;
    });
  }

  late final _$loadNotificationsAsyncAction = AsyncAction(
    '_NotificationStoreBase.loadNotifications',
    context: context,
  );

  @override
  Future<void> loadNotifications({int page = 1, int perPage = 20}) {
    return _$loadNotificationsAsyncAction.run(
      () => super.loadNotifications(page: page, perPage: perPage),
    );
  }

  late final _$markAsReadAsyncAction = AsyncAction(
    '_NotificationStoreBase.markAsRead',
    context: context,
  );

  @override
  Future<void> markAsRead(String notificationId) {
    return _$markAsReadAsyncAction.run(() => super.markAsRead(notificationId));
  }

  late final _$markAllAsReadAsyncAction = AsyncAction(
    '_NotificationStoreBase.markAllAsRead',
    context: context,
  );

  @override
  Future<void> markAllAsRead() {
    return _$markAllAsReadAsyncAction.run(() => super.markAllAsRead());
  }

  late final _$deleteNotificationAsyncAction = AsyncAction(
    '_NotificationStoreBase.deleteNotification',
    context: context,
  );

  @override
  Future<void> deleteNotification(String notificationId) {
    return _$deleteNotificationAsyncAction.run(
      () => super.deleteNotification(notificationId),
    );
  }

  late final _$_NotificationStoreBaseActionController = ActionController(
    name: '_NotificationStoreBase',
    context: context,
  );

  @override
  void clearError() {
    final _$actionInfo = _$_NotificationStoreBaseActionController.startAction(
      name: '_NotificationStoreBase.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_NotificationStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
notifications: ${notifications},
unreadCount: ${unreadCount},
unreadNotifications: ${unreadNotifications},
hasUnread: ${hasUnread},
recentNotifications: ${recentNotifications}
    ''';
  }
}
