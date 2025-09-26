import 'dart:convert';
import '../models/chat.dart';
import 'api_client.dart';

class ChatService {
  final _api = ApiClient.I;

  Future<List<Conversation>> conversations() async {
    final res = await _api.get('/api/conversations');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Conversation?> createConversation({required int serviceRequestId}) async {
    final res = await _api.post('/api/conversations', body: {
      'service_request_id': serviceRequestId,
    });
    if (res.statusCode == 201 || res.statusCode == 200) {
      return Conversation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    return null;
  }

  Future<List<Message>> messages(int conversationId) async {
    final res = await _api.get('/api/conversations/$conversationId/messages');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Message?> sendMessage(int conversationId, String text) async {
    final res = await _api.post('/api/conversations/$conversationId/messages', body: {
      'text': text,
    });
    if (res.statusCode == 201 || res.statusCode == 200) {
      return Message.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    return null;
  }
}

