import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/dashboard_repository.dart';
import 'service_providers.dart';

final fixerDashboardRepositoryProvider = Provider<FixerDashboardRepository>((
  ref,
) {
  return FixerDashboardRepository(
    ref.read(apiClientProvider),
    ref.read(notificationsServiceProvider),
    ref.read(fixerServiceProvider),
  );
});
