import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/theme/app_theme.dart';

void main() {
  group('AppColors', () {
    test('has all required color constants', () {
      expect(AppColors.primaryRed, const Color(0xFFDC2626));
      expect(AppColors.deepRed, const Color(0xFF991B1B));
      expect(AppColors.background, const Color(0xFFF8F9FC));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.darkSurface, const Color(0xFF1C1C1E));
      expect(AppColors.textPrimary, const Color(0xFF111827));
      expect(AppColors.textSecondary, const Color(0xFF6B7280));
      expect(AppColors.success, const Color(0xFF059669));
      expect(AppColors.warning, const Color(0xFFD97706));
      expect(AppColors.error, const Color(0xFFDC2626));
      expect(AppColors.divider, const Color(0xFFE5E7EB));
    });
  });

  group('AppTheme', () {
    testWidgets('light theme is defined', (_) async {
      expect(AppTheme.light, isA<ThemeData>());
    });

    testWidgets('dark theme is defined', (_) async {
      expect(AppTheme.dark, isA<ThemeData>());
    });
  });

  group('AppRadius', () {
    test('has radius constants', () {
      expect(AppRadius.sm, 8.0);
      expect(AppRadius.md, 12.0);
      expect(AppRadius.lg, 16.0);
      expect(AppRadius.xl, 20.0);
      expect(AppRadius.full, 999.0);
    });
  });

  group('AppSpacing', () {
    test('has spacing constants', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 20.0);
      expect(AppSpacing.xxl, 24.0);
    });
  });
}
