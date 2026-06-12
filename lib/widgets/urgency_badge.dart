import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';

class UrgencyBadge extends StatefulWidget {
  const UrgencyBadge({super.key, required this.level, this.size = BadgeSize.md});

  final UrgencyLevel level;
  final BadgeSize size;

  @override
  State<UrgencyBadge> createState() => _UrgencyBadgeState();
}

class _UrgencyBadgeState extends State<UrgencyBadge>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _createAnimation();
    _maybeStartAfterFirstFrame();
  }

  @override
  void didUpdateWidget(covariant UrgencyBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _pulseController.dispose();
      _createAnimation();
      _maybeStartAfterFirstFrame();
    }
  }

  void _createAnimation() {
    switch (widget.level) {
      case UrgencyLevel.critical:
        _pulseController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600),
        );
        _scaleAnimation = TweenSequence([
          TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 1.25)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 20,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.25, end: 1.0)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 80,
          ),
        ]).animate(_pulseController);
      case UrgencyLevel.urgent:
        _pulseController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1400),
        );
        _scaleAnimation = TweenSequence([
          TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 1.15)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 20,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.15, end: 1.0)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 80,
          ),
        ]).animate(_pulseController);
      case UrgencyLevel.routine:
        _pulseController = AnimationController(
          vsync: this,
          value: 1,
        );
        _scaleAnimation = AlwaysStoppedAnimation(1.0);
    }
  }

  void _maybeStartAfterFirstFrame() {
    if (widget.level == UrgencyLevel.routine) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pulseController.repeat();
    });
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

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.size == BadgeSize.sm ? 14.0 : 18.0;
    final containerSize = widget.size == BadgeSize.sm ? 28.0 : 36.0;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: containerSize,
        height: containerSize,
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: _color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.favorite,
          size: iconSize,
          color: _color,
        ),
      ),
    );
  }
}

enum BadgeSize { sm, md }
