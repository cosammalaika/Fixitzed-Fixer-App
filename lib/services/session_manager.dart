import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:fixitzed_fixer_app/config.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';
import 'package:fixitzed_fixer_app/services/token_storage.dart';

enum SessionValidationResult {
  valid,
  missingToken,
  invalidToken,
  accountDisabled,
  wrongApp,
  indeterminate,
}

class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  final AppSync _sync = AppSync.instance;
  Future<SessionValidationResult>? _sessionValidationInFlight;

  Future<void> storeToken(String token) =>
      TokenStorage.instance.saveToken(token);

  Future<String?> readToken() async {
    return TokenStorage.instance.getToken();
  }

  Future<void> removeToken() async {
    await TokenStorage.instance.clearToken();
  }

  Future<void> finalizeLogout({String reason = 'manual'}) async {
    await removeToken();
    _broadcastLogout(reason: reason);
  }

  Future<void> ensureForcedLogout({String reason = 'sessionExpired'}) async {
    final current = await readToken();
    if (current == null) return;
    await removeToken();
    _broadcastLogout(reason: reason);
  }

  Future<SessionValidationResult> probeStoredSession() async {
    final existing = _sessionValidationInFlight;
    if (existing != null) return existing;

    final future = _probeStoredSession();
    _sessionValidationInFlight = future;
    return future.whenComplete(() {
      if (identical(_sessionValidationInFlight, future)) {
        _sessionValidationInFlight = null;
      }
    });
  }

  Future<void> confirmActiveSessionOrLogout(int statusCode) async {
    if (!_shouldInspect(statusCode)) return;

    final result = await probeStoredSession();
    if (result == SessionValidationResult.invalidToken ||
        result == SessionValidationResult.wrongApp) {
      await ensureForcedLogout(reason: 'sessionExpired');
      return;
    }
    if (result == SessionValidationResult.accountDisabled) {
      await ensureForcedLogout(reason: 'accountDisabled');
    }
  }

  void _broadcastLogout({required String reason}) {
    final basePayload = <String, dynamic>{'action': 'logout', 'reason': reason};

    final sourcePayload = <String, dynamic>{
      'source': 'auth',
      'action': 'logout',
      'reason': reason,
    };

    _sync.emit(AppSyncTopic.profile, payload: basePayload);
    _sync.emit(AppSyncTopic.dashboard, payload: sourcePayload);
    _sync.emit(AppSyncTopic.notifications, payload: sourcePayload);
    _sync.emit(AppSyncTopic.requests, payload: sourcePayload);
    _sync.emit(AppSyncTopic.wallet, payload: sourcePayload);
    _sync.emit(AppSyncTopic.auth, payload: basePayload);
  }

  Future<SessionValidationResult> _probeStoredSession() async {
    final token = await readToken();
    if (token == null || token.isEmpty) {
      return SessionValidationResult.missingToken;
    }

    try {
      final res = await http
          .get(
            Uri.parse('$apiBaseUrl/api/me'),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        return _isFixerSession(res.body)
            ? SessionValidationResult.valid
            : SessionValidationResult.wrongApp;
      }
      if (res.statusCode == 423) {
        return SessionValidationResult.accountDisabled;
      }
      if (_shouldInspect(res.statusCode)) {
        return SessionValidationResult.invalidToken;
      }
    } on TimeoutException {
      return SessionValidationResult.indeterminate;
    } on http.ClientException {
      return SessionValidationResult.indeterminate;
    } catch (_) {
      return SessionValidationResult.indeterminate;
    }

    return SessionValidationResult.indeterminate;
  }

  bool _isFixerSession(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) return false;
      final payload = decoded['user'] ?? decoded['data'];
      if (payload is! Map) return false;
      final user = Map<String, dynamic>.from(payload);
      final roles = <String>{};

      void addRole(dynamic value) {
        if (value is String && value.trim().isNotEmpty) {
          roles.add(value.trim().toLowerCase());
        }
      }

      addRole(user['primary_role']);
      addRole(user['primaryRole']);

      final directRoles = user['roles'];
      if (directRoles is List) {
        for (final entry in directRoles) {
          if (entry is Map) {
            addRole(entry['name']);
          } else {
            addRole(entry);
          }
        }
      }

      final roleNames = user['role_names'] ?? user['roleNames'];
      if (roleNames is List) {
        for (final entry in roleNames) {
          addRole(entry);
        }
      }

      return roles.contains('fixer');
    } catch (_) {}
    return false;
  }

  bool _shouldInspect(int statusCode) {
    return statusCode == 401 || statusCode == 419 || statusCode == 423;
  }
}
