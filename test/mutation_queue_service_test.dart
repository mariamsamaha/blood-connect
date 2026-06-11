import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/services/mutation_queue_service.dart';
import 'package:bloodconnect/services/sync_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  group('MutationQueueService', () {
    late Directory tmpDir;
    late SyncManager syncManager;
    int executedEndpoints = 0;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('mutation_queue_test_');
      executedEndpoints = 0;
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('enqueue adds to pending queue (offline)', () async {
      final mockConnectivity = _MockConnectivity([ConnectivityResult.none]);
      syncManager = SyncManager(
        connectivity: mockConnectivity,
        initialStatus: ConnectivityStatus.offline,
      );

      final service = MutationQueueService(
        executor: (endpoint, method, payload) async {
          executedEndpoints++;
        },
        syncManager: syncManager,
        storagePath: tmpDir.path,
      );

      await service.initialize();
      await service.enqueue(endpoint: '/test', method: 'POST', payload: {'key': 'val'});

      // Offline — mutation stays pending, executor not called
      expect(service.pendingCount, 1);
      expect(executedEndpoints, 0);

      await service.dispose();
    });

    test('executor runs when online', () async {
      final mockConnectivity = _MockConnectivity([ConnectivityResult.wifi]);
      syncManager = SyncManager(
        connectivity: mockConnectivity,
        initialStatus: ConnectivityStatus.online,
      );

      final service = MutationQueueService(
        executor: (endpoint, method, payload) async {
          executedEndpoints++;
        },
        syncManager: syncManager,
        storagePath: tmpDir.path,
      );

      await service.initialize();

      // Give the initial _processQueue call time to settle
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(executedEndpoints, 0); // queue was empty

      await service.enqueue(endpoint: '/test', method: 'POST', payload: {'key': 'val'});

      // Wait for async processing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.pendingCount, 0);
      expect(executedEndpoints, 1);

      await service.dispose();
    });

    test('enqueue deduplicates identical mutations', () async {
      final mockConnectivity = _MockConnectivity([ConnectivityResult.none]);
      syncManager = SyncManager(
        connectivity: mockConnectivity,
        initialStatus: ConnectivityStatus.offline,
      );

      final service = MutationQueueService(
        executor: (endpoint, method, payload) async {},
        syncManager: syncManager,
        storagePath: tmpDir.path,
      );

      await service.initialize();
      await service.enqueue(endpoint: '/test', method: 'POST', payload: {'key': 'val'});
      await service.enqueue(endpoint: '/test', method: 'POST', payload: {'key': 'val'});

      expect(service.pendingCount, 1);

      await service.dispose();
    });

    test('enqueue respects max queue size', () async {
      final mockConnectivity = _MockConnectivity([ConnectivityResult.none]);
      syncManager = SyncManager(
        connectivity: mockConnectivity,
        initialStatus: ConnectivityStatus.offline,
      );

      final service = MutationQueueService(
        executor: (endpoint, method, payload) async {},
        syncManager: syncManager,
        storagePath: tmpDir.path,
      );

      await service.initialize();
      // Enqueue more than max (which is 200)
      for (int i = 0; i < 210; i++) {
        await service.enqueue(endpoint: '/test/$i', method: 'POST');
      }

      expect(service.pendingCount, isNonZero);

      await service.dispose();
    });

    test('moves to dead letter after max retries', () async {
      final mockConnectivity = _MockConnectivity([ConnectivityResult.wifi]);
      syncManager = SyncManager(
        connectivity: mockConnectivity,
        initialStatus: ConnectivityStatus.online,
      );

      int attempts = 0;
      final service = MutationQueueService(
        maxRetries: 0, // immediate dead letter
        executor: (endpoint, method, payload) async {
          attempts++;
          throw Exception('Simulated failure');
        },
        syncManager: syncManager,
        storagePath: tmpDir.path,
      );

      await service.initialize();
      await service.enqueue(endpoint: '/test', method: 'POST');
      // Wait for retries to exhaust
      await Future.delayed(const Duration(milliseconds: 500));

      expect(service.deadLetterMutations.length, 1);

      await service.dispose();
    });

    test('retryDeadLetters resets dead letter items', () async {
      final mockConnectivity = _MockConnectivity([ConnectivityResult.none]);
      syncManager = SyncManager(
        connectivity: mockConnectivity,
        initialStatus: ConnectivityStatus.offline,
      );

      final service = MutationQueueService(
        executor: (endpoint, method, payload) async {
          throw Exception('Simulated failure');
        },
        syncManager: syncManager,
        storagePath: tmpDir.path,
      );

      await service.initialize();
      await service.enqueue(endpoint: '/test', method: 'POST');
      await Future.delayed(const Duration(milliseconds: 100));

      await service.retryDeadLetters();
      expect(service.deadLetterMutations.length, 0);

      await service.dispose();
    });

    test('enqueue when offline -> come online -> assert replay', () async {
      final connectivityCtrl = StreamController<List<ConnectivityResult>>();
      final mockConnectivity = _MockConnectivityCtrl(connectivityCtrl);
      syncManager = SyncManager(
        connectivity: mockConnectivity,
        initialStatus: ConnectivityStatus.offline,
      );

      int replayCount = 0;
      final service = MutationQueueService(
        executor: (endpoint, method, payload) async {
          replayCount++;
        },
        syncManager: syncManager,
        storagePath: tmpDir.path,
      );

      await service.initialize();

      // Enqueue while offline — stays pending
      await service.enqueue(endpoint: '/test', method: 'POST', payload: {'key': 'val'});
      await service.enqueue(endpoint: '/test2', method: 'PATCH', payload: {'k': 'v'});
      expect(service.pendingCount, 2);
      expect(replayCount, 0);

      // Simulate coming online — publish to connectivity stream
      connectivityCtrl.add([ConnectivityResult.wifi]);
      await Future.delayed(const Duration(milliseconds: 800)); // debounce 500ms + exec

      // Both mutations should be replayed
      expect(service.pendingCount, 0);
      expect(replayCount, 2);

      await service.dispose();
      await connectivityCtrl.close();
    });

    test('clearAll removes all mutations', () async {
      final mockConnectivity = _MockConnectivity([ConnectivityResult.none]);
      syncManager = SyncManager(
        connectivity: mockConnectivity,
        initialStatus: ConnectivityStatus.offline,
      );

      final service = MutationQueueService(
        executor: (endpoint, method, payload) async {},
        syncManager: syncManager,
        storagePath: tmpDir.path,
      );

      await service.initialize();
      await service.enqueue(endpoint: '/test', method: 'POST');
      await service.clearAll();

      expect(service.pendingCount, 0);

      await service.dispose();
    });
  });
}

class _MockConnectivity extends Fake implements Connectivity {
  final List<ConnectivityResult> _results;
  _MockConnectivity(this._results);

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream.value(_results);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _results;
}

class _MockConnectivityCtrl extends Fake implements Connectivity {
  final StreamController<List<ConnectivityResult>> controller;
  _MockConnectivityCtrl(this.controller);

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      controller.isClosed ? [] : controller.stream.first;
}
