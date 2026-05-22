import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.trailing,
    this.showDivider = false,
  });

  final String title;
  final Widget? action;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (action != null) ...[
              action!,
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 8),
          Container(height: 2, decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            gradient: LinearGradient(
              colors: [AppColors.primaryRed.withValues(alpha: 0.3), Colors.transparent],
            ),
          )),
        ],
      ],
    );
  }
}
