import 'dart:async';

import 'package:flutter/foundation.dart';
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
    debugPrint('UnreadCountNotifier: build started');
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      debugPrint('UnreadCountNotifier: timer tick');
      _refresh();
    });
    ref.onDispose(() {
      debugPrint('UnreadCountNotifier: disposed');
      _timer?.cancel();
    });
    return 0;
  }

  Future<void> _refresh() async {
    _pendingRefresh++;
    final myRefresh = _pendingRefresh;
    try {
      final service = ref.read(notificationServiceProvider);
      final count = await service.getUnreadCount();
      if (myRefresh == _pendingRefresh) {
        debugPrint('UnreadCountNotifier: setting state=$count (was $state)');
        state = count;
      } else {
        debugPrint('UnreadCountNotifier: discarded stale refresh (req=$myRefresh, pending=$_pendingRefresh)');
      }
    } catch (e) {
      debugPrint('UnreadCountNotifier refresh failed: $e');
    }
  }

  Future<void> refresh() => _refresh();
}

final unreadCountNotifierProvider =
    NotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);

final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.getNotifications();
});
