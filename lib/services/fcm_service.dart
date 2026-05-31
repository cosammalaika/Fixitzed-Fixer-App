import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:fixitzed_fixer_app/firebase_options.dart';
import 'package:fixitzed_fixer_app/services/local_notification_service.dart';
import 'package:fixitzed_fixer_app/services/api_client.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';
import 'package:http/http.dart' as http;

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  await _ensureFirebaseInitialized();
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();
  static const String appType = 'fixer';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _ensureFirebaseInitialized();
    } catch (e) {
      if (kDebugMode) print('Firebase init failed: $e');
      return;
    }

    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
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

    final token = await _resolveMessagingToken();
    if (token != null) {
      await _persistToken(token);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen(_persistToken);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _emitRealtimeSyncHints(message);
      LocalNotificationService.instance.handlePayload(
        payloadFromMessage(message),
      );
    });

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'];
      final body = notification?.body ?? message.data['body'];
      final payload = payloadFromMessage(message);
      _emitRealtimeSyncHints(message);
      final shouldShowLocal = Platform.isAndroid || notification == null;
      if (shouldShowLocal && (title != null || body != null)) {
        LocalNotificationService.instance.showInstant(
          title: title ?? 'New notification',
          body: body ?? '',
          payload: payload,
        );
      }
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _emitRealtimeSyncHints(initialMessage);
      LocalNotificationService.instance.handlePayload(
        payloadFromMessage(initialMessage),
      );
    }

    _initialized = true;
  }

  void _emitRealtimeSyncHints(RemoteMessage message) {
    final sync = AppSync.instance;
    final data = message.data;
    final rawTopics = (data['sync_topics'] ?? data['topics'] ?? '')
        .toString()
        .trim();

    final topics = <String>{};
    if (rawTopics.isNotEmpty) {
      for (final topic in rawTopics.split(',')) {
        final normalized = topic.trim().toLowerCase();
        switch (normalized) {
          case 'dashboard':
            topics.add(AppSyncTopic.dashboard);
            break;
          case 'requests':
          case 'bookings':
            topics.add(AppSyncTopic.requests);
            topics.add(AppSyncTopic.dashboard);
            break;
          case 'wallet':
          case 'coins':
          case 'subscription':
            topics.add(AppSyncTopic.wallet);
            topics.add(AppSyncTopic.dashboard);
            break;
          case 'notifications':
          case 'notification':
            topics.add(AppSyncTopic.notifications);
            topics.add(AppSyncTopic.dashboard);
            break;
          case 'profile':
            topics.add(AppSyncTopic.profile);
            break;
        }
      }
    }

    // Fallback: any foreground push should at least refresh dashboard+notifications.
    if (topics.isEmpty) {
      topics.addAll([AppSyncTopic.dashboard, AppSyncTopic.notifications]);
    }

    for (final topic in topics) {
      sync.emit(
        topic,
        payload: {'source': 'fcm', 'message_id': message.messageId},
      );
    }
  }

  Future<String?> _getMessagingToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      if (kDebugMode) log('FCM getToken failed: $e');
      return null;
    }
  }

  Future<String?> _resolveMessagingToken() async {
    if (Platform.isIOS) {
      for (var attempt = 0; attempt < 5; attempt++) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    return _getMessagingToken();
  }

  Future<void> _persistToken(String token) async {
    if (kDebugMode) print('FCM token: $token');
    try {
      // Use authenticated ApiClient; fallback to direct HTTP if needed.
      try {
        await ApiClient.I.post(
          '/api/device-token',
          body: {
            'token': token,
            'app': appType,
            'app_type': appType,
            'platform': Platform.isIOS ? 'ios' : 'android',
          },
        );
        return;
      } catch (_) {
        // Fallback direct call with stored token if available
      }

      final client = ApiClient.I;
      final prefsToken = await client.getToken();
      if (prefsToken == null || prefsToken.isEmpty) return;
      final uri = Uri.parse('${client.baseUrl}/api/device-token');
      final res = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $prefsToken',
        },
        body: jsonEncode({
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'app': appType,
          'app_type': appType,
        }),
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

  Future<void> registerTokenForCurrentUser() async {
    try {
      final token = await _resolveMessagingToken();
      if (token == null || token.isEmpty) return;
      await _persistToken(token);
    } catch (e) {
      if (kDebugMode) log('registerTokenForCurrentUser failed: $e');
    }
  }

  Future<void> unregisterTokenForCurrentUser() async {
    try {
      final client = ApiClient.I;
      final auth = await client.getToken();
      if (auth == null || auth.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final uri = Uri.parse('${client.baseUrl}/api/device-token');
      await http.delete(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $auth',
        },
        body: jsonEncode({'token': token}),
      );
    } catch (e) {
      if (kDebugMode) log('unregisterTokenForCurrentUser failed: $e');
    }
  }

  String? payloadFromMessage(RemoteMessage message) {
    final data = message.data;
    final payload = data['payload']?.toString().trim();
    if (payload != null && payload.isNotEmpty) {
      return payload;
    }

    final requestId = data['service_request_id']?.toString().trim();
    if (requestId != null && requestId.isNotEmpty) {
      return 'booking_detail:$requestId';
    }

    final notificationId = data['notification_id']?.toString().trim();
    if (notificationId != null && notificationId.isNotEmpty) {
      return 'remote_notification:$notificationId';
    }

    return null;
  }
}
