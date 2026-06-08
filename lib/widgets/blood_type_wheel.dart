import 'dart:math' as math;
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/utils/blood_compatibility.dart';
import 'package:flutter/material.dart';

enum CompatibilityDirection {
  /// Which donor types can donate TO the selected type.
  donorsForSelected,

  /// Which types the selected type can donate TO.
  selectedCanDonateTo,
}

class BloodTypeWheel extends StatelessWidget {
  const BloodTypeWheel({
    super.key,
    required this.selectedType,
    this.size = 260,
    this.showLabel = true,
    this.label,
    this.direction = CompatibilityDirection.donorsForSelected,
  });

  final String selectedType;
  final double size;
  final bool showLabel;
  final String? label;
  final CompatibilityDirection direction;

  static const allTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  Widget build(BuildContext context) {
    if (selectedType.isEmpty) return const SizedBox.shrink();

    final compatible = switch (direction) {
      CompatibilityDirection.donorsForSelected =>
        donorBloodTypesCompatibleWith(selectedType),
      CompatibilityDirection.selectedCanDonateTo =>
        donorCanFulfillRequestTypes[selectedType] ?? [],
    };

    final defaultLabel = switch (direction) {
      CompatibilityDirection.donorsForSelected =>
        'Compatible donors for $selectedType',
      CompatibilityDirection.selectedCanDonateTo =>
        '$selectedType can donate to',
    };

    return SizedBox(
      width: size,
      height: size + (showLabel ? 36 : 0),
      child: Column(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _BloodTypeWheelPainter(
                selectedType: selectedType,
                compatibleTypes: compatible,
              ),
            ),
          ),
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                label ?? defaultLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _BloodTypeWheelPainter extends CustomPainter {
  _BloodTypeWheelPainter({
    required this.selectedType,
    required this.compatibleTypes,
  });

  final String selectedType;
  final List<String> compatibleTypes;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 6;
    final typeR = 22.0;
    final orbitR = outerR * 0.72;

    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerR, bgPaint);

    final bgBorder = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, outerR, bgBorder);

    for (var i = 0; i < BloodTypeWheel.allTypes.length; i++) {
      final type = BloodTypeWheel.allTypes[i];
      final angle = -math.pi / 2 + i * 2 * math.pi / 8;
      final x = center.dx + orbitR * math.cos(angle);
      final y = center.dy + orbitR * math.sin(angle);
      final pos = Offset(x, y);

      final isCompatible = compatibleTypes.contains(type);
      final isSelected = type == selectedType;

      if (!isSelected) {
        final linePaint = Paint()
          ..color = isCompatible
              ? AppColors.success.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawLine(center, pos, linePaint);
      }

      Color fillColor;
      Color textColor;
      double borderWidth;
      Color borderColor;

      if (isSelected) {
        fillColor = AppColors.primaryRed.withValues(alpha: 0.15);
        textColor = AppColors.primaryRed;
        borderColor = AppColors.primaryRed;
        borderWidth = 2;
      } else if (isCompatible) {
        fillColor = AppColors.success.withValues(alpha: 0.12);
        textColor = AppColors.success;
        borderColor = AppColors.success;
        borderWidth = 1.5;
      } else {
        fillColor = Colors.grey.withValues(alpha: 0.04);
        textColor = AppColors.textTertiary;
        borderColor = Colors.grey.withValues(alpha: 0.15);
        borderWidth = 1;
      }

      canvas.drawCircle(
        pos,
        typeR,
        Paint()..color = fillColor..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pos,
        typeR,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: type,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: isSelected || isCompatible
                ? FontWeight.w700
                : FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    final centerR = outerR * 0.28;
    canvas.drawCircle(
      center,
      centerR,
      Paint()..color = AppColors.primaryRed..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      centerR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final ct = TextPainter(
      text: TextSpan(
        text: selectedType,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ct.paint(canvas, center - Offset(ct.width / 2, ct.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BloodTypeWheelPainter oldDelegate) {
    return oldDelegate.selectedType != selectedType;
  }
}
