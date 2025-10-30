import 'package:http/http.dart' as http;

import 'package:fixitzed_fixer_app/services/session_manager.dart';

class SessionGuard {
  SessionGuard._();

  static Future<void> evaluate(http.BaseResponse response) async {
    if (_shouldInvalidate(response.statusCode)) {
      await SessionManager.instance.ensureForcedLogout();
    }
  }

  static bool _shouldInvalidate(int statusCode) {
    return statusCode == 401 || statusCode == 419;
  }
}
