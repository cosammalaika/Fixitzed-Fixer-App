import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fixer.dart';
import 'api_client.dart';

class AuthService {
  final _api = ApiClient.I;

  // Positional-args login to match UI usage (email/phone/username + password)
  Future<bool> login(String identifier, String password) async {
    final res = await _api.post(
      '/api/login',
      body: {
        // Backend can accept email/phone/username under a common key like 'email' or 'identifier'.
        // If your API expects a different key, change 'email' accordingly.
        'identifier': identifier,
        'password': password,
      },
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = (data['token'] ?? data['access_token']) as String?;
      if (token != null) {
        await _api.setToken(token);
        return true;
      }
    }
    return false;
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final res = await _api.post(
      '/api/register',
      body: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone,
      },
    );
    return res.statusCode == 201 || res.statusCode == 200;
  }

  Future<Fixer?> me() async {
    final res = await _api.get('/api/fixer/me');
    if (res.statusCode == 200) {
      final root = jsonDecode(res.body);
      Map<String, dynamic>? payload;
      if (root is Map<String, dynamic>) {
        if (root['data'] is Map<String, dynamic>) {
          payload = Map<String, dynamic>.from(root['data'] as Map);
        } else if (root['fixer'] is Map<String, dynamic>) {
          payload = Map<String, dynamic>.from(root['fixer'] as Map);
        } else if (root.containsKey('id') && root.containsKey('user')) {
          payload = root;
        }
      }
      if (payload != null) {
        return Fixer.fromJson(payload);
      }
    }
    return null;
  }

  Future<void> logout() async {
    try {
      await _api.post('/api/logout', body: {});
    } finally {
      await _api.setToken(null);
    }
  }
}
