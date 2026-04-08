import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncValue, Ref;
import 'package:flutter_riverpod/legacy.dart';

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
  Future<void>? _refreshInFlight;
  DateTime? _lastRefreshAt;
  static const Duration _minRefreshGap = Duration(seconds: 8);

  Future<void> load({bool forceRefresh = false}) async {
    final cached = await _repository.readCachedDashboard();
    if (cached != null) {
      state = AsyncValue.data(cached);
    }
    await refresh(
      silent: cached != null,
      forceRefresh: forceRefresh || cached == null,
    );
  }

  Future<void> refresh({bool silent = false, bool forceRefresh = false}) async {
    final existing = _refreshInFlight;
    if (existing != null) {
      await existing;
      return;
    }

    if (!forceRefresh &&
        _lastRefreshAt != null &&
        DateTime.now().difference(_lastRefreshAt!) < _minRefreshGap) {
      return;
    }

    final future = _runRefresh(silent: silent, forceRefresh: forceRefresh);
    _refreshInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<void> _runRefresh({
    required bool silent,
    required bool forceRefresh,
  }) async {
    final previous = state.value ?? await _repository.readCachedDashboard();
    if (previous == null && !silent) {
      state = const AsyncValue<FixerDashboardSnapshot>.loading();
    }

    try {
      final next = await _repository.fetchDashboard(forceRefresh: forceRefresh);
      _lastRefreshAt = DateTime.now();
      state = AsyncValue.data(next);
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncValue.data(previous.copyWith(fromCache: true));
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
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
      unawaited(refresh(silent: silent, forceRefresh: true));
    }

    _ref.onAppSync(AppSyncTopic.dashboard, (event) {
      final payload = event.payload;
      final source = payload is Map
          ? payload['source']?.toString().trim().toLowerCase()
          : null;
      if (source == 'tab_reselected') {
        unawaited(refresh(silent: true, forceRefresh: false));
        return;
      }
      if (source == 'auth' || source == 'login_success') {
        queueRefresh(silent: true);
        return;
      }
      queueRefresh(silent: true);
    });
    _ref.onAppSync(AppSyncTopic.notifications, (_) {
      queueRefresh(silent: true);
    });
    _ref.onAppSync(AppSyncTopic.requests, (_) {
      queueRefresh(silent: true);
    });
    _ref.onAppSync(AppSyncTopic.wallet, (_) {
      queueRefresh(silent: true);
    });
    _ref.onAppSync(AppSyncTopic.auth, (event) async {
      final payload = event.payload;
      final action = payload is Map
          ? payload['action']?.toString().trim().toLowerCase()
          : null;
      if (action != 'logout') return;
      await _repository.clearCache();
      state = const AsyncValue<FixerDashboardSnapshot>.loading();
    });
  }
}

final fixerDashboardControllerProvider =
    StateNotifierProvider<
      FixerDashboardController,
      AsyncValue<FixerDashboardSnapshot>
    >((ref) {
      final repository = ref.read(fixerDashboardRepositoryProvider);
      return FixerDashboardController(repository, ref);
    });
