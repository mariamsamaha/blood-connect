import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/services/sync_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class _MockConnectivity extends Fake implements Connectivity {
  final StreamController<List<ConnectivityResult>> _controller = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> _checkResult = [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _checkResult;
}

void main() {
  group('SyncManager', () {
    test('starts with given initial status', () {
      final mock = _MockConnectivity();
      final manager = SyncManager(
        connectivity: mock,
        initialStatus: ConnectivityStatus.online,
      );
      expect(manager.isOnline, isTrue);
      expect(manager.currentStatus, ConnectivityStatus.online);
    });

    test('starts with offline when specified', () {
      final mock = _MockConnectivity();
      final manager = SyncManager(
        connectivity: mock,
        initialStatus: ConnectivityStatus.offline,
      );
      expect(manager.isOnline, isFalse);
    });

    test('checkConnectivity updates status', () async {
      final mock = _MockConnectivity();
      mock._checkResult = [ConnectivityResult.none];
      final manager = SyncManager(
        connectivity: mock,
        initialStatus: ConnectivityStatus.online,
      );
      await manager.checkConnectivity();
      expect(manager.isOnline, isFalse);
    });

    test('calls onOnline callback when coming back online', () async {
      final mock = _MockConnectivity();
      bool onlineCalled = false;
      final manager = SyncManager(
        connectivity: mock,
        initialStatus: ConnectivityStatus.offline,
        onOnline: () { onlineCalled = true; },
      );
      mock._controller.add([ConnectivityResult.wifi]);
      await Future.delayed(Duration(milliseconds: 600));
      expect(onlineCalled, isTrue);
      expect(manager.isOnline, isTrue);
    });

    test('calls onOffline callback when going offline', () async {
      final mock = _MockConnectivity();
      bool offlineCalled = false;
      final manager = SyncManager(
        connectivity: mock,
        initialStatus: ConnectivityStatus.online,
        onOffline: () { offlineCalled = true; },
      );
      mock._controller.add([ConnectivityResult.none]);
      await Future.delayed(Duration(milliseconds: 600));
      expect(offlineCalled, isTrue);
      expect(manager.isOnline, isFalse);
    });

    test('debounces connectivity changes', () async {
      final mock = _MockConnectivity();
      int changeCount = 0;
      SyncManager(
        connectivity: mock,
        initialStatus: ConnectivityStatus.online,
        onOffline: () { changeCount++; },
      );
      mock._controller.add([ConnectivityResult.none]);
      mock._controller.add([ConnectivityResult.wifi]);
      mock._controller.add([ConnectivityResult.none]);
      await Future.delayed(Duration(milliseconds: 600));
      expect(changeCount, 1);
    });

    test('onStatusChanged stream emits status changes', () async {
      final mock = _MockConnectivity();
      final manager = SyncManager(
        connectivity: mock,
        initialStatus: ConnectivityStatus.online,
      );
      final events = <ConnectivityStatus>[];
      manager.onStatusChanged.listen(events.add);
      mock._controller.add([ConnectivityResult.none]);
      await Future.delayed(Duration(milliseconds: 600));
      expect(events, [ConnectivityStatus.offline]);
    });

    test('dispose cancels timer and closes stream', () {
      final mock = _MockConnectivity();
      final manager = SyncManager(connectivity: mock);
      manager.dispose();
      expect(manager.isOnline, isTrue);
    });
  });
}
