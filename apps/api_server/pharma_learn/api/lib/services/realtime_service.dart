import 'dart:async';

import 'package:supabase/supabase.dart';

/// Service for managing Supabase Realtime channel subscriptions.
///
/// Used for:
/// - Live trainer dashboard updates
/// - Assessment proctoring events
/// - Session attendance real-time sync
/// - Notification delivery
///
/// Reference: plan.md — Supabase Realtime backbone
class RealtimeService {
  final SupabaseClient _supabase;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  RealtimeService(this._supabase);

  /// Subscribes to a table for INSERT, UPDATE, DELETE events.
  ///
  /// Returns a Stream of change events.
  ///
  /// Example:
  /// ```dart
  /// final stream = realtimeService.subscribeToTable(
  ///   'session_attendance',
  ///   filter: 'session_id=eq.$sessionId',
  /// );
  /// stream.listen((event) => print('Attendance changed: $event'));
  /// ```
  Stream<Map<String, dynamic>> subscribeToTable(
    String table, {
    String? schema,
    String? filter,
    List<String>? events, // 'INSERT', 'UPDATE', 'DELETE', '*'
  }) {
    final channelName = _buildChannelName(table, filter);

    if (_controllers.containsKey(channelName)) {
      return _controllers[channelName]!.stream;
    }

    final controller = StreamController<Map<String, dynamic>>.broadcast(
      onCancel: () => _unsubscribe(channelName),
    );
    _controllers[channelName] = controller;

    final channel = _supabase.channel(channelName);

    final postgresChanges = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: filter?.split('=').first ?? 'id',
      value: filter?.split('=').last ?? '*',
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: schema ?? 'public',
      table: table,
      filter: filter != null ? postgresChanges : null,
      callback: (payload) {
        if (!controller.isClosed) {
          controller.add({
            'event': payload.eventType.name,
            'table': table,
            'old_record': payload.oldRecord,
            'new_record': payload.newRecord,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          });
        }
      },
    );

    channel.subscribe();
    _channels[channelName] = channel;

    return controller.stream;
  }

  /// Subscribes to a broadcast channel for custom events.
  ///
  /// Used for:
  /// - Proctoring events (tab switches, focus loss)
  /// - Live dashboard updates
  /// - Custom notifications
  Stream<Map<String, dynamic>> subscribeToBroadcast(
    String channelName, {
    String? event,
  }) {
    final fullChannelName = 'broadcast:$channelName';

    if (_controllers.containsKey(fullChannelName)) {
      return _controllers[fullChannelName]!.stream;
    }

    final controller = StreamController<Map<String, dynamic>>.broadcast(
      onCancel: () => _unsubscribe(fullChannelName),
    );
    _controllers[fullChannelName] = controller;

    final channel = _supabase.channel(fullChannelName);

    channel.onBroadcast(
      event: event ?? '*',
      callback: (payload) {
        if (!controller.isClosed) {
          controller.add({
            'event': event ?? 'broadcast',
            'payload': payload,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          });
        }
      },
    );

    channel.subscribe();
    _channels[fullChannelName] = channel;

    return controller.stream;
  }

  /// Sends a broadcast message to a channel.
  ///
  /// Used for server-to-client notifications.
  Future<void> broadcast(
    String channelName,
    String event,
    Map<String, dynamic> payload,
  ) async {
    final fullChannelName = 'broadcast:$channelName';

    RealtimeChannel channel;
    if (_channels.containsKey(fullChannelName)) {
      channel = _channels[fullChannelName]!;
    } else {
      channel = _supabase.channel(fullChannelName);
      channel.subscribe();
      _channels[fullChannelName] = channel;
    }

    await channel.sendBroadcastMessage(
      event: event,
      payload: payload,
    );
  }

  /// Subscribes to presence updates for a channel.
  ///
  /// Used for:
  /// - Live session participant tracking
  /// - Online/offline status
  Stream<Map<String, dynamic>> subscribeToPresence(String channelName) {
    final fullChannelName = 'presence:$channelName';

    if (_controllers.containsKey(fullChannelName)) {
      return _controllers[fullChannelName]!.stream;
    }

    final controller = StreamController<Map<String, dynamic>>.broadcast(
      onCancel: () => _unsubscribe(fullChannelName),
    );
    _controllers[fullChannelName] = controller;

    final channel = _supabase.channel(fullChannelName);

    channel.onPresenceSync((payload) {
      if (!controller.isClosed) {
        controller.add({
          'event': 'sync',
          'presences': channel.presenceState(),
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });

    channel.onPresenceJoin((payload) {
      if (!controller.isClosed) {
        controller.add({
          'event': 'join',
          'key': payload.key,
          'new_presences': payload.newPresences,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });

    channel.onPresenceLeave((payload) {
      if (!controller.isClosed) {
        controller.add({
          'event': 'leave',
          'key': payload.key,
          'left_presences': payload.leftPresences,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });

    channel.subscribe();
    _channels[fullChannelName] = channel;

    return controller.stream;
  }

  /// Tracks presence for the current user in a channel.
  ///
  /// Used for live session participation tracking.
  Future<void> trackPresence(
    String channelName,
    String userKey,
    Map<String, dynamic> payload,
  ) async {
    final fullChannelName = 'presence:$channelName';

    RealtimeChannel channel;
    if (_channels.containsKey(fullChannelName)) {
      channel = _channels[fullChannelName]!;
    } else {
      channel = _supabase.channel(fullChannelName);
      channel.subscribe();
      _channels[fullChannelName] = channel;
    }

    await channel.track(payload);
  }

  /// Untracks presence for the current user.
  Future<void> untrackPresence(String channelName) async {
    final fullChannelName = 'presence:$channelName';

    if (_channels.containsKey(fullChannelName)) {
      await _channels[fullChannelName]!.untrack();
    }
  }

  /// Subscribes to session attendance updates for live dashboard.
  ///
  /// Reference: plan.md — Relic WS for live trainer dashboard
  Stream<Map<String, dynamic>> subscribeToSessionAttendance(String sessionId) {
    return subscribeToTable(
      'session_attendance',
      filter: 'session_id=eq.$sessionId',
    );
  }

  /// Subscribes to assessment proctoring events.
  ///
  /// Reference: plan.md — Relic WS for proctoring
  Stream<Map<String, dynamic>> subscribeToProctoring(String attemptId) {
    return subscribeToBroadcast(
      'proctoring:$attemptId',
      event: 'proctoring_event',
    );
  }

  /// Sends a proctoring event (tab switch, focus loss, etc.).
  Future<void> sendProctoringEvent(
    String attemptId,
    String eventType,
    Map<String, dynamic> data,
  ) async {
    await broadcast(
      'proctoring:$attemptId',
      'proctoring_event',
      {
        'attempt_id': attemptId,
        'event_type': eventType,
        'data': data,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Subscribes to employee notifications.
  Stream<Map<String, dynamic>> subscribeToNotifications(String employeeId) {
    return subscribeToTable(
      'notifications',
      filter: 'employee_id=eq.$employeeId',
      events: ['INSERT'],
    );
  }

  /// Unsubscribes from a channel.
  Future<void> _unsubscribe(String channelName) async {
    if (_channels.containsKey(channelName)) {
      await _channels[channelName]!.unsubscribe();
      _channels.remove(channelName);
    }

    if (_controllers.containsKey(channelName)) {
      await _controllers[channelName]!.close();
      _controllers.remove(channelName);
    }
  }

  /// Unsubscribes from all channels and cleans up resources.
  Future<void> dispose() async {
    for (final channelName in _channels.keys.toList()) {
      await _unsubscribe(channelName);
    }
  }

  String _buildChannelName(String table, String? filter) {
    if (filter != null) {
      return 'table:$table:$filter';
    }
    return 'table:$table';
  }
}
