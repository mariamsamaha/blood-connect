import 'dart:async';
import 'dart:math' as math;

import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/screens/ai_eligibility_gate.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapDiscoverScreen extends ConsumerStatefulWidget {
  const MapDiscoverScreen({super.key});

  @override
  ConsumerState<MapDiscoverScreen> createState() => _MapDiscoverScreenState();
}

class _MapDiscoverScreenState extends ConsumerState<MapDiscoverScreen> {
  List<BloodRequest> _requests = const [];
  UserProfile? _profile;
  BloodRequest? _selectedRequest;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final donorService = ref.read(donorServiceProvider);
      final locationService = ref.read(locationServiceProvider);
      final firebase = auth.currentUser;
      if (firebase == null) return;

      final profile = await userService.getProfileByFirebaseUid(firebase.uid);
      if (profile == null) return;

      final pos = await locationService.getCurrentPosition();
      final lat = pos?.latitude ?? profile.latitude ?? 30.0444;
      final lng = pos?.longitude ?? profile.longitude ?? 31.2357;
      if (pos != null && profile.firebaseUid.isNotEmpty) {
        unawaited(
          userService.updateLocation(
            firebaseUid: profile.firebaseUid,
            latitude: pos.latitude,
            longitude: pos.longitude,
          ),
        );
      }

      final requests = await donorService.findMatchingRequests(
        donorId: profile.id,
        donorBloodType: profile.bloodType,
        donorLat: lat,
        donorLng: lng,
        radiusKm: math.max(25, profile.notificationRadiusKm),
      );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _requests = requests;
        _selectedRequest = requests.isEmpty ? null : requests.first;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load nearby requests.')),
      );
    }
  }

  Future<void> _respondToSelected() async {
    final request = _selectedRequest;
    final profile = _profile;
    if (request == null || profile == null) return;

    try {
      final allowed = await showAiEligibilityGate(context, ref, profile);
      if (!mounted || !allowed) return;

      final locationService = ref.read(locationServiceProvider);
      final donorService = ref.read(donorServiceProvider);
      final userService = ref.read(userServiceProvider);
      final pos = await locationService.getCurrentPosition();
      final lat = pos?.latitude ?? profile.latitude;
      final lng = pos?.longitude ?? profile.longitude;
      if (lat == null || lng == null) throw Exception('Location required');

      if (pos != null && profile.firebaseUid.isNotEmpty) {
        unawaited(
          userService.updateLocation(
            firebaseUid: profile.firebaseUid,
            latitude: pos.latitude,
            longitude: pos.longitude,
          ),
        );
      }

      await donorService.acceptRequest(
        requestId: request.id,
        donorId: profile.id,
        donorLat: lat,
        donorLng: lng,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted.')),
      );
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: _loadRequests,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      const SearchHeader(),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        height: math.max(430, constraints.maxHeight - 112),
                        child: DiscoveryMap(
                          isLoading: _isLoading,
                          requests: _requests,
                          selectedRequest: _selectedRequest,
                          onRequestSelected: (request) {
                            setState(() => _selectedRequest = request);
                          },
                          onRespond: _respondToSelected,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class SearchHeader extends StatelessWidget {
  const SearchHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.elevated,
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.search_rounded, color: theme.hintColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Search hospitals, areas...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
          Material(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            elevation: 4,
            shadowColor: scheme.primary.withValues(alpha: 0.28),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () {},
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.tune_rounded, color: scheme.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DiscoveryMap extends StatelessWidget {
  const DiscoveryMap({
    super.key,
    required this.isLoading,
    required this.requests,
    required this.selectedRequest,
    required this.onRequestSelected,
    required this.onRespond,
  });

  final bool isLoading;
  final List<BloodRequest> requests;
  final BloodRequest? selectedRequest;
  final ValueChanged<BloodRequest> onRequestSelected;
  final VoidCallback onRespond;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markerPositions = _markerPositions(requests.length);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.025),
            theme.colorScheme.surface,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _DiscoveryGridPainter(theme)),
            ),
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: isLoading ? 0.2 : 1,
                duration: AppAnimations.medium,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    Offset mapPoint(Offset point, double size) {
                      return Offset(
                        (constraints.maxWidth * point.dx - size / 2)
                            .clamp(
                              AppSpacing.sm,
                              constraints.maxWidth - size - AppSpacing.sm,
                            )
                            .toDouble(),
                        (constraints.maxHeight * point.dy - size / 2)
                            .clamp(
                              AppSpacing.sm,
                              constraints.maxHeight - size - AppSpacing.sm,
                            )
                            .toDouble(),
                      );
                    }

                    const donorPoints = [
                      Offset(0.82, 0.2),
                      Offset(0.18, 0.62),
                      Offset(0.7, 0.54),
                    ];

                    return Stack(
                      children: [
                        ...List.generate(requests.length, (index) {
                          final request = requests[index];
                          final markerSize =
                              request.urgencyLevel == UrgencyLevel.critical
                                  ? 64.0
                                  : 58.0;
                          final position = mapPoint(
                            markerPositions[index],
                            markerSize,
                          );
                          return Positioned(
                            left: position.dx,
                            top: position.dy,
                            child: DiscoveryMarker(
                              request: request,
                              isSelected: selectedRequest?.id == request.id,
                              onTap: () => onRequestSelected(request),
                            ),
                          );
                        }),
                        ...List.generate(donorPoints.length, (index) {
                          final position = mapPoint(donorPoints[index], 48);
                          return Positioned(
                            left: position.dx,
                            top: position.dy,
                            child: DiscoveryMarker.nearbyDonor(
                              delay: 250 + (index * 300),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (isLoading)
              Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: 150,
              child: ActiveRequestsHeader(count: requests.length),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: AnimatedSwitcher(
                duration: AppAnimations.medium,
                switchInCurve: AppAnimations.gentle,
                switchOutCurve: AppAnimations.defaultCurve,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: NearbyRequestCard(
                  key: ValueKey(selectedRequest?.id ?? 'empty-request-card'),
                  request: selectedRequest,
                  onRespond: onRespond,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Offset> _markerPositions(int count) {
    const positions = [
      Offset(0.22, 0.18),
      Offset(0.62, 0.27),
      Offset(0.38, 0.45),
      Offset(0.8, 0.5),
      Offset(0.16, 0.42),
      Offset(0.72, 0.15),
    ];
    return List.generate(count, (index) => positions[index % positions.length]);
  }
}

class DiscoveryMarker extends StatefulWidget {
  const DiscoveryMarker({
    super.key,
    required this.request,
    required this.isSelected,
    required this.onTap,
  })  : isDonor = false,
        delay = 0;

  const DiscoveryMarker.nearbyDonor({super.key, this.delay = 0})
      : request = null,
        isSelected = false,
        isDonor = true,
        onTap = null;

  final BloodRequest? request;
  final bool isSelected;
  final bool isDonor;
  final int delay;
  final VoidCallback? onTap;

  @override
  State<DiscoveryMarker> createState() => _DiscoveryMarkerState();
}

class _DiscoveryMarkerState extends State<DiscoveryMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urgency = widget.request?.urgencyLevel;
    final isCritical = urgency == UrgencyLevel.critical;
    final size = widget.isDonor
        ? 18.0
        : isCritical
            ? 34.0
            : 28.0;
    final color = widget.isDonor
        ? scheme.tertiary
        : urgency == UrgencyLevel.routine
            ? AppColors.warning
            : scheme.primary;

    final marker = AnimatedScale(
      scale: widget.isSelected ? 1.16 : 1,
      duration: AppAnimations.medium,
      curve: AppAnimations.gentle,
      child: SizedBox(
        width: size + 30,
        height: size + 30,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isCritical || widget.isDonor)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final value = Curves.easeOut.transform(_controller.value);
                  return Container(
                    width: size + (28 * value),
                    height: size + (28 * value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.16 * (1 - value)),
                    ),
                  );
                },
              ),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isCritical ? 0.28 : 0.18),
                    blurRadius: isCritical ? 18 : 12,
                    spreadRadius: isCritical ? 3 : 1,
                  ),
                ],
              ),
              child: widget.isDonor
                  ? null
                  : Icon(
                      Icons.water_drop_rounded,
                      color: scheme.onPrimary,
                      size: size * 0.48,
                    ),
            ),
          ],
        ),
      ),
    );

    if (widget.onTap == null) return marker;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: marker,
    );
  }
}

class ActiveRequestsHeader extends StatelessWidget {
  const ActiveRequestsHeader({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleCount = count == 0 ? 0 : math.min(count, 3);

    return AnimatedContainer(
      duration: AppAnimations.medium,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$visibleCount Active Requests Nearby',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            count == 0
                ? 'No matching requests are available around you right now'
                : 'Compatible blood requests within your response area',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class NearbyRequestCard extends StatelessWidget {
  const NearbyRequestCard({
    super.key,
    required this.request,
    required this.onRespond,
  });

  final BloodRequest? request;
  final VoidCallback onRespond;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final request = this.request;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.modal,
      ),
      child: request == null
          ? Row(
              children: [
                Icon(Icons.location_searching_rounded, color: scheme.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Pull to refresh nearby blood requests.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    request.bloodType,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.water_drop_rounded,
                            color: scheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              request.urgencyLevel == UrgencyLevel.critical
                                  ? 'Urgently Needed'
                                  : 'Blood Needed',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        request.hospitalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        request.distanceKm == null
                            ? '${request.unitsNeeded} unit${request.unitsNeeded == 1 ? '' : 's'} needed'
                            : '${request.distanceKm!.toStringAsFixed(1)} km away',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                ElevatedButton(
                  onPressed: onRespond,
                  style: ElevatedButton.styleFrom(
                    elevation: 4,
                    shadowColor: scheme.primary.withValues(alpha: 0.25),
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Respond'),
                ),
              ],
            ),
    );
  }
}

class _DiscoveryGridPainter extends CustomPainter {
  const _DiscoveryGridPainter(this.theme);

  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    const spacing = 34.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final routePaint = Paint()
      ..color = theme.colorScheme.primary.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.2)
      ..cubicTo(
        size.width * 0.36,
        size.height * 0.08,
        size.width * 0.5,
        size.height * 0.42,
        size.width * 0.78,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.92,
        size.height * 0.3,
        size.width * 0.72,
        size.height * 0.72,
        size.width * 0.42,
        size.height * 0.68,
      );
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant _DiscoveryGridPainter oldDelegate) {
    return oldDelegate.theme != theme;
  }
}
