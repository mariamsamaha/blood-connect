import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ConnectivityStatus { online, offline }

class SyncManager {
  final Connectivity _connectivity;
  final StreamController<ConnectivityStatus> _statusController;
  ConnectivityStatus _status;
  Timer? _debounceTimer;
  final VoidCallback? onOnline;
  final VoidCallback? onOffline;

  static const _debounceDuration = Duration(milliseconds: 500);

  Stream<ConnectivityStatus> get onStatusChanged => _statusController.stream;
  ConnectivityStatus get currentStatus => _status;
  bool get isOnline => _status == ConnectivityStatus.online;

  SyncManager({
    Connectivity? connectivity,
    ConnectivityStatus initialStatus = ConnectivityStatus.online,
    this.onOnline,
    this.onOffline,
  })  : _connectivity = connectivity ?? Connectivity(),
        _status = initialStatus,
        _statusController = StreamController<ConnectivityStatus>.broadcast() {
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<void> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () => _updateStatus(results));
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    final newStatus =
        online ? ConnectivityStatus.online : ConnectivityStatus.offline;
    if (newStatus != _status) {
      final previous = _status;
      _status = newStatus;
      _statusController.add(newStatus);
      if (previous == ConnectivityStatus.offline && online) {
        onOnline?.call();
      } else if (previous == ConnectivityStatus.online && !online) {
        onOffline?.call();
      }
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _statusController.close();
  }
}
