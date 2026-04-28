import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UrgencyBadge extends StatelessWidget {
  const UrgencyBadge({super.key, required this.level});

  final UrgencyLevel level;

  Color get color {
    switch (level) {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level.name.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

