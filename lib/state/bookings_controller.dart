import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_fixer_app/models/service_request.dart';
import 'package:fixitzed_fixer_app/services/fixer_service.dart';
import 'package:fixitzed_fixer_app/state/service_providers.dart';

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
  FixerBookingsController(this._service)
    : super(const AsyncValue<FixerBookingsState>.loading()) {
    refresh();
  }

  final FixerService _service;
  bool _refreshing = false;

  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent) {
      state = const AsyncValue<FixerBookingsState>.loading().copyWithPrevious(
        state,
      );
    }
    final result = await AsyncValue.guard<FixerBookingsState>(() async {
      final responses = await Future.wait<List<ServiceRequest>>([
        _service.requests(status: 'pending'),
        _service.requests(status: 'accepted'),
        _service.requests(status: 'completed'),
        _service.requests(status: 'declined'),
        _service.requests(status: 'awaiting_payment'),
      ]);
      final pending = responses[0];
      final accepted = responses[1];
      final completed = responses[2];
      final declined = responses[3];
      final awaitingPayment = responses[4];

      return FixerBookingsState(
        pending: pending,
        accepted: _mergeDistinct(accepted, awaitingPayment),
        completed: completed,
        declined: declined,
        awaitingPayment: awaitingPayment,
      );
    });
    state = result;
    _refreshing = false;
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
      final controller = FixerBookingsController(service);
      ref.onDispose(controller.dispose);
      return controller;
    });
