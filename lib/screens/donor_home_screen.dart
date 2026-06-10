import 'dart:async';
import 'dart:math' as math;

import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/request_card.dart';
import 'package:bloodconnect/widgets/section_header.dart';
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
        // ── AI eligibility gate ───────────────────────────────────────────
        if (!mounted) return;
        final allowed = await showAiEligibilityGate(context, ref, profile);
        if (!mounted) return;
        if (!allowed) return;
        // ── proceed with accept ───────────────────────────────────────────
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
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _load,
        child: _isLoading
            ? _buildSkeleton()
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GreetingCard(
                            profile: _profile,
                            donations: _donations,
                            points: _points,
                            notificationCount: _matchingRequests.length,
                          ),
                          const SizedBox(height: 14),
                          _buildAiCard(),
                          const SizedBox(height: 14),
                          _buildStoriesCard(),
                          const SizedBox(height: 14),
                          _buildCouponsCard(),
                          if (_activeMission != null) ...[
                            const SizedBox(height: 14),
                            _ActiveMissionBanner(
                              request: _activeMission!,
                              onTap: () => context.push('/donor/mission'),
                            ),
                          ],
                          if (_locationWarning != null) ...[
                            const SizedBox(height: 12),
                            _LocationBanner(
                              onTap: () => context.push('/profile'),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(
                                child: SectionHeader(title: 'Nearby Requests'),
                              ),
                              if (_matchingRequests.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.full,
                                    ),
                                  ),
                                  child: Text(
                                    '${_visibleRequests.length} found',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryRed,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _FilterRow(
                            selected: _filter,
                            onSelect: (f) => setState(() => _filter = f),
                          ),
                          const SizedBox(height: 16),
                          if (_visibleRequests.isEmpty)
                            const _EmptyRequests()
                          else
                            ..._visibleRequests.map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: RequestCard(
                                  request: r,
                                  onAccept: () => _respond(r, true),
                                  onDecline: () => _respond(r, false),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) context.go('/stories');
          if (index == 2) context.go('/profile');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_rounded),
            label: 'Stories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const ShimmerLoading(
          child: _GreetingCard(
            profile: null,
            donations: 0,
            points: 0,
            notificationCount: 0,
          ),
        ),
        const SizedBox(height: 14),
        const ShimmerLoading(
          child: SizedBox(
            height: 60,
            child: Card(),
          ),
        ),
        const SizedBox(height: 24),
        const ShimmerLoading(
          child: SectionHeader(title: 'Nearby Requests'),
        ),
        const SizedBox(height: 12),
        ...List.generate(3, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: SkeletonCard(),
        )),
      ],
    );
  }

  Widget _buildAiCard() {
    return GestureDetector(
      onTap: () => context.push('/ai-check'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.primaryRed.withValues(alpha: 0.15),
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Know Before You Give',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryRed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Check your eligibility with AI',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesCard() {
    return GestureDetector(
      onTap: () => context.push('/stories'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.primaryRed.withValues(alpha: 0.15),
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.primaryRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Donor Stories',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryRed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Read inspiring stories from our community',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponsCard() {
    return GestureDetector(
      onTap: () => context.push('/coupons'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.15),
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rewards Shop',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Redeem points for exciting coupons & discounts',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({
    required this.profile,
    required this.donations,
    required this.points,
    required this.notificationCount,
  });

  final UserProfile? profile;
  final int donations;
  final int points;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    final name = profile?.name.split(' ').first ?? 'Donor';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final hasProfile = profile != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: AppGradients.primary,
        boxShadow: AppShadows.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$greeting, $name',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => context.push('/notifications'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.notifications_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      if (notificationCount > 0)
                        Positioned(
                          right: -4,
                          top: -4,
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
                              '$notificationCount',
                              style: const TextStyle(
                                color: AppColors.primaryRed,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (hasProfile)
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
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      profile!.name.isNotEmpty
                          ? profile!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                text: profile?.bloodType.isNotEmpty == true
                    ? profile!.bloodType
                    : 'Unknown',
              ),
              _Pill(text: '$donations Donations'),
              _Pill(text: '$points Points'),
            ],
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
                borderRadius: BorderRadius.circular(AppRadius.sm),
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
        borderRadius: BorderRadius.circular(AppRadius.md),
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
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primaryRed.withValues(alpha: 0.15),
        backgroundColor: Theme.of(context).cardColor,
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryRed : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(
          color: selected
              ? AppColors.primaryRed.withValues(alpha: 0.3)
              : Theme.of(context).dividerColor,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
