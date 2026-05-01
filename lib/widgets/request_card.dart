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

  Color get _leftBarColor {
    switch (widget.request.urgencyLevel) {
      case UrgencyLevel.critical:
        return AppColors.primaryRed;
      case UrgencyLevel.urgent:
        return AppColors.warning;
      case UrgencyLevel.routine:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = widget.request.urgencyLevel == UrgencyLevel.critical;
    final createdAgo = DateTime.now().difference(widget.request.createdAt);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isCritical
              ? [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(
                      alpha: 0.12 + (_pulse.value * 0.12),
                    ),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 170,
              decoration: BoxDecoration(
                color: _leftBarColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.request.bloodType,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Spacer(),
                        UrgencyBadge(level: widget.request.urgencyLevel),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.request.hospitalName} • ${widget.request.distanceKm?.toStringAsFixed(1) ?? '-'} km',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text('${widget.request.unitsNeeded} units'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Chip(
                          label: Text(
                            createdAgo.inMinutes < 60
                                ? 'Posted ${createdAgo.inMinutes} min ago'
                                : createdAgo.inHours < 24
                                    ? 'Posted ${createdAgo.inHours}h ago'
                                    : 'Posted ${createdAgo.inDays}d ago',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.secondary(
                            label: 'Decline',
                            onPressed: widget.onDecline,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton.primary(
                            label: 'Accept',
                            onPressed: widget.onAccept,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

