import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BloodTypeChip extends StatelessWidget {
  const BloodTypeChip({
    super.key,
    required this.type,
    required this.selected,
    this.onTap,
    this.compact = false,
  });

  final String type;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hPad = compact ? 12.0 : 14.0;
    final vPad = compact ? 8.0 : 10.0;
    final fontSize = compact ? 13.0 : 15.0;
    final radius = compact ? AppRadius.sm : AppRadius.md;

    return Semantics(
      button: true,
      label: 'Blood type $type',
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppAnimations.medium,
          curve: AppAnimations.defaultCurve,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryRed : Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? AppColors.primaryRed : AppColors.divider,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected ? AppShadows.primary : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: AppAnimations.medium,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
            child: Text(type),
          ),
        ),
      ),
    );
  }
}
