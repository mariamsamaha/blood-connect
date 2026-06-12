import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/urgency_badge.dart';
import 'package:flutter/material.dart';

class RequestCard extends StatefulWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final BloodRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _urgencyColor {
    switch (widget.request.urgencyLevel) {
      case UrgencyLevel.critical:
        return AppColors.primaryRed;
      case UrgencyLevel.urgent:
        return AppColors.warning;
      case UrgencyLevel.routine:
        return AppColors.info;
    }
  }

  Color get _urgencyBg {
    switch (widget.request.urgencyLevel) {
      case UrgencyLevel.critical:
        return AppColors.softRed;
      case UrgencyLevel.urgent:
        return AppColors.softAmber;
      case UrgencyLevel.routine:
        return AppColors.softBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = widget.request.urgencyLevel == UrgencyLevel.critical;
    final createdAgo = DateTime.now().difference(widget.request.createdAt);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppAnimations.medium,
      curve: AppAnimations.smooth,
      builder: (context, opacity, child) {
        return Opacity(opacity: opacity, child: child);
      },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final pulseVal = _pulse.value;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: isCritical
                  ? [
                      BoxShadow(
                        color: AppColors.primaryRed.withValues(
                          alpha: 0.08 + (pulseVal * 0.10),
                        ),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: isCritical
                ? Border.all(
                    color: AppColors.primaryRed.withValues(alpha: 0.15),
                  )
                : Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _urgencyColor,
                      _urgencyColor.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _urgencyBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.request.bloodType,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: _urgencyColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const Spacer(),
                        UrgencyBadge(level: widget.request.urgencyLevel),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.local_hospital_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.request.hospitalName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.request.distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.request.distanceKm!.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _MetaChip(
                          icon: Icons.bloodtype_outlined,
                          label: '${widget.request.unitsNeeded} unit${widget.request.unitsNeeded == 1 ? '' : 's'}',
                        ),
                        _MetaChip(
                          icon: Icons.access_time_rounded,
                          label: createdAgo.inMinutes < 60
                              ? '${createdAgo.inMinutes} min ago'
                              : createdAgo.inHours < 24
                                  ? '${createdAgo.inHours}h ago'
                                  : '${createdAgo.inDays}d ago',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.secondary(
                            label: 'Decline',
                            onPressed: widget.onDecline,
                            size: ButtonSize.md,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton.primary(
                            label: 'Accept',
                            onPressed: widget.onAccept,
                            size: ButtonSize.md,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
