import 'dart:convert';
import '../models/subscription.dart';
import 'api_client.dart';

class SubscriptionService {
  final _api = ApiClient.I;

  Future<List<Plan>> plans() async {
    final res = await _api.get('/api/plans');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

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

  Future<Map<String, dynamic>?> createSubscription({required int planId, required String method}) async {
    final res = await _api.post('/api/subscriptions', body: {
      'plan_id': planId,
      'method': method, // airtel|mtn|card
    });
    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return null;
  }
}

