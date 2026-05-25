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

  static Widget _iconWidget(String icon) {
    if (icon.startsWith('http://') || icon.startsWith('https://')) {
      return Image.network(
        icon,
        width: 28,
        height: 28,
        errorBuilder: (_, __, ___) =>
            const Text('🏆', style: TextStyle(fontSize: 28)),
      );
    }
    return Text(icon, style: const TextStyle(fontSize: 28));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: earned ? AppColors.softRed : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: earned
              ? AppColors.primaryRed.withValues(alpha: 0.3)
              : AppColors.divider,
          width: earned ? 1.5 : 1,
        ),
        boxShadow: earned ? AppShadows.glowRed : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: AppAnimations.medium,
            curve: AppAnimations.bounce,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: _iconWidget(icon),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: earned ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!earned) ...[
            const SizedBox(height: 6),
            // LayoutBuilder detects unconstrained width (e.g. from GridView
            // inside a ListView) and provides a safe fallback of 80px so
            // LinearProgressIndicator never receives infinite width.
            LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 80.0;
                return SizedBox(
                  width: barWidth,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: AppAnimations.slow,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 4,
                        backgroundColor: AppColors.divider,
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      );
                    },
                  ),
                );
              },
            ),
            if (progressLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                progressLabel!,
                style: TextStyle(fontSize: 8, color: AppColors.textSecondary),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
