import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UrgencyBadge extends StatefulWidget {
  const UrgencyBadge({super.key, required this.level, this.size = BadgeSize.md});

  final UrgencyLevel level;
  final BadgeSize size;

  @override
  State<UrgencyBadge> createState() => _UrgencyBadgeState();
}

class _UrgencyBadgeState extends State<UrgencyBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    if (widget.level == UrgencyLevel.critical) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    } else {
      _pulseController = AnimationController(
        vsync: this,
        value: 1,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.level) {
      case UrgencyLevel.critical:
        return AppColors.primaryRed;
      case UrgencyLevel.urgent:
        return AppColors.warning;
      case UrgencyLevel.routine:
        return AppColors.info;
    }
  }

  IconData get _icon {
    switch (widget.level) {
      case UrgencyLevel.critical:
        return Icons.emergency_rounded;
      case UrgencyLevel.urgent:
        return Icons.warning_amber_rounded;
      case UrgencyLevel.routine:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hPad = widget.size == BadgeSize.sm ? 8.0 : 10.0;
    final vPad = widget.size == BadgeSize.sm ? 4.0 : 5.0;
    final fontSize = widget.size == BadgeSize.sm ? 10.0 : 11.0;
    final iconSize = widget.size == BadgeSize.sm ? 12.0 : 14.0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.12 + (pulse * 0.05)),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: _color.withValues(alpha: 0.2 + (pulse * 0.15)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: iconSize, color: _color),
              const SizedBox(width: 4),
              Text(
                widget.level.name.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: _color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum BadgeSize { sm, md }
