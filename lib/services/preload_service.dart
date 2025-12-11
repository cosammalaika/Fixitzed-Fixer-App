import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_fixer_app/state/bookings_controller.dart';
import 'package:fixitzed_fixer_app/state/dashboard_controller.dart';
import 'package:fixitzed_fixer_app/state/service_providers.dart';

/// Warms up high-traffic endpoints right after auth so the app feels instant.
class PreloadService {
  PreloadService(this._ref);

  final Ref _ref;

  Future<void> preloadAll({bool forceRefresh = false}) async {
    debugPrint('[Preload] Fixer preload start');
    try {
      final dashboard = _ref.read(fixerDashboardControllerProvider.notifier);
      final bookings = _ref.read(fixerBookingsProvider.notifier);
      final catalog = _ref.read(catalogServiceProvider);

      final futures = <Future<void>>[
        dashboard.refresh(silent: true),
        bookings.refresh(silent: true),
        catalog.fetchCatalog(forceRefresh: forceRefresh).then((_) {}),
      ];

      await Future.wait(futures.map((f) => f.catchError((_) {})));
    } catch (err, st) {
      debugPrint('[Preload] Fixer preload error: $err\n$st');
    } finally {
      debugPrint('[Preload] Fixer preload done');
    }
  }
}
