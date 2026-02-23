import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:fixitzed_fixer_app/config.dart';
import 'package:fixitzed_fixer_app/services/session_guard.dart';
import 'package:fixitzed_fixer_app/services/session_manager.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  String get baseUrl => apiBaseUrl;

  Future<String?> getToken() async {
    return SessionManager.instance.readToken();
  }

  Future<void> setToken(String? token) async {
    if (token == null || token.isEmpty) {
      await SessionManager.instance.removeToken();
    } else {
      await SessionManager.instance.storeToken(token);
    }
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final requestHeaders = await _headers();
    if (headers != null && headers.isNotEmpty) {
      requestHeaders.addAll(headers);
    }
    if (kDebugMode) {
      debugPrint(
        '[ApiClient][GET] url=$uri auth=${requestHeaders.containsKey('Authorization')} headers=${requestHeaders.keys.toList()}',
      );
    }
    final response = await http.get(uri, headers: requestHeaders);
    if (kDebugMode) {
      final body = response.body;
      final snippet = body.length > 300 ? '${body.substring(0, 300)}…' : body;
      debugPrint(
        '[ApiClient][GET] status=${response.statusCode} url=$uri body=$snippet',
      );
    }
    await SessionGuard.evaluate(response);
    return response;
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    bool jsonBody = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers(json: jsonBody);
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonBody ? jsonEncode(body) : body,
    );
    await SessionGuard.evaluate(response);
    return response;
  }

  Future<http.Response> patch(
    String path, {
    Object? body,
    bool jsonBody = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers(json: jsonBody);
    final response = await http.patch(
      uri,
      headers: headers,
      body: jsonBody ? jsonEncode(body) : body,
    );
    await SessionGuard.evaluate(response);
    return response;
  }

  Future<http.Response> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers();
    final response = await http.delete(uri, headers: headers);
    await SessionGuard.evaluate(response);
    return response;
  }

  Future<http.MultipartRequest> multipart(
    String path, {
    String method = 'POST',
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final req = http.MultipartRequest(method, uri);
    final token = await getToken();
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    return req;
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await getToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }
}
