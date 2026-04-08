import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_fixer_app/services/api_client.dart';
import 'package:fixitzed_fixer_app/services/catalog_service.dart';
import 'package:fixitzed_fixer_app/services/fixer_service.dart';
import 'package:fixitzed_fixer_app/services/notifications_service.dart';
import 'package:fixitzed_fixer_app/services/preload_service.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.I);
final fixerServiceProvider = Provider<FixerService>((ref) {
  final service = FixerService();
  ref.onAppSync(AppSyncTopic.auth, (event) {
    if (_isLogoutEvent(event)) {
      FixerService.clearCache();
    }
  });
  return service;
});
final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  final service = NotificationsService();
  ref.onAppSync(AppSyncTopic.auth, (event) {
    if (_isLogoutEvent(event)) {
      NotificationsService.clearCache();
    }
  });
  return service;
});
final catalogServiceProvider = Provider<CatalogService>(
  (ref) => CatalogService(client: ref.read(apiClientProvider)),
);
final preloadServiceProvider = Provider<PreloadService>(
  (ref) => PreloadService(ref),
);

bool _isLogoutEvent(AppSyncEvent event) {
  final payload = event.payload;
  if (payload is! Map) return false;
  return payload['action']?.toString().trim().toLowerCase() == 'logout';
}
