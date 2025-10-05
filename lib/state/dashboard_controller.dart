import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/dashboard_snapshot.dart';
import '../data/repositories/dashboard_repository.dart';
import 'repository_providers.dart';

class FixerDashboardController
    extends StateNotifier<AsyncValue<FixerDashboardSnapshot>> {
  FixerDashboardController(this._repository)
      : super(const AsyncValue<FixerDashboardSnapshot>.loading()) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      refresh(silent: true);
    });
  }

  final FixerDashboardRepository _repository;
  Timer? _timer;

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = const AsyncValue<FixerDashboardSnapshot>.loading()
          .copyWithPrevious(state);
    }

    // Make sure fetchDashboard returns Future<FixerDashboardSnapshot>
    final result = await AsyncValue.guard<FixerDashboardSnapshot>(
      () => _repository.fetchDashboard(),
    );

    state = result;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final fixerDashboardControllerProvider = StateNotifierProvider<
    FixerDashboardController, AsyncValue<FixerDashboardSnapshot>>((ref) {
  final repository = ref.read(fixerDashboardRepositoryProvider);
  final controller = FixerDashboardController(repository);
  ref.onDispose(controller.dispose);
  return controller;
});
