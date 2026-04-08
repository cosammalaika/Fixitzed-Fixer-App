import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_fixer_app/data/repositories/dashboard_repository.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';
import 'package:fixitzed_fixer_app/state/service_providers.dart';

final fixerDashboardRepositoryProvider = Provider<FixerDashboardRepository>((
  ref,
) {
  final repository = FixerDashboardRepository(
    ref.read(apiClientProvider),
    ref.read(notificationsServiceProvider),
    ref.read(fixerServiceProvider),
  );
  ref.onAppSync(AppSyncTopic.auth, (event) async {
    final payload = event.payload;
    if (payload is Map &&
        payload['action']?.toString().trim().toLowerCase() == 'logout') {
      await repository.clearCache();
    }
  });
  return repository;
});
