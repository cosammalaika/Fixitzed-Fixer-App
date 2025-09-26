class Conversation {
  final int id;
  final int? serviceRequestId;
  final int customerId;
  final int fixerId;

  Conversation({required this.id, this.serviceRequestId, required this.customerId, required this.fixerId});

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as int,
        serviceRequestId: j['service_request_id'] as int?,
        customerId: j['customer_id'] as int,
        fixerId: j['fixer_id'] as int,
      );
}

class Message {
  final int id;
  final int conversationId;
  final int senderId;
  final String text;
  final DateTime createdAt;

  Message({required this.id, required this.conversationId, required this.senderId, required this.text, required this.createdAt});

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as int,
        conversationId: j['conversation_id'] as int,
        senderId: j['sender_id'] as int,
        text: (j['text'] ?? '') as String,
        createdAt: DateTime.parse((j['created_at'] ?? DateTime.now().toIso8601String()) as String),
      );
}

