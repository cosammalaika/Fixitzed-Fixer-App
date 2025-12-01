import 'dart:developer';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:fixitzed_fixer_app/services/local_notification_service.dart';
import 'package:fixitzed_fixer_app/services/api_client.dart';
import 'package:http/http.dart' as http;

Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await LocalNotificationService.instance.init();
  final notification = message.notification;
  final title = notification?.title ?? message.data['title'];
  final body = notification?.body ?? message.data['body'];
  if (title != null || body != null) {
    await LocalNotificationService.instance.showInstant(
      title: title ?? 'New notification',
      body: body ?? '',
      payload: message.data['payload'],
    );
  }
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      if (kDebugMode) print('Firebase init failed: $e');
      return;
    }

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      log('FCM permission: ${settings.authorizationStatus}');
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _persistToken(token);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen(_persistToken);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'];
      final body = notification?.body ?? message.data['body'];
      if (title != null || body != null) {
        LocalNotificationService.instance.showInstant(
          title: title ?? 'New notification',
          body: body ?? '',
          payload: message.data['payload'],
        );
      }
    });

    _initialized = true;
  }

  Future<void> _persistToken(String token) async {
    if (kDebugMode) print('FCM token: $token');
    try {
      // Use authenticated ApiClient; fallback to direct HTTP if needed.
      try {
        await ApiClient.I.post('/api/device-tokens', body: {'token': token});
        return;
      } catch (_) {
        // Fallback direct call with stored token if available
      }

      final client = ApiClient.I;
      final prefsToken = await client.getToken();
      if (prefsToken == null || prefsToken.isEmpty) return;
      final uri = Uri.parse('${client.baseUrl}/api/device-tokens');
      final res = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $prefsToken',
        },
        body: '{"token":"$token","platform":"${Platform.isIOS ? 'ios' : 'android'}"}',
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (kDebugMode) print('FCM token persisted (${res.statusCode})');
      } else {
        if (kDebugMode) {
          print('Failed to persist token (${res.statusCode}): ${res.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Failed to persist token: $e');
    }
  }
}
