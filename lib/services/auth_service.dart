import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fixitzed_fixer_app/models/fixer.dart';
import 'package:fixitzed_fixer_app/services/api_client.dart';
import 'package:fixitzed_fixer_app/services/session_guard.dart';
import 'package:fixitzed_fixer_app/services/session_manager.dart';
import 'package:fixitzed_fixer_app/services/fcm_service.dart';

class LoginResult {
  final bool success;
  final bool inactive;

  const LoginResult({required this.success, this.inactive = false});
}

class PasswordResetResult {
  final bool success;
  final String message;

  const PasswordResetResult({required this.success, required this.message});
}

class AuthService {
  final _api = ApiClient.I;

  // Positional-args login to match UI usage (email/phone/username + password)
  Future<LoginResult> login(String identifier, String password) async {
    final res = await _api.post(
      '/api/login',
      body: {'identifier': identifier, 'password': password},
    );
    if (res.statusCode != 200) {
      return const LoginResult(success: false);
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = (data['token'] ?? data['access_token']) as String?;
    if (token == null) {
      return const LoginResult(success: false);
    }

    await _api.setToken(token);
    await FcmService.instance.registerTokenForCurrentUser();

    bool inactive = _extractInactiveFlag(data['user']);

    if (!inactive) {
      final meRes = await _api.get('/api/me');
      if (meRes.statusCode == 200) {
        final decoded = jsonDecode(meRes.body);
        Map<String, dynamic>? payload;
        if (decoded is Map<String, dynamic>) {
          if (decoded['user'] is Map<String, dynamic>) {
            payload = Map<String, dynamic>.from(decoded['user'] as Map);
          } else if (decoded['data'] is Map<String, dynamic>) {
            payload = Map<String, dynamic>.from(decoded['data'] as Map);
          }
        }
        inactive = _extractInactiveFlag(payload);
      }
    }

    if (inactive) {
      await _api.setToken(null);
      return const LoginResult(success: false, inactive: true);
    }

    return const LoginResult(success: true);
  }

  bool _extractInactiveFlag(dynamic source) {
    if (source is Map<String, dynamic>) {
      final statusRaw =
          source['status'] ??
          source['account_status'] ??
          source['accountStatus'];
      if (statusRaw is String && statusRaw.trim().isNotEmpty) {
        return statusRaw.trim().toLowerCase() != 'active';
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
      await FcmService.instance.unregisterTokenForCurrentUser();
      await _api.setToken(null);
      await SessionManager.instance.finalizeLogout(reason: 'manual');
    }
  }

  Future<bool> updateProfilePhoto(String path) async {
    try {
      final trimmed = path.trim();
      if (trimmed.isEmpty) return false;
      final request = await _api.multipart('/api/me', method: 'POST');
      request.fields['_method'] = 'PATCH';
      request.files.add(
        await http.MultipartFile.fromPath('profile_photo', trimmed),
      );
      final streamed = await request.send();
      await SessionGuard.evaluate(streamed);
      return streamed.statusCode >= 200 && streamed.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<PasswordResetResult> requestPasswordReset(String identifier) async {
    try {
      final res = await _api.post(
        '/api/password/forgot',
        body: {'identifier': identifier},
      );
      return _mapResetResponse(
        res,
        fallbackSuccess:
            'If we find a matching account, a reset code will be emailed shortly.',
      );
    } catch (_) {
      return const PasswordResetResult(
        success: false,
        message:
            'Unable to submit the reset request. Check your connection and try again.',
      );
    }
  }

  Future<PasswordResetResult> confirmPasswordReset({
    required String identifier,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final res = await _api.post(
        '/api/password/reset',
        body: {
          'identifier': identifier,
          'token': token,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
      return _mapResetResponse(
        res,
        fallbackSuccess:
            'Password updated successfully. You can now sign in with your new password.',
      );
    } catch (_) {
      return const PasswordResetResult(
        success: false,
        message:
            'Unable to update the password right now. Please try again in a moment.',
      );
    }
  }

  PasswordResetResult _mapResetResponse(
    http.Response res, {
    required String fallbackSuccess,
  }) {
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {}

    final isSuccess = res.statusCode >= 200 && res.statusCode < 300;
    String message = fallbackSuccess;

    if (body != null) {
      final msgValue = body['message'] ?? body['status'];
      if (msgValue is String && msgValue.trim().isNotEmpty) {
        message = msgValue.trim();
      } else if (msgValue is List && msgValue.isNotEmpty) {
        message = msgValue.join('\n');
      }
    }

    if (!isSuccess) {
      final errors = <String>[];
      if (body != null) {
        final err = body['errors'];
        if (err is Map) {
          err.forEach((_, value) {
            if (value is List) {
              errors.addAll(value.map((e) => e.toString()));
            } else if (value != null) {
              errors.add(value.toString());
            }
          });
        } else if (err is List) {
          errors.addAll(err.map((e) => e.toString()));
        }
      }

      if (errors.isNotEmpty) {
        message = errors.join('\n');
      } else if (message == fallbackSuccess) {
        message = res.statusCode >= 500
            ? 'Something went wrong on our side. Please try again shortly.'
            : 'Unable to process the request. Check the details and try again.';
      }
    }

    return PasswordResetResult(success: isSuccess, message: message);
  }
}
