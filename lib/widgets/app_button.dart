import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppButton extends StatefulWidget {
  const AppButton._({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    required this.variant,
    this.size = ButtonSize.lg,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.size = ButtonSize.lg,
  }) : variant = ButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.size = ButtonSize.lg,
  }) : variant = ButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.size = ButtonSize.lg,
  }) : variant = ButtonVariant.ghost;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.size = ButtonSize.lg,
  }) : variant = ButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final bool isLoading;
  final ButtonSize size;

  @override
  State<AppButton> createState() => _AppButtonState();
}

enum ButtonVariant { primary, secondary, ghost, danger }

enum ButtonSize { sm, md, lg }

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  double _scale = 1;

  void _animatePress(bool down) {
    setState(() => _scale = down ? AppAnimations.scalePress : 1);
  }

  double get _height {
    switch (widget.size) {
      case ButtonSize.sm:
        return 40;
      case ButtonSize.md:
        return 48;
      case ButtonSize.lg:
        return 56;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case ButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 16);
      case ButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 20);
      case ButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 24);
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case ButtonSize.sm:
        return 13;
      case ButtonSize.md:
        return 14;
      case ButtonSize.lg:
        return 15;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case ButtonSize.sm:
        return 16;
      case ButtonSize.md:
        return 18;
      case ButtonSize.lg:
        return 20;
    }
  }

  double get _loadingSize {
    switch (widget.size) {
      case ButtonSize.sm:
        return 16;
      case ButtonSize.md:
        return 18;
      case ButtonSize.lg:
        return 22;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    Color bgColor;
    Color textColor;
    Color borderColor;
    List<BoxShadow>? shadows;
    Color? splashColor;

    switch (widget.variant) {
      case ButtonVariant.primary:
        bgColor = enabled ? AppColors.primaryRed : AppColors.textTertiary;
        textColor = Colors.white;
        borderColor = Colors.transparent;
        shadows = AppShadows.primary;
        splashColor = Colors.white.withValues(alpha: 0.2);
      case ButtonVariant.secondary:
        bgColor = Colors.transparent;
        textColor = enabled ? AppColors.primaryRed : AppColors.textTertiary;
        borderColor = enabled ? AppColors.primaryRed : AppColors.divider;
        shadows = null;
        splashColor = AppColors.primaryRed.withValues(alpha: 0.08);
      case ButtonVariant.ghost:
        bgColor = Colors.transparent;
        textColor = enabled ? AppColors.textSecondary : AppColors.textTertiary;
        borderColor = Colors.transparent;
        shadows = null;
        splashColor = AppColors.textSecondary.withValues(alpha: 0.08);
      case ButtonVariant.danger:
        bgColor = enabled ? AppColors.error : AppColors.textTertiary;
        textColor = Colors.white;
        borderColor = Colors.transparent;
        shadows = null;
        splashColor = Colors.white.withValues(alpha: 0.2);
    }

    return GestureDetector(
      onTapDown: enabled ? (_) => _animatePress(true) : null,
      onTapUp: enabled ? (_) => _animatePress(false) : null,
      onTapCancel: () => _animatePress(false),
      child: AnimatedScale(
        scale: _scale,
        duration: AppAnimations.fast,
        child: SizedBox(
          width: widget.variant == ButtonVariant.ghost ? null : double.infinity,
          height: _height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              color: bgColor,
              border: Border.all(color: borderColor),
              boxShadow: shadows,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: enabled ? widget.onPressed : null,
                splashColor: splashColor,
                highlightColor: splashColor.withValues(alpha: 0.3),
                child: Padding(
                  padding: _padding,
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: _loadingSize,
                            height: _loadingSize,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(textColor),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(widget.icon, color: textColor, size: _iconSize),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                widget.label,
                                style: GoogleFonts.inter(
                                  fontSize: _fontSize,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
