import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class ReportService {
  final _api = ApiClient.I;

  Future<bool> submit({
    required String type, // 'user' or 'fixer'
    required String subject,
    required String message,
    int? targetId,
  }) async {
    try {
      final res = await _api.post('/api/reports', body: {
        'type': type,
        'subject': subject,
        'message': message,
        if (targetId != null) 'target_id': targetId.toString(),
      });
      if (res.statusCode >= 200 && res.statusCode < 300) return true;
    } catch (_) {}
    return false;
  }
}

