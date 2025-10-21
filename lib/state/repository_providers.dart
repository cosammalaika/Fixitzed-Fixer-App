import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_fixer_app/data/repositories/dashboard_repository.dart';
import 'package:fixitzed_fixer_app/state/service_providers.dart';

final fixerDashboardRepositoryProvider = Provider<FixerDashboardRepository>((
  ref,
) {
  return FixerDashboardRepository(
    ref.read(apiClientProvider),
    ref.read(notificationsServiceProvider),
    ref.read(fixerServiceProvider),
  );
});
