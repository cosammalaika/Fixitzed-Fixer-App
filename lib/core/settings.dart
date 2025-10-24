import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsKeys {
  static const pushNotifications = 'settings_push_notifications';
  static const emailNotifications = 'settings_email_notifications';
  static const darkMode = 'settings_dark_mode';
  static const language = 'settings_language';
}

class AppSettings {
  static Future<bool> getPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppSettingsKeys.pushNotifications) ?? true;
  }

  static Future<void> setPushEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppSettingsKeys.pushNotifications, value);
  }

  static Future<bool> getEmailEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppSettingsKeys.emailNotifications) ?? true;
  }

  static Future<void> setEmailEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppSettingsKeys.emailNotifications, value);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppSettingsKeys.language) ?? 'English';
  }

  static Future<void> setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppSettingsKeys.language, value);
  }
}
