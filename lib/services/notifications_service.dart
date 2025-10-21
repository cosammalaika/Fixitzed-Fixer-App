import 'dart:convert';
import 'package:fixitzed_fixer_app/models/notification_item.dart';
import 'package:fixitzed_fixer_app/services/api_client.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';

class NotificationsService {
  NotificationsService({AppSync? sync}) : _sync = sync ?? AppSync.instance;

  final AppSync _sync;

  final _api = ApiClient.I;

  Future<List<NotificationItem>> list() async {
    final res = await _api.get('/api/notifications');
    if (res.statusCode == 200) {
      final root = jsonDecode(res.body);
      if (root is Map<String, dynamic>) {
        // paginated: { data: { data: [...] } } or unpaginated: { data: [...] }
        final data = root['data'];
        final list = (data is Map<String, dynamic>) ? (data['data'] as List?) : (data as List?);
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
    }
    return [];
  }

  Future<bool> markRead(int id) async {
    final res = await _api.patch('/api/notifications/$id/read', body: {});
    final ok = res.statusCode == 200;
    if (ok) {
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

  bool _isForFixerAudience(NotificationItem item) {
    final type = item.recipientType.trim().toLowerCase();
    if (type.isEmpty) return true;
    if (type == 'individual') {
      return true;
    }
    if (type == 'fixer' ||
        type == 'fixers' ||
        type == 'all' ||
        type == 'broadcast' ||
        type == 'system') {
      return true;
    }
    return false;
  }
}
