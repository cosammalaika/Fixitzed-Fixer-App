class NotificationItem {
  final int id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String recipientType;
  final int? userId;
  final Map<String, dynamic> data;
  final int? serviceRequestId;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    required this.recipientType,
    required this.userId,
    required this.data,
    required this.serviceRequestId,
  });

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

    final data = parseMap(j['data']);
    final serviceRequestId =
        parseInt(data['service_request_id']) ??
        parseInt(j['service_request_id']) ??
        parseInt(j['request_id']);

    return NotificationItem(
      id: j['id'] as int,
      title: (j['title'] ?? '') as String,
      body: (j['body'] ?? j['message'] ?? '') as String,
      read: (j['read'] ?? j['is_read'] ?? false) as bool,
      createdAt: DateTime.parse(
        (j['created_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
      recipientType: (j['recipient_type'] ?? '') as String,
      userId: parseInt(j['user_id']),
      data: data,
      serviceRequestId: serviceRequestId,
    );
  }
}
