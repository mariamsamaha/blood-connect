import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BadgeCard extends StatelessWidget {
  const BadgeCard({
    super.key,
    required this.icon,
    required this.name,
    required this.earned,
    this.progress = 1,
  });

  final String icon;
  final String name;
  final bool earned;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: earned ? const Color(0xFFD4AF37) : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (!earned)
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
        ],
      ),
    );
  }
}

