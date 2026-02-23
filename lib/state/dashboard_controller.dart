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
    unawaited(load());
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(refresh(silent: true, forceRefresh: true));
    });
    _registerSync();
  }

  final FixerDashboardRepository _repository;
  final Ref _ref;
  Timer? _timer;
  bool _syncRegistered = false;
  bool _refreshing = false;

  Future<void> load({bool forceRefresh = false}) async {
    final cached = await _repository.readCachedDashboard();
    if (cached != null) {
      state = AsyncValue.data(cached);
    }
    await refresh(
      silent: cached != null,
      forceRefresh: true,
    );
  }

  Future<void> refresh({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    if (_refreshing) return;
    _refreshing = true;

    if (state.hasValue) {
      state = const AsyncValue<FixerDashboardSnapshot>.loading()
          .copyWithPrevious(state);
    } else if (!silent) {
      state = const AsyncValue<FixerDashboardSnapshot>.loading();
    }

    final result = await AsyncValue.guard<FixerDashboardSnapshot>(
      () => _repository.fetchDashboard(forceRefresh: forceRefresh),
    );

    state = result;
    _refreshing = false;
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
        unawaited(refresh(silent: true, forceRefresh: true));
      } else {
        unawaited(refresh(forceRefresh: true));
      }
    }

    _ref.onAppSync(AppSyncTopic.dashboard, (_) {
      queueRefresh(silent: true);
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
