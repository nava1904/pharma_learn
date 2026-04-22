import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import '../core/api/api_client.dart';

part 'notification_store.g.dart';

/// Store for in-app notifications.
/// Handles notification list, read status, and mark-all.
@singleton
class NotificationStore = _NotificationStoreBase with _$NotificationStore;

abstract class _NotificationStoreBase with Store {
  final ApiClient _api;
  
  _NotificationStoreBase(this._api);
  
  // ---------------------------------------------------------------------------
  // Observable State
  // ---------------------------------------------------------------------------
  
  @observable
  bool isLoading = false;
  
  @observable
  String? errorMessage;
  
  @observable
  ObservableList<AppNotification> notifications = ObservableList<AppNotification>();
  
  @observable
  int unreadCount = 0;
  
  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------
  
  @computed
  List<AppNotification> get unreadNotifications =>
      notifications.where((n) => !n.isRead).toList();
  
  @computed
  bool get hasUnread => unreadCount > 0;
  
  @computed
  List<AppNotification> get recentNotifications =>
      notifications.take(10).toList();
  
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  @action
  Future<void> loadNotifications({int page = 1, int perPage = 20}) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final response = await _api.get(
        '/v1/notifications',
        queryParameters: {'page': page.toString(), 'per_page': perPage.toString()},
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['data']?['notifications'] ?? data['notifications'] ?? [];
      
      if (page == 1) {
        notifications = ObservableList.of(
          (list as List).map((n) => AppNotification.fromJson(n)).toList(),
        );
      } else {
        notifications.addAll(
          (list as List).map((n) => AppNotification.fromJson(n)),
        );
      }
      
      unreadCount = data['unread_count'] ?? 
          notifications.where((n) => !n.isRead).length;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<void> markAsRead(String notificationId) async {
    try {
      await _api.post('/v1/notifications/$notificationId/read');
      
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        notifications[index] = notifications[index].copyWith(isRead: true);
        unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
      }
    } catch (e) {
      errorMessage = e.toString();
    }
  }
  
  @action
  Future<void> markAllAsRead() async {
    try {
      await _api.post('/v1/notifications/mark-all-read');
      
      notifications = ObservableList.of(
        notifications.map((n) => n.copyWith(isRead: true)).toList(),
      );
      unreadCount = 0;
    } catch (e) {
      errorMessage = e.toString();
    }
  }
  
  @action
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _api.delete('/v1/notifications/$notificationId');
      
      final n = notifications.firstWhere(
        (n) => n.id == notificationId,
        orElse: () => notifications.first,
      );
      if (!n.isRead) unreadCount--;
      notifications.removeWhere((n) => n.id == notificationId);
    } catch (e) {
      errorMessage = e.toString();
    }
  }
  
  @action
  void clearError() {
    errorMessage = null;
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;
  
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.data,
  });
  
  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      data: data,
    );
  }
  
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      type: json['type'] ?? 'general',
      title: json['title'] ?? '',
      body: json['body'] ?? json['message'] ?? '',
      isRead: json['is_read'] ?? json['read'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}
