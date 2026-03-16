class NotificationItem {
  final int id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final DateTime? readAt;
  final String recipientType;
  final String type;
  final String? iconKey;
  final int? userId;
  final Map<String, dynamic> data;
  final int? serviceRequestId;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    required this.readAt,
    required this.recipientType,
    required this.type,
    required this.iconKey,
    required this.userId,
    required this.data,
    required this.serviceRequestId,
  });

  NotificationItem copyWith({
    int? id,
    String? title,
    String? body,
    bool? read,
    DateTime? createdAt,
    Object? readAt = _sentinel,
    String? recipientType,
    String? type,
    Object? iconKey = _sentinel,
    int? userId,
    Map<String, dynamic>? data,
    Object? serviceRequestId = _sentinel,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      readAt: identical(readAt, _sentinel) ? this.readAt : readAt as DateTime?,
      recipientType: recipientType ?? this.recipientType,
      type: type ?? this.type,
      iconKey: identical(iconKey, _sentinel)
          ? this.iconKey
          : iconKey as String?,
      userId: userId ?? this.userId,
      data: data ?? this.data,
      serviceRequestId: identical(serviceRequestId, _sentinel)
          ? this.serviceRequestId
          : serviceRequestId as int?,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> parseMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    }

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    String parseString(dynamic value, {String fallback = ''}) {
      if (value == null) return fallback;
      final parsed = value.toString().trim();
      return parsed.isEmpty ? fallback : parsed;
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == '1' ||
            normalized == 'true' ||
            normalized == 'yes' ||
            normalized == 'read';
      }
      return false;
    }

    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value.toLocal();
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value.trim())?.toLocal();
      }
      if (value is int) {
        final milliseconds = value > 9999999999 ? value : value * 1000;
        return DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
      }
      return null;
    }

    final data = parseMap(j['data']);
    final serviceRequestId =
        parseInt(data['service_request_id']) ??
        parseInt(j['service_request_id']) ??
        parseInt(j['request_id']);

    return NotificationItem(
      id: parseInt(j['id']) ?? 0,
      title: parseString(j['title']),
      body: parseString(
        j['body'] ?? j['message'] ?? data['body'] ?? data['message'],
      ),
      read:
          parseBool(j['read'] ?? j['is_read']) ||
          parseDate(j['read_at']) != null,
      createdAt: parseDate(j['created_at'] ?? j['createdAt']) ?? DateTime.now(),
      readAt: parseDate(j['read_at']),
      recipientType: parseString(j['recipient_type']),
      type: parseString(j['type'] ?? data['type'] ?? data['notification_type']),
      iconKey: parseString(
        j['icon'] ?? data['icon'] ?? data['icon_name'] ?? data['icon_key'],
      ),
      userId: parseInt(j['user_id']),
      data: data,
      serviceRequestId: serviceRequestId,
    );
  }
}

const Object _sentinel = Object();
