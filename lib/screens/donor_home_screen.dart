import 'dart:async';
import 'dart:math' as math;

import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/providers/notification_provider.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/request_card.dart';
import 'package:bloodconnect/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloodconnect/screens/ai_eligibility_gate.dart';
import 'package:go_router/go_router.dart';

class DonorHomeScreen extends ConsumerStatefulWidget {
  const DonorHomeScreen({super.key});

  @override
  ConsumerState<DonorHomeScreen> createState() => _DonorHomeScreenState();
}

class _DonorHomeScreenState extends ConsumerState<DonorHomeScreen> {
  List<BloodRequest> _matchingRequests = const [];
  BloodRequest? _activeMission;
  UserProfile? _profile;
  int _donations = 0;
  int _points = 0;
  bool _isLoading = true;
  String? _locationWarning;
  UrgencyLevel? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _load() async {
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

      final stats = await donorService.getDonorStats(profile.id);
      final mission = await donorService.getActiveMission(profile.id);

      final pos = await locationService.getCurrentPosition();
      double? lat = pos?.latitude ?? profile.latitude;
      double? lng = pos?.longitude ?? profile.longitude;

      if (pos != null && profile.firebaseUid.isNotEmpty) {
        unawaited(
          ref.read(userServiceProvider).updateLocation(
            firebaseUid: profile.firebaseUid,
            latitude: pos.latitude,
            longitude: pos.longitude,
          ),
        );
      }
      const fallbackLat = 30.0444;
      const fallbackLng = 31.2357;
      final usedFallback = lat == null || lng == null;
      final searchLat = lat ?? fallbackLat;
      final searchLng = lng ?? fallbackLng;

      final matches = await donorService.findMatchingRequests(
        donorId: profile.id,
        donorBloodType: profile.bloodType,
        donorLat: searchLat,
        donorLng: searchLng,
        radiusKm:
            usedFallback ? 300 : math.max(25, profile.notificationRadiusKm),
      );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _donations = stats['totalDonations'] ?? 0;
        _points = stats['rewardPoints'] ?? 0;
        _activeMission = mission;
        _matchingRequests = matches;
        _locationWarning = usedFallback
            ? 'Enable location for more accurate matching.'
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load donor feed.')),
      );
    }
  }

  List<BloodRequest> get _visibleRequests {
    if (_filter == null) return _matchingRequests;
    return _matchingRequests.where((r) => r.urgencyLevel == _filter).toList();
  }

  Future<void> _respond(BloodRequest request, bool accept) async {
    final auth = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);
    final donorService = ref.read(donorServiceProvider);
    final locationService = ref.read(locationServiceProvider);
    final user = auth.currentUser;
    if (user == null) return;
    final profile = await userService.getProfileByFirebaseUid(user.uid);
    if (profile == null) return;

    try {
      if (accept) {
        if (!mounted) return;
        final allowed = await showAiEligibilityGate(context, ref, profile);
        if (!mounted) return;
        if (!allowed) return;
        final pos = await locationService.getCurrentPosition();
        var lat = pos?.latitude ?? profile.latitude;
        var lng = pos?.longitude ?? profile.longitude;
        if (lat == null || lng == null) throw Exception('Location required');
        if (pos != null && profile.firebaseUid.isNotEmpty) {
          unawaited(
            ref.read(userServiceProvider).updateLocation(
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
      } else {
        await donorService.declineRequest(
          requestId: request.id,
          donorId: profile.id,
        );
      }
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.35;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final unreadCountAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadCountAsync.asData?.value ?? 0;

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _load,
        child: _isLoading
            ? _buildSkeleton(heroHeight)
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHero(heroHeight, unreadCount),
                  ),
                  SliverToBoxAdapter(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      child: Container(
                        color: scaffoldBg,
                        child: _buildContent(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHero(double height, int unreadCount) {
    final name = _profile?.name.split(' ').first ?? 'Donor';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final hasProfile = _profile != null;

    return Container(
      height: height,
      decoration: const BoxDecoration(gradient: AppGradients.primary),
      child: Stack(
        children: [
          Positioned(top: -50, right: -40,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(bottom: -20, left: -30,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(top: height * 0.12, right: 16,
            child: Icon(
              Icons.bloodtype,
              size: 100,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '👋',
                                  style: TextStyle(fontSize: 30),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: -2, top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryRed,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hasProfile) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            child: Text(
                              _profile!.name.isNotEmpty
                                  ? _profile!.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.bloodtype,
                          iconColor: AppColors.primaryRed,
                          value: _profile?.bloodType.isNotEmpty == true
                              ? _profile!.bloodType
                              : '--',
                          label: 'Blood Type',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.favorite,
                          iconColor: AppColors.primaryRed,
                          value: '$_donations',
                          label: 'Donations',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.stars_rounded,
                          iconColor: AppColors.warning,
                          value: '$_points',
                          label: 'Points',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        if (_activeMission != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ActiveMissionBanner(
              request: _activeMission!,
              onTap: () => context.push('/donor/mission'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_locationWarning != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _LocationBanner(
              onTap: () => context.push('/profile'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Nearby Requests',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (_matchingRequests.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_visibleRequests.length} found',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _FilterRow(
            selected: _filter,
            onSelect: (f) => setState(() => _filter = f),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _visibleRequests.isEmpty
              ? const _EmptyRequests()
              : Column(
                  children: _visibleRequests.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: RequestCard(
                        request: r,
                        onAccept: () => _respond(r, true),
                        onDecline: () => _respond(r, false),
                      ),
                    ),
                  ).toList(),
                ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSkeleton(double heroHeight) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ShimmerLoading(
          child: Container(
            height: heroHeight,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                const SizedBox(height: 24),
                ...List.generate(3, (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: SkeletonCard(),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveMissionBanner extends StatelessWidget {
  const _ActiveMissionBanner({
    required this.request,
    required this.onTap,
  });

  final BloodRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [AppColors.darkSurfaceCard, AppColors.darkBackground]
                : [
                    const Color(0xFFFFF7ED),
                    const Color(0xFFFFF7ED).withValues(alpha: 0.8),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.flag_outlined,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Mission',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${request.hospitalName} \u2022 ${request.bloodType}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  request.displayCode,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: request.displayCode),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: AppColors.warning.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurfaceCard
            : AppColors.softAmber,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_off_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Location unavailable. Enable for better matching.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.onSelect,
  });

  final UrgencyLevel? selected;
  final ValueChanged<UrgencyLevel?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          _FilterChip(
            label: 'Critical',
            selected: selected == UrgencyLevel.critical,
            onTap: () => onSelect(UrgencyLevel.critical),
          ),
          _FilterChip(
            label: 'Urgent',
            selected: selected == UrgencyLevel.urgent,
            onTap: () => onSelect(UrgencyLevel.urgent),
          ),
          _FilterChip(
            label: 'Routine',
            selected: selected == UrgencyLevel.routine,
            onTap: () => onSelect(UrgencyLevel.routine),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryRed
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.primaryRed
                  : Theme.of(context).dividerColor,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: AppColors.success.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No requests in your area right now',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check back soon.',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
