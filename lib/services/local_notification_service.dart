import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class LocalNotificationService {
  LocalNotificationService._internal();

  static final LocalNotificationService instance = LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
    'fixitzed_fixer_default',
    'Fixer Alerts',
    description: 'Job assignments, reminders and announcements for FixitZED Fixers.',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(settings);

    if (Platform.isAndroid) {
      final androidSpecific =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidSpecific != null) {
        await androidSpecific.createNotificationChannel(_defaultChannel);
        await androidSpecific.requestNotificationsPermission();
      }
    } else if (Platform.isIOS) {
      final iosSpecific =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosSpecific?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isMacOS) {
      final macSpecific =
          _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      await macSpecific?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  Future<void> showInstant({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (kIsWeb) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _defaultChannel.id,
        _defaultChannel.name,
        channelDescription: _defaultChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> notifyJobUpdate({
    required String bookingCode,
    required String status,
    DateTime? scheduledAt,
  }) async {
    final buffer = StringBuffer('Booking #$bookingCode is now $status');
    if (scheduledAt != null) {
      final formatted = DateFormat('EEE, MMM d • HH:mm').format(scheduledAt);
      buffer.write(' • $formatted');
    }
    await showInstant(
      title: 'Booking update',
      body: buffer.toString(),
      payload: 'booking_update',
    );
  }
}
