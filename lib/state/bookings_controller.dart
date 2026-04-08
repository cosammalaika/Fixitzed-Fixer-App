import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncValue, Ref;
import 'package:flutter_riverpod/legacy.dart';

import 'package:fixitzed_fixer_app/models/service_request.dart';
import 'package:fixitzed_fixer_app/services/fixer_service.dart';
import 'package:fixitzed_fixer_app/state/service_providers.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';

class FixerBookingsState {
  const FixerBookingsState({
    required this.pending,
    required this.accepted,
    required this.completed,
    required this.declined,
    required this.awaitingPayment,
  });

  final List<ServiceRequest> pending;
  final List<ServiceRequest> accepted;
  final List<ServiceRequest> completed;
  final List<ServiceRequest> declined;
  final List<ServiceRequest> awaitingPayment;

  List<ServiceRequest> get active {
    final seen = <int>{};
    final results = <ServiceRequest>[];
    for (final request in [...pending, ...accepted, ...awaitingPayment]) {
      if (seen.add(request.id)) {
        results.add(request);
      }
    }
    return results;
  }
}

class FixerBookingsController
    extends StateNotifier<AsyncValue<FixerBookingsState>> {
  FixerBookingsController(this._service, this._ref)
    : super(const AsyncValue<FixerBookingsState>.loading()) {
    final cached = _freshCache();
    if (cached != null) {
      state = AsyncValue.data(cached);
    }
    unawaited(refresh(silent: cached != null, forceRefresh: cached == null));
    _registerSync();
  }

  final FixerService _service;
  final Ref _ref;
  Future<void>? _refreshInFlight;
  static FixerBookingsState? _cache;
  static DateTime? _cacheFetchedAt;
  static const Duration _ttl = Duration(minutes: 5);
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
    final previous = state.value ?? _freshCache();
    if (!silent && previous == null) {
      state = const AsyncValue<FixerBookingsState>.loading();
    }

    try {
      final responses = await Future.wait<List<ServiceRequest>>([
        _service.requests(status: 'pending', forceRefresh: forceRefresh),
        _service.requests(status: 'accepted', forceRefresh: forceRefresh),
        _service.requests(status: 'completed', forceRefresh: forceRefresh),
        _service.requests(status: 'declined', forceRefresh: forceRefresh),
        _service.requests(
          status: 'awaiting_payment',
          forceRefresh: forceRefresh,
        ),
      ]);
      final pending = responses[0];
      final accepted = responses[1];
      final completed = responses[2];
      final declined = responses[3];
      final awaitingPayment = responses[4];

      final next = FixerBookingsState(
        pending: pending,
        accepted: _mergeDistinct(accepted, awaitingPayment),
        completed: completed,
        declined: declined,
        awaitingPayment: awaitingPayment,
      );
      state = AsyncValue.data(next);
      _cache = next;
      _cacheFetchedAt = DateTime.now();
      _lastRefreshAt = _cacheFetchedAt;
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncValue.data(previous);
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }

  static FixerBookingsState? _freshCache() {
    if (_cache == null || _cacheFetchedAt == null) return null;
    if (DateTime.now().difference(_cacheFetchedAt!) > _ttl) return null;
    return _cache;
  }

  void _registerSync() {
    _ref.onAppSync(AppSyncTopic.requests, (_) {
      unawaited(refresh(silent: true, forceRefresh: true));
    });
    _ref.onAppSync(AppSyncTopic.wallet, (_) {
      unawaited(refresh(silent: true, forceRefresh: true));
    });
    _ref.onAppSync(AppSyncTopic.auth, (event) {
      final payload = event.payload;
      final action = payload is Map
          ? payload['action']?.toString().trim().toLowerCase()
          : null;
      if (action != 'logout') return;
      _cache = null;
      _cacheFetchedAt = null;
      state = const AsyncValue<FixerBookingsState>.loading();
    });
  }
}

List<ServiceRequest> _mergeDistinct(
  List<ServiceRequest> primary,
  List<ServiceRequest> secondary,
) {
  if (secondary.isEmpty) return primary;
  final existing = <int>{for (final item in primary) item.id};
  final merged = [...primary];
  for (final item in secondary) {
    if (existing.add(item.id)) {
      merged.add(item);
    }
  }
  return merged;
}

final fixerBookingsProvider =
    StateNotifierProvider<
      FixerBookingsController,
      AsyncValue<FixerBookingsState>
    >((ref) {
      final service = ref.read(fixerServiceProvider);
      return FixerBookingsController(service, ref);
    });
