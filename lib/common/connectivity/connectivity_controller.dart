import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';

final connectivityProvider =
    StateNotifierProvider<ConnectivityController, ConnectivityStatus>((ref) {
      return ConnectivityController(ConnectivityPlusClient(Connectivity()));
    });

class ConnectivityStatus {
  const ConnectivityStatus({required this.isOnline, required this.result});

  final bool isOnline;
  final ConnectivityResult result;

  ConnectivityStatus copyWith({bool? isOnline, ConnectivityResult? result}) {
    return ConnectivityStatus(
      isOnline: isOnline ?? this.isOnline,
      result: result ?? this.result,
    );
  }
}

class ConnectivityController extends StateNotifier<ConnectivityStatus> {
  ConnectivityController(
    this._connectivity, {
    Duration offlinePollInterval = const Duration(seconds: 2),
  }) : _offlinePollInterval = offlinePollInterval,
       super(
         const ConnectivityStatus(
           isOnline: true,
           result: ConnectivityResult.other,
         ),
       ) {
    _appLifecycleListener = AppLifecycleListener(onResume: refreshStatus);
    _init();
  }

  final ConnectivityClient _connectivity;
  final Duration _offlinePollInterval;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlinePollTimer;
  late final AppLifecycleListener _appLifecycleListener;
  bool _disposed = false;
  bool _refreshInFlight = false;

  Future<void> _init() async {
    _subscription = _connectivity.onConnectivityChanged.listen(_setStatus);
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    if (_refreshInFlight || _disposed) return;

    _refreshInFlight = true;
    try {
      final current = await _connectivity.checkConnectivity();
      if (_disposed) return;
      _setStatus(current);
    } finally {
      _refreshInFlight = false;
    }
  }

  void _setStatus(List<ConnectivityResult> results) {
    if (_disposed) return;

    final normalized = results.isEmpty
        ? const [ConnectivityResult.none]
        : results;
    final onlineResults = normalized.where(
      (result) => result != ConnectivityResult.none,
    );
    final online = onlineResults.isNotEmpty;
    final primary = online ? onlineResults.first : ConnectivityResult.none;

    _syncOfflinePolling(online);

    if (state.isOnline == online && state.result == primary) return;

    state = ConnectivityStatus(isOnline: online, result: primary);
  }

  void _syncOfflinePolling(bool isOnline) {
    if (isOnline) {
      _offlinePollTimer?.cancel();
      _offlinePollTimer = null;
      return;
    }

    _offlinePollTimer ??= Timer.periodic(
      _offlinePollInterval,
      (_) => refreshStatus(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _offlinePollTimer?.cancel();
    _subscription?.cancel();
    _appLifecycleListener.dispose();
    super.dispose();
  }
}

abstract class ConnectivityClient {
  Future<List<ConnectivityResult>> checkConnectivity();

  Stream<List<ConnectivityResult>> get onConnectivityChanged;
}

class ConnectivityPlusClient implements ConnectivityClient {
  ConnectivityPlusClient(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    return _connectivity.checkConnectivity();
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }
}
