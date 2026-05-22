import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primaryRed = Color(0xFFDC2626);
  static const deepRed = Color(0xFF991B1B);
  static const softRed = Color(0xFFFEF2F2);
  static const background = Color(0xFFF8F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const darkSurface = Color(0xFF1C1C1E);
  static const darkCard = Color(0xFF2C2C2E);
  static const darkBackground = Color(0xFF121214);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
  static const divider = Color(0xFFE5E7EB);
  static const darkDivider = Color(0xFF38383A);
  static const gold = Color(0xFFF59E0B);
  static const softGold = Color(0xFFFFF8E1);
  static const softGreen = Color(0xFFF0FDF4);
  static const softBlue = Color(0xFFEFF6FF);
  static const softAmber = Color(0xFFFFFBEB);
  static const darkSurfaceCard = Color(0xFF1E1E20);
}

class AppGradients {
  static const primary = LinearGradient(
    colors: [AppColors.primaryRed, AppColors.deepRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const primaryVertical = LinearGradient(
    colors: [AppColors.primaryRed, AppColors.deepRed],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const success = LinearGradient(
    colors: [AppColors.success, Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const warning = LinearGradient(
    colors: [AppColors.warning, Color(0xFFB45309)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const info = LinearGradient(
    colors: [AppColors.info, Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0x40000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const shimmer = LinearGradient(
    colors: [
      Color(0xFFE5E7EB),
      Color(0xFFF3F4F6),
      Color(0xFFE5E7EB),
      Color(0xFFF3F4F6),
    ],
    stops: [0.0, 0.3, 0.6, 1.0],
  );
  static const shimmerDark = LinearGradient(
    colors: [
      Color(0xFF2C2C2E),
      Color(0xFF3A3A3C),
      Color(0xFF2C2C2E),
      Color(0xFF3A3A3C),
    ],
    stops: [0.0, 0.3, 0.6, 1.0],
  );
  static const glass = LinearGradient(
    colors: [Color(0x66FFFFFF), Color(0x33FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const glassDark = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x0FFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppShadows {
  static const xs = BoxShadow(
    color: Color(0x06000000),
    blurRadius: 2,
    offset: Offset(0, 1),
  );
  static const sm = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 4,
    offset: Offset(0, 1),
  );
  static const md = BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  static const lg = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );
  static const xl = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
  static const xxl = BoxShadow(
    color: Color(0x1F000000),
    blurRadius: 40,
    offset: Offset(0, 12),
  );

  static final List<BoxShadow> card = [sm];
  static final List<BoxShadow> elevated = [lg];
  static final List<BoxShadow> modal = [xl];
  static final List<BoxShadow> dropdown = [md];

  static final List<BoxShadow> primary = [
    BoxShadow(
      color: AppColors.primaryRed.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.primaryRed.withValues(alpha: 0.1),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> glowRed = [
    BoxShadow(
      color: AppColors.primaryRed.withValues(alpha: 0.15),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  static final List<BoxShadow> glowGold = [
    BoxShadow(
      color: AppColors.gold.withValues(alpha: 0.25),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  static final List<BoxShadow> darkCard = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  static final List<BoxShadow> darkElevated = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  static final List<BoxShadow> darkPrimary = [
    BoxShadow(
      color: AppColors.primaryRed.withValues(alpha: 0.15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

class AppRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const full = 999.0;
}

class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;
  static const page = EdgeInsets.symmetric(horizontal: 20.0);
  static const pageV = EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0);
}

class AppAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration xSlow = Duration(milliseconds: 800);

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve spring = Curves.easeOutBack;
  static const Curve smooth = Curves.easeInOutCubic;
  static const Curve bounce = Curves.elasticOut;
  static const Curve gentle = Curves.easeOutQuart;

  static const scalePress = 0.97;
  static const scaleHover = 1.02;
}

class AppTheme {
  static TextTheme _textTheme(Color body, Color heading) {
    return TextTheme(
      displayLarge: GoogleFonts.poppins(
        fontSize: 28, fontWeight: FontWeight.bold, color: heading,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 24, fontWeight: FontWeight.bold, color: heading,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 22, fontWeight: FontWeight.w600, color: heading,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 18, fontWeight: FontWeight.w600, color: heading,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16, fontWeight: FontWeight.w600, color: heading,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: body,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w400, color: body,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w400, color: body,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w400, color: body,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
      ),
    );
  }

  static InputDecorationTheme _inputTheme(Color fill, Color border, Color focused) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: focused, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error, width: 1.6),
      ),
      errorStyle: GoogleFonts.inter(color: AppColors.error, fontSize: 12),
      hintStyle: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
      floatingLabelBehavior: FloatingLabelBehavior.never,
    );
  }

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryRed,
      onPrimary: Colors.white,
      secondary: AppColors.deepRed,
      surface: AppColors.surface,
      error: AppColors.error,
      tertiary: AppColors.info,
      outline: AppColors.divider,
    ),
    textTheme: _textTheme(AppColors.textPrimary, AppColors.textPrimary),
    dividerColor: AppColors.divider,
    dividerTheme: DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: AppColors.textSecondary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: _inputTheme(
      const Color(0xFFF9FAFB),
      AppColors.divider,
      AppColors.primaryRed,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
      actionTextColor: Colors.white,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      elevation: 0,
      selectedItemColor: AppColors.primaryRed,
      unselectedItemColor: AppColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
      enableFeedback: true,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      secondaryLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryRed,
      linearTrackColor: AppColors.divider,
      circularTrackColor: AppColors.divider,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primaryRed,
      inactiveTrackColor: AppColors.divider,
      thumbColor: AppColors.primaryRed,
      overlayColor: AppColors.primaryRed.withValues(alpha: 0.12),
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primaryRed;
        return AppColors.textTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primaryRed.withValues(alpha: 0.3);
        return AppColors.divider;
      }),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      elevation: 8,
      shadowColor: Colors.black26,
    ),
    timePickerTheme: TimePickerThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      hourMinuteTextColor: AppColors.primaryRed,
      dialHandColor: AppColors.primaryRed,
      dialBackgroundColor: AppColors.softRed,
      entryModeIconColor: AppColors.primaryRed,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(AppRadius.full),
      thumbColor: WidgetStateProperty.all(AppColors.textTertiary.withValues(alpha: 0.4)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        shadowColor: AppColors.primaryRed.withValues(alpha: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        side: const BorderSide(color: AppColors.divider),
        foregroundColor: AppColors.textPrimary,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryRed,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: _inputTheme(
        const Color(0xFFF9FAFB),
        AppColors.divider,
        AppColors.primaryRed,
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        elevation: WidgetStateProperty.all(4),
        shadowColor: WidgetStateProperty.all(Colors.black26),
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
    highlightColor: AppColors.primaryRed.withValues(alpha: 0.05),
    splashColor: AppColors.primaryRed.withValues(alpha: 0.08),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryRed,
      onPrimary: Colors.white,
      secondary: AppColors.deepRed,
      surface: AppColors.darkCard,
      error: AppColors.error,
      tertiary: AppColors.info,
      outline: AppColors.darkDivider,
    ),
    textTheme: _textTheme(const Color(0xFFE5E7EB), Colors.white),
    dividerColor: AppColors.darkDivider,
    dividerTheme: DividerThemeData(color: AppColors.darkDivider, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: AppColors.darkBackground,
      foregroundColor: Colors.white,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg))),
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: _inputTheme(
      const Color(0xFF222224),
      AppColors.darkDivider,
      AppColors.primaryRed,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      elevation: 0,
      selectedItemColor: AppColors.primaryRed,
      unselectedItemColor: AppColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.darkCard,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primaryRed;
        return AppColors.textTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primaryRed.withValues(alpha: 0.3);
        return AppColors.darkDivider;
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryRed,
      linearTrackColor: AppColors.darkDivider,
      circularTrackColor: AppColors.darkDivider,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primaryRed,
      inactiveTrackColor: AppColors.darkDivider,
      thumbColor: AppColors.primaryRed,
      overlayColor: AppColors.primaryRed.withValues(alpha: 0.12),
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      backgroundColor: const Color(0xFF2C2C2E),
      contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
      actionTextColor: AppColors.primaryRed,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      secondaryLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      elevation: 8,
      shadowColor: Colors.black45,
      backgroundColor: const Color(0xFF2C2C2E),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(AppRadius.full),
      thumbColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.15)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        side: const BorderSide(color: AppColors.darkDivider),
        foregroundColor: const Color(0xFFE5E7EB),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryRed,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      hourMinuteTextColor: Colors.white,
      dialHandColor: AppColors.primaryRed,
      dialBackgroundColor: AppColors.primaryRed.withValues(alpha: 0.15),
      entryModeIconColor: Colors.white,
      backgroundColor: const Color(0xFF2C2C2E),
      hourMinuteColor: Colors.white,
    ),
    splashFactory: InkSparkle.splashFactory,
    highlightColor: AppColors.primaryRed.withValues(alpha: 0.08),
    splashColor: AppColors.primaryRed.withValues(alpha: 0.12),
  );
}
