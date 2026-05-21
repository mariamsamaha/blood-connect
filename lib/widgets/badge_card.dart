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

  /// Renders the icon as an image if it's a URL, otherwise as emoji text.
  static Widget _iconWidget(String icon) {
    if (icon.startsWith('http://') || icon.startsWith('https://')) {
      return Image.network(icon, width: 24, height: 24, errorBuilder: (_, __, ___) => const Text('\u{1F3C6}', style: TextStyle(fontSize: 24)));
    }
    return Text(icon, style: const TextStyle(fontSize: 24));
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1.0 : 0.5,
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(8),
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
            _iconWidget(icon),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!earned) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: AppColors.divider,
                valueColor: const AlwaysStoppedAnimation(AppColors.primaryRed),
              ),
              if (progressLabel != null)
                Text(
                  progressLabel!,
                  style: const TextStyle(
                    fontSize: 8,
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

