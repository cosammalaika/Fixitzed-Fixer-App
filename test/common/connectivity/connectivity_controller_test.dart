import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fixitzed_fixer_app/common/connectivity/connectivity_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'polls while offline and clears status when connectivity returns',
    () async {
      final client = _FakeConnectivityClient(
        initialResults: const [ConnectivityResult.none],
      );
      final controller = ConnectivityController(
        client,
        offlinePollInterval: const Duration(milliseconds: 10),
      );

      addTearDown(controller.dispose);
      addTearDown(client.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isOnline, isFalse);
      expect(controller.state.result, ConnectivityResult.none);

      client.currentResults = const [ConnectivityResult.wifi];
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.state.isOnline, isTrue);
      expect(controller.state.result, ConnectivityResult.wifi);
    },
  );
}

class _FakeConnectivityClient implements ConnectivityClient {
  _FakeConnectivityClient({required List<ConnectivityResult> initialResults})
    : currentResults = initialResults;

  List<ConnectivityResult> currentResults;
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return currentResults;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _controller.stream;
  }

  void dispose() {
    _controller.close();
  }
}
