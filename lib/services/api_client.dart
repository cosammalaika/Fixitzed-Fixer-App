import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  static const _tokenKey = 'auth_token';

  String get baseUrl => apiBaseUrl;

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<http.Response> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = await _headers();
    return http.get(uri, headers: headers);
  }

  Future<http.Response> post(String path, {Object? body, bool jsonBody = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers(json: jsonBody);
    return http.post(uri, headers: headers, body: jsonBody ? jsonEncode(body) : body);
  }

  Future<http.Response> patch(String path, {Object? body, bool jsonBody = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers(json: jsonBody);
    return http.patch(uri, headers: headers, body: jsonBody ? jsonEncode(body) : body);
  }

  Future<http.Response> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers();
    return http.delete(uri, headers: headers);
  }

  Future<http.MultipartRequest> multipart(String path, {String method = 'POST'}) async {
    final uri = Uri.parse('$baseUrl$path');
    final req = http.MultipartRequest(method, uri);
    final token = await getToken();
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    return req;
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await getToken();
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (json) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }
}

