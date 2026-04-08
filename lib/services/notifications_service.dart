import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:fixitzed_fixer_app/models/notification_item.dart';
import 'package:fixitzed_fixer_app/services/api_client.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';

class NotificationsLoadResult {
  const NotificationsLoadResult({
    required this.items,
    required this.success,
    required this.usedCacheFallback,
  });

  final List<NotificationItem> items;
  final bool success;
  final bool usedCacheFallback;
}

class NotificationsService {
  NotificationsService({AppSync? sync}) : _sync = sync ?? AppSync.instance;

  final AppSync _sync;
  final _api = ApiClient.I;

  static List<NotificationItem>? _cache;
  static DateTime? _fetchedAt;
  static Future<NotificationsLoadResult>? _inFlight;
  static const Duration _ttl = Duration(minutes: 5);
  static const Duration _minRefreshGap = Duration(seconds: 20);

  Future<List<NotificationItem>> list({bool forceRefresh = false}) async {
    final result = await load(forceRefresh: forceRefresh);
    return result.items;
  }

  Future<NotificationsLoadResult> load({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cached = _cache;
    if (!forceRefresh &&
        cached != null &&
        _fetchedAt != null &&
        now.difference(_fetchedAt!) < _ttl) {
      _log('fetch_skipped_cache', <String, Object?>{'count': cached.length});
      return NotificationsLoadResult(
        items: List<NotificationItem>.from(cached),
        success: true,
        usedCacheFallback: false,
      );
    }

    if (!forceRefresh &&
        cached != null &&
        _fetchedAt != null &&
        now.difference(_fetchedAt!) < _minRefreshGap) {
      return NotificationsLoadResult(
        items: List<NotificationItem>.from(cached),
        success: true,
        usedCacheFallback: false,
      );
    }

    final existing = _inFlight;
    if (existing != null) {
      _log('fetch_deduped');
      return existing;
    }

    final future = _loadFromNetwork();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  Future<NotificationsLoadResult> _loadFromNetwork() async {
    _log('fetch_start');
    try {
      final res = await _api.get('/api/notifications');
      if (res.statusCode == 200) {
        final items = _parseItems(res.body);
        _cache = List<NotificationItem>.from(items);
        _fetchedAt = DateTime.now();
        _log('fetch_success', <String, Object?>{'count': items.length});
        return NotificationsLoadResult(
          items: List<NotificationItem>.from(items),
          success: true,
          usedCacheFallback: false,
        );
      }
      _log('fetch_failure', <String, Object?>{'status': res.statusCode});
    } catch (error) {
      _log('fetch_exception', <String, Object?>{'error': error.toString()});
    }

    final cached = _cache;
    if (cached != null) {
      _log('fetch_cache_fallback', <String, Object?>{'count': cached.length});
      return NotificationsLoadResult(
        items: List<NotificationItem>.from(cached),
        success: false,
        usedCacheFallback: true,
      );
    }

    return const NotificationsLoadResult(
      items: <NotificationItem>[],
      success: false,
      usedCacheFallback: false,
    );
  }

  Future<bool> markRead(int id) async {
    final res = await _api.patch('/api/notifications/$id/read', body: {});
    final ok = res.statusCode == 200;
    if (ok) {
      _cache = _cache
          ?.map(
            (item) => item.id == id
                ? item.copyWith(read: true, readAt: DateTime.now())
                : item,
          )
          .toList();
      _sync.emit(
        AppSyncTopic.notifications,
        payload: <String, dynamic>{'action': 'markRead', 'id': id},
      );
      _sync.emit(
        AppSyncTopic.dashboard,
        payload: const <String, dynamic>{'source': 'notifications'},
      );
    }
    return ok;
  }

  Future<bool> markAllRead() async {
    final res = await _api.post('/api/notifications/read-all', body: {});
    final ok = res.statusCode == 200;
    if (ok) {
      _cache = _cache
          ?.map(
            (item) => item.copyWith(
              read: true,
              readAt: item.readAt ?? DateTime.now(),
            ),
          )
          .toList();
      _sync.emit(
        AppSyncTopic.notifications,
        payload: const <String, dynamic>{'action': 'markAll'},
      );
      _sync.emit(
        AppSyncTopic.dashboard,
        payload: const <String, dynamic>{'source': 'notifications'},
      );
    }
    return ok;
  }

  Future<bool> delete(int id) async {
    final res = await _api.delete('/api/notifications/$id');
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
      _cache = _cache?.where((item) => item.id != id).toList();
      _sync.emit(
        AppSyncTopic.notifications,
        payload: <String, dynamic>{'action': 'delete', 'id': id},
      );
    }
    return ok;
  }

  static void clearCache() {
    _cache = null;
    _fetchedAt = null;
    _inFlight = null;
  }

  List<NotificationItem> _parseItems(String body) {
    final root = jsonDecode(body);
    if (root is Map<String, dynamic>) {
      final data = root['data'];
      final list = (data is Map<String, dynamic>)
          ? (data['data'] as List?)
          : (data as List?);
      if (list != null) {
        return list
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .where(_isForFixerAudience)
            .toList();
      }
    } else if (root is List) {
      return root
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .where(_isForFixerAudience)
          .toList();
    }
    return const <NotificationItem>[];
  }

  bool _isForFixerAudience(NotificationItem item) {
    final type = item.recipientType.trim().toLowerCase();
    if (type.isEmpty || type == 'individual') return true;
    return type == 'fixer' ||
        type == 'fixers' ||
        type == 'all' ||
        type == 'broadcast' ||
        type == 'system';
  }

  void _log(String event, [Map<String, Object?> details = const {}]) {
    if (!kDebugMode) return;
    debugPrint('[FixerNotifications] $event $details');
  }
}
