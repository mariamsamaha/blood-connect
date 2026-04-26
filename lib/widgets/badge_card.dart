import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';

class BadgeCard extends StatelessWidget {
  const BadgeCard({
    super.key,
    required this.icon,
    required this.name,
    required this.earned,
    this.progress = 0.0,
    this.progressLabel,
  });

  final String icon;
  final String name;
  final bool earned;
  final double progress;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1.0 : 0.5,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: earned
              ? AppColors.primaryRed.withAlpha(20)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: earned ? AppColors.primaryRed : AppColors.divider,
            width: earned ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            if (!earned) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: AppColors.divider,
                valueColor: const AlwaysStoppedAnimation(AppColors.primaryRed),
              ),
              const SizedBox(height: 4),
              Text(
                progressLabel ?? '',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

