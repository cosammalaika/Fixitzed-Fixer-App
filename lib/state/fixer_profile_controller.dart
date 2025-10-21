import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_fixer_app/models/fixer.dart';
import 'package:fixitzed_fixer_app/services/fixer_service.dart';
import 'package:fixitzed_fixer_app/state/service_providers.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';

class FixerProfileController extends StateNotifier<AsyncValue<Fixer?>> {
  FixerProfileController(this._service, this._ref)
    : super(const AsyncValue<Fixer?>.loading()) {
    refresh();
    _registerSync();
  }

  final FixerService _service;
  final Ref _ref;
  bool _refreshing = false;

  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent) {
      state = const AsyncValue<Fixer?>.loading().copyWithPrevious(state);
    }
    final result = await AsyncValue.guard(_service.profile);
    state = result;
    _refreshing = false;
  }

  Future<bool> updateServices(List<int> serviceIds) async {
    state = const AsyncValue<Fixer?>.loading().copyWithPrevious(state);
    final updated = await AsyncValue.guard(
      () => _service.updateMe(serviceIds: serviceIds),
    );
    final value = updated.value;
    if (value != null) {
      state = AsyncValue.data(value);
      return true;
    }
    state = updated;
    return false;
  }

  void _registerSync() {
    _ref.onAppSync(AppSyncTopic.profile, (_) {
      unawaited(refresh());
    });
  }
}

final AutoDisposeStateNotifierProvider<
  FixerProfileController,
  AsyncValue<Fixer?>
>
fixerProfileProvider =
    StateNotifierProvider.autoDispose<
      FixerProfileController,
      AsyncValue<Fixer?>
    >((ref) {
      final service = ref.read(fixerServiceProvider);
      final controller = FixerProfileController(service, ref);
      ref.onDispose(controller.dispose);
      return controller;
    });
