import 'dart:convert';
import 'package:fixitzed_fixer_app/services/api_client.dart';

class SubscriptionService {
  final _api = ApiClient.I;

  Future<Map<String, dynamic>?> mySubscription() async {
    final res = await _api.get('/api/subscriptions/me');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> paymentHistory() async {
    final res = await _api.get('/api/payments/history');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>?> purchase({
    required int planId,
    required String method,
    int loyaltyPoints = 0,
  }) async {
    final payload = {
      'plan_id': planId,
      'payment_method': method,
      if (loyaltyPoints > 0) 'loyalty_points': loyaltyPoints,
    };
    final res = await _api.post('/api/subscription/checkout', body: payload);
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {}

    if (res.statusCode == 201 || res.statusCode == 200) {
      return body;
    }

    if (body != null) {
      final response = <String, dynamic>{
        'success': false,
        'message': _extractMessage(body),
      };
      if (body['data'] != null) {
        response['data'] = body['data'];
      }
      return response;
    }

    return {
      'success': false,
      'message': 'Unable to complete purchase. Please try again.',
    };
  }

  String _extractMessage(Map<String, dynamic> body) {
    final message = body['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    final errors = body['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is String && first.trim().isNotEmpty) {
            return first;
          }
        }
      }
    }

    return 'Unable to complete purchase. Please try again.';
  }
}
