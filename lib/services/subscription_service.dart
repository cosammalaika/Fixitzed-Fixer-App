import 'dart:convert';
import '../models/subscription.dart';
import 'api_client.dart';

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
    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return null;
  }
}
