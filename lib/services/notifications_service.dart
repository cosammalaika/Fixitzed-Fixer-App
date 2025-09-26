import 'dart:convert';
import '../models/notification_item.dart';
import 'api_client.dart';

class NotificationsService {
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
              .toList();
        }
      } else if (root is List) {
        return root
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<bool> markRead(int id) async {
    final res = await _api.patch('/api/notifications/$id/read', body: {});
    return res.statusCode == 200;
  }

  Future<bool> markAllRead() async {
    final res = await _api.post('/api/notifications/read-all', body: {});
    return res.statusCode == 200;
  }
}
