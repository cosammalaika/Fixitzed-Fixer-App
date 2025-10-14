class NotificationItem {
  final int id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String recipientType;
  final int? userId;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    required this.recipientType,
    required this.userId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: j['id'] as int,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? j['message'] ?? '') as String,
        read: (j['read'] ?? j['is_read'] ?? false) as bool,
        createdAt: DateTime.parse(
          (j['created_at'] ?? DateTime.now().toIso8601String()) as String,
        ),
        recipientType: (j['recipient_type'] ?? '') as String,
        userId: j['user_id'] is int ? j['user_id'] as int : int.tryParse('${j['user_id']}'),
      );
}
