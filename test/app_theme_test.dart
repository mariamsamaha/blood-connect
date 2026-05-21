import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/theme/app_theme.dart';

void main() {
  group('AppColors', () {
    test('has all required color constants', () {
      expect(AppColors.primaryRed, const Color(0xFFC0152A));
      expect(AppColors.deepRed, const Color(0xFF8B0000));
      expect(AppColors.background, const Color(0xFFF7F8FA));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.darkSurface, const Color(0xFF1C1C1E));
      expect(AppColors.textPrimary, const Color(0xFF1A1A2E));
      expect(AppColors.textSecondary, const Color(0xFF6B7280));
      expect(AppColors.success, const Color(0xFF10B981));
      expect(AppColors.warning, const Color(0xFFF59E0B));
      expect(AppColors.error, const Color(0xFFEF4444));
      expect(AppColors.divider, const Color(0xFFE5E7EB));
    });
  });

  group('AppTheme', () {
    test('page padding is 20 horizontal', () {
      expect(AppTheme.pagePadding, const EdgeInsets.symmetric(horizontal: 20));
    });

    test('card radius is 16', () {
      expect(AppTheme.cardRadius, const Radius.circular(16));
    });

    test('button radius is 12', () {
      expect(AppTheme.buttonRadius, const Radius.circular(12));
    });

    test('chip radius is 8', () {
      expect(AppTheme.chipRadius, const Radius.circular(8));
    });
  });
}
