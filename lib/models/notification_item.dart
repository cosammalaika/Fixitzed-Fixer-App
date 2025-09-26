class NotificationItem {
  final int id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  NotificationItem({required this.id, required this.title, required this.body, required this.read, required this.createdAt});

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: j['id'] as int,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        read: (j['read'] ?? j['is_read'] ?? false) as bool,
        createdAt: DateTime.parse((j['created_at'] ?? DateTime.now().toIso8601String()) as String),
      );
}

