import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:fixitzed_fixer_app/config.dart';
import 'package:fixitzed_fixer_app/services/session_guard.dart';
import 'package:fixitzed_fixer_app/services/session_manager.dart';

class LoyaltyService {
  Future<Map<String, dynamic>?> summary() async {
    final token = await SessionManager.instance.readToken();
    if (token == null) return null;

    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/loyalty'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    await SessionGuard.evaluate(res);

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is Map && body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
    }

    return null;
  }
}
