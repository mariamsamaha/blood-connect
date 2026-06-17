import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloodconnect/providers/core_providers.dart';
import 'package:bloodconnect/models/notification_item.dart';

final unreadCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.getUnreadCount();
});

class UnreadCountNotifier extends Notifier<int> {
  Timer? _timer;
  int _pendingRefresh = 0;

  @override
  int build() {
    _refresh();
    return 0;
  }

  Future<void> _refresh() async {
    _pendingRefresh++;
    final myRefresh = _pendingRefresh;
    try {
      final service = ref.read(notificationServiceProvider);
      final count = await service.getUnreadCount();
      if (myRefresh == _pendingRefresh) {
        state = count;
        if (count > 0) _startPolling();
        else _stopPolling();
      }
    } catch (_) {}
  }

  void _startPolling() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    ref.onDispose(() => _timer?.cancel());
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() => _refresh();
}

final unreadCountNotifierProvider =
    NotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);

final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.getNotifications();
});
