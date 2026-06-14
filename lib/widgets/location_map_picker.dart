import 'dart:math' as math;

import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';

class LocationMapPicker extends StatefulWidget {
  const LocationMapPicker({
    super.key,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.onLocationChanged,
    required this.onUseCurrentLocation,
    this.isLocating = false,
    this.height = 220,
    this.actionLabel = 'Use current location',
  });

  final String title;
  final String subtitle;
  final double? latitude;
  final double? longitude;
  final ValueChanged<({double latitude, double longitude})> onLocationChanged;
  final VoidCallback onUseCurrentLocation;
  final bool isLocating;
  final double height;
  final String actionLabel;

  static const _fallbackLatitude = 30.0444;
  static const _fallbackLongitude = 31.2357;
  static const _mapLatitudeSpan = 0.18;
  static const _mapLongitudeSpan = 0.18;

  @override
  State<LocationMapPicker> createState() => _LocationMapPickerState();
}

class _LocationMapPickerState extends State<LocationMapPicker> {
  late double _centerLatitude;
  late double _centerLongitude;

  @override
  void initState() {
    super.initState();
    _centerLatitude = widget.latitude ?? LocationMapPicker._fallbackLatitude;
    _centerLongitude = widget.longitude ?? LocationMapPicker._fallbackLongitude;
  }

  @override
  void didUpdateWidget(covariant LocationMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasNewLocation = widget.latitude != null && widget.longitude != null;
    final hadLocation =
        oldWidget.latitude != null && oldWidget.longitude != null;
    final isOutsideMap =
        hasNewLocation &&
        ((widget.latitude! - _centerLatitude).abs() >
                LocationMapPicker._mapLatitudeSpan / 2 ||
            (widget.longitude! - _centerLongitude).abs() >
                LocationMapPicker._mapLongitudeSpan / 2);
    if (hasNewLocation && (!hadLocation || isOutsideMap)) {
      _centerLatitude = widget.latitude!;
      _centerLongitude = widget.longitude!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasLocation = widget.latitude != null && widget.longitude != null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outline),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: scheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(
                height: widget.height,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pinOffset = _offsetForLocation(
                      constraints.biggest,
                      widget.latitude ?? _centerLatitude,
                      widget.longitude ?? _centerLongitude,
                    );

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        widget.onLocationChanged(
                          _locationForOffset(
                            details.localPosition,
                            constraints.biggest,
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _LocationMapPainter(theme),
                            ),
                          ),
                          Positioned(
                            left: pinOffset.dx - 24,
                            top: pinOffset.dy - 44,
                            child: AnimatedScale(
                              scale: hasLocation ? 1 : 0.92,
                              duration: AppAnimations.medium,
                              curve: AppAnimations.gentle,
                              child: _MapPin(hasLocation: hasLocation),
                            ),
                          ),
                          Positioned(
                            left: AppSpacing.md,
                            right: AppSpacing.md,
                            bottom: AppSpacing.md,
                            child: _CoordinatePill(
                              latitude: widget.latitude,
                              longitude: widget.longitude,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.isLocating
                        ? null
                        : widget.onUseCurrentLocation,
                    icon: widget.isLocating
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(widget.actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Offset _offsetForLocation(Size size, double lat, double lng) {
    final normalizedX =
        ((lng - (_centerLongitude - LocationMapPicker._mapLongitudeSpan / 2)) /
                LocationMapPicker._mapLongitudeSpan)
            .clamp(0.18, 0.82);
    final normalizedY =
        (1 -
                ((lat -
                        (_centerLatitude -
                            LocationMapPicker._mapLatitudeSpan / 2)) /
                    LocationMapPicker._mapLatitudeSpan))
            .clamp(0.22, 0.72);
    return Offset(size.width * normalizedX, size.height * normalizedY);
  }

  ({double latitude, double longitude}) _locationForOffset(
    Offset offset,
    Size size,
  ) {
    final x = (offset.dx / math.max(size.width, 1)).clamp(0.0, 1.0);
    final y = (offset.dy / math.max(size.height, 1)).clamp(0.0, 1.0);
    return (
      latitude:
          _centerLatitude + ((0.5 - y) * LocationMapPicker._mapLatitudeSpan),
      longitude:
          _centerLongitude + ((x - 0.5) * LocationMapPicker._mapLongitudeSpan),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.hasLocation});

  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 48,
      height: 54,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 26,
            child: Container(
              width: 22,
              height: 8,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          Icon(
            Icons.location_on_rounded,
            color: hasLocation
                ? scheme.primary
                : scheme.primary.withValues(alpha: 0.65),
            size: 46,
            shadows: [
              Shadow(
                color: scheme.primary.withValues(alpha: 0.18),
                blurRadius: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoordinatePill extends StatelessWidget {
  const _CoordinatePill({required this.latitude, required this.longitude});

  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = latitude == null || longitude == null
        ? 'Tap the map or use current location'
        : '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';

    return AnimatedContainer(
      duration: AppAnimations.medium,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: const [AppShadows.sm],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me_rounded, color: scheme.primary, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: latitude == null ? theme.hintColor : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationMapPainter extends CustomPainter {
  const _LocationMapPainter(this.theme);

  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = LinearGradient(
        colors: [
          theme.colorScheme.primary.withValues(alpha: 0.035),
          theme.colorScheme.tertiary.withValues(alpha: 0.025),
          theme.colorScheme.surface,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final grid = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    const spacing = 30.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final road = Paint()
      ..color = theme.colorScheme.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.68)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.52,
        size.width * 0.42,
        size.height * 0.8,
        size.width * 0.7,
        size.height * 0.58,
      )
      ..cubicTo(
        size.width * 0.84,
        size.height * 0.46,
        size.width * 0.82,
        size.height * 0.25,
        size.width * 0.96,
        size.height * 0.18,
      );
    canvas.drawPath(path, road);

    final secondaryRoad = Paint()
      ..color = theme.colorScheme.secondary.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.16),
      Offset(size.width * 0.86, size.height * 0.36),
      secondaryRoad,
    );
  }

  @override
  bool shouldRepaint(covariant _LocationMapPainter oldDelegate) {
    return oldDelegate.theme != theme;
  }
}
