import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSyncEvent {
  AppSyncEvent(this.topic, {this.payload}) : timestamp = DateTime.now().toUtc();

  final String topic;
  final Object? payload;
  final DateTime timestamp;
}

class AppSync {
  AppSync._internal();

  static final AppSync instance = AppSync._internal();

  factory AppSync() => instance;

  final _controller = StreamController<AppSyncEvent>.broadcast();

  void emit(String topic, {Object? payload}) {
    if (_controller.isClosed) return;
    _controller.add(AppSyncEvent(topic, payload: payload));
  }

  Stream<AppSyncEvent> on(String topic) =>
      _controller.stream.where((event) => event.topic == topic);

  void dispose() {}
}

final appSyncProvider = Provider<AppSync>((ref) {
  return AppSync.instance;
});

class AppSyncTopic {
  AppSyncTopic._();

  static const dashboard = 'dashboard';
  static const notifications = 'notifications';
  static const requests = 'requests';
  static const wallet = 'wallet';
  static const profile = 'profile';
  static const auth = 'auth';
}

extension AppSyncRef on Ref {
  void onAppSync(
    String topic,
    FutureOr<void> Function(AppSyncEvent event) handler,
  ) {
    final sync = read(appSyncProvider);
    final subscription = sync.on(topic).listen((event) {
      final result = handler(event);
      if (result is Future<void>) {
        unawaited(result);
      }
    });
    onDispose(subscription.cancel);
  }

  void triggerAppSync(String topic, {Object? payload}) {
    read(appSyncProvider).emit(topic, payload: payload);
  }
}
