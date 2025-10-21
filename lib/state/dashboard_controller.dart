import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_fixer_app/data/models/dashboard_snapshot.dart';
import 'package:fixitzed_fixer_app/data/repositories/dashboard_repository.dart';
import 'package:fixitzed_fixer_app/state/repository_providers.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';

class FixerDashboardController
    extends StateNotifier<AsyncValue<FixerDashboardSnapshot>> {
  FixerDashboardController(this._repository, this._ref)
      : super(const AsyncValue<FixerDashboardSnapshot>.loading()) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      refresh(silent: true);
    });
    _registerSync();
  }

  final FixerDashboardRepository _repository;
  final Ref _ref;
  Timer? _timer;
  bool _syncRegistered = false;

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

  void _registerSync() {
    if (_syncRegistered) return;
    _syncRegistered = true;

    void queueRefresh({bool silent = true}) {
      if (silent) {
        unawaited(refresh(silent: true));
      } else {
        unawaited(refresh());
      }
    }

    _ref.onAppSync(AppSyncTopic.dashboard, (_) {
      queueRefresh(silent: false);
    });
    _ref.onAppSync(AppSyncTopic.notifications, (_) {
      queueRefresh();
    });
    _ref.onAppSync(AppSyncTopic.requests, (_) {
      queueRefresh();
    });
    _ref.onAppSync(AppSyncTopic.wallet, (_) {
      queueRefresh();
    });
  }
}

final fixerDashboardControllerProvider = StateNotifierProvider<
    FixerDashboardController, AsyncValue<FixerDashboardSnapshot>>((ref) {
  final repository = ref.read(fixerDashboardRepositoryProvider);
  final controller = FixerDashboardController(repository, ref);
  ref.onDispose(controller.dispose);
  return controller;
});
