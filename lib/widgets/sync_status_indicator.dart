import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(mutationQueueServiceProvider);
    return queueAsync.when(
      data: (queue) {
        final count = queue.pendingCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              count > 0 ? Icons.sync_rounded : Icons.cloud_done_rounded,
              color: count > 0
                  ? AppColors.warning
                  : AppColors.textSecondary,
              size: 22,
            ),
            if (count > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryRed,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (count > 0)
              Positioned(
                right: -10,
                top: -8,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Icon(Icons.cloud_outlined, color: AppColors.textSecondary, size: 22),
      error: (_, __) => const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 22),
    );
  }
}
