import 'package:bloodconnect/providers/core_providers.dart';
import 'package:bloodconnect/models/notification_item.dart';
import 'package:bloodconnect/providers/notification_provider.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/empty_state.dart';
import 'package:bloodconnect/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(unreadCountNotifierProvider.notifier).refresh();
      ref.invalidate(notificationsProvider);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(notificationsProvider);
    ref.read(unreadCountNotifierProvider.notifier).refresh();
  }

  Future<void> _markRead(NotificationItem notification) async {
    if (!notification.isUnread) return;
    final service = ref.read(notificationServiceProvider);
    await service.markAsRead(notificationId: notification.id);
    ref.invalidate(notificationsProvider);
    ref.read(unreadCountNotifierProvider.notifier).refresh();
  }

  Future<void> _markAllRead() async {
    final service = ref.read(notificationServiceProvider);
    await service.markAsRead();
    ref.invalidate(notificationsProvider);
    ref.read(unreadCountNotifierProvider.notifier).refresh();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'request_alert':
        return Icons.bloodtype_rounded;
      case 'fulfillment_update':
        return Icons.check_circle_outline_rounded;
      case 'reward_earned':
        return Icons.emoji_events_rounded;
      case 'story_like':
        return Icons.favorite_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notificationsAsync.hasValue &&
              notificationsAsync.value!.any((n) => n.isUnread))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _refresh,
        child: notificationsAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: List.generate(
              6,
              (_) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SkeletonListItem(),
              ),
            ),
          ),
          error: (_, __) => ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Could not load notifications'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          data: (notifications) {
            if (notifications.isEmpty) {
              return const SizedBox(
                height: double.infinity,
                child: EmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: 'No notifications yet',
                  subtitle: 'Notifications will appear here when events happen.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = notifications[index];
                final timeAgo = _timeAgo(n.sentAt);
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _colorForType(n.notificationType)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconForType(n.notificationType),
                      color: _colorForType(n.notificationType),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight:
                          n.isUnread ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        n.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: n.isUnread
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  trailing: n.isUnread
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryRed,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                  onTap: () {
                    _markRead(n);
                    if (n.requestId != null && n.requestId!.isNotEmpty) {
                      context.pop();
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'request_alert':
        return AppColors.primaryRed;
      case 'fulfillment_update':
        return AppColors.success;
      case 'reward_earned':
        return AppColors.warning;
      case 'story_like':
        return AppColors.primaryRed;
      default:
        return AppColors.textSecondary;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}
