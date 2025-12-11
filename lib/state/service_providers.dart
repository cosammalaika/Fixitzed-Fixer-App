import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_fixer_app/services/api_client.dart';
import 'package:fixitzed_fixer_app/services/catalog_service.dart';
import 'package:fixitzed_fixer_app/services/fixer_service.dart';
import 'package:fixitzed_fixer_app/services/notifications_service.dart';
import 'package:fixitzed_fixer_app/services/preload_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.I);
final fixerServiceProvider = Provider<FixerService>((ref) => FixerService());
final notificationsServiceProvider = Provider<NotificationsService>(
  (ref) => NotificationsService(),
);
final catalogServiceProvider = Provider<CatalogService>(
  (ref) => CatalogService(client: ref.read(apiClientProvider)),
);
final preloadServiceProvider = Provider<PreloadService>(
  (ref) => PreloadService(ref),
);
