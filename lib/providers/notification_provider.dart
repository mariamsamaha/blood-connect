import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/notification_item.dart';

final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.getNotifications();
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.getUnreadCount();
});

class UnreadCountNotifier extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  Future<void> _refresh() async {
    try {
      final service = ref.read(notificationServiceProvider);
      final count = await service.getUnreadCount();
      state = count;
    } catch (_) {}
  }

  void refresh() => _refresh();
}

final unreadCountNotifierProvider =
    NotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);
