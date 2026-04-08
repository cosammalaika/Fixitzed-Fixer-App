import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncValue, Ref;
import 'package:flutter_riverpod/legacy.dart';

import 'package:fixitzed_fixer_app/models/fixer.dart';
import 'package:fixitzed_fixer_app/services/fixer_service.dart';
import 'package:fixitzed_fixer_app/state/service_providers.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';

class FixerProfileController extends StateNotifier<AsyncValue<Fixer?>> {
  FixerProfileController(this._service, this._ref)
    : super(const AsyncValue<Fixer?>.loading()) {
    unawaited(refresh(forceRefresh: true));
    _registerSync();
  }

  final FixerService _service;
  final Ref _ref;
  Future<void>? _refreshInFlight;
  DateTime? _lastRefreshAt;
  static const Duration _minRefreshGap = Duration(seconds: 8);

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

    final future = _runRefresh(silent: silent);
    _refreshInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<void> _runRefresh({required bool silent}) async {
    final previous = state.value;
    if (!silent && previous == null) {
      state = const AsyncValue<Fixer?>.loading();
    }
    try {
      final profile = await _service.profile();
      if (profile == null && previous != null) {
        state = AsyncValue.data(previous);
        return;
      }
      state = AsyncValue.data(profile);
      _lastRefreshAt = DateTime.now();
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncValue.data(previous);
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<bool> updateServices(List<int> serviceIds) async {
    final previous = state.value;
    final updated = await AsyncValue.guard(
      () => _service.updateMe(serviceIds: serviceIds),
    );
    final value = updated.value;
    if (value != null) {
      state = AsyncValue.data(value);
      _lastRefreshAt = DateTime.now();
      return true;
    }
    if (previous != null) {
      state = AsyncValue.data(previous);
      return false;
    }
    state = updated;
    return false;
  }

  void _registerSync() {
    _ref.onAppSync(AppSyncTopic.profile, (_) {
      unawaited(refresh(silent: true, forceRefresh: true));
    });
    _ref.onAppSync(AppSyncTopic.auth, (event) {
      final payload = event.payload;
      final action = payload is Map
          ? payload['action']?.toString().trim().toLowerCase()
          : null;
      if (action != 'logout') return;
      state = const AsyncValue<Fixer?>.loading();
    });
  }
}

final fixerProfileProvider =
    StateNotifierProvider<FixerProfileController, AsyncValue<Fixer?>>((ref) {
      final service = ref.read(fixerServiceProvider);
      return FixerProfileController(service, ref);
    });
