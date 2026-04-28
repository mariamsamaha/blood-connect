import 'dart:math' as math;

import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/request_card.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Widget structure:
/// - Scaffold
///   - RefreshIndicator
///     - CustomScrollView
///       - Greeting gradient card (name, blood type, stats)
///       - Optional active mission card with pulse + copy code
///       - Optional location warning banner
///       - Nearby requests section header + filter chips
///       - Request cards list or empty state
///   - BottomNavigationBar (Home, Profile)
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

      double? lat = profile.latitude;
      double? lng = profile.longitude;
      if (lat == null || lng == null) {
        final pos = await locationService.getCurrentPosition();
        lat = pos?.latitude;
        lng = pos?.longitude;
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
        radiusKm: usedFallback ? 300 : math.max(100, profile.notificationRadiusKm),
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
        var lat = profile.latitude;
        var lng = profile.longitude;
        if (lat == null || lng == null) {
          final pos = await locationService.getCurrentPosition();
          lat = pos?.latitude;
          lng = pos?.longitude;
        }
        if (lat == null || lng == null) throw Exception('Location required');
        await donorService.acceptRequest(
          requestId: request.id,
          donorId: profile.id,
          donorLat: lat,
          donorLng: lng,
        );
      } else {
        await donorService.declineRequest(requestId: request.id, donorId: profile.id);
      }
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _load,
        child: _isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppTheme.pagePadding,
                children: const [SizedBox(height: 380)],
              )
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GreetingCard(profile: _profile, donations: _donations, points: _points),
                          if (_activeMission != null) ...[
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => context.push('/donor/mission'),
                              child: _MissionCard(request: _activeMission!),
                            ),
                          ],
                          if (_locationWarning != null) ...[
                            const SizedBox(height: 12),
                            _LocationBanner(onTap: () => context.push('/profile')),
                          ],
                          const SizedBox(height: 24),
                          const SectionHeader(title: 'Nearby Requests'),
                          const SizedBox(height: 12),
                          _FilterRow(selected: _filter, onSelect: (f) => setState(() => _filter = f)),
                          const SizedBox(height: 16),
                          if (_visibleRequests.isEmpty)
                            const _EmptyRequests()
                          else
                            ..._visibleRequests.map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
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
          if (index == 1) context.go('/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.profile, required this.donations, required this.points});
  final UserProfile? profile;
  final int donations;
  final int points;
  @override
  Widget build(BuildContext context) {
    final name = profile?.name.split(' ').first ?? 'Donor';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [AppColors.primaryRed, AppColors.deepRed]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Good morning, $name 👋', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Pill(text: profile?.bloodType.isEmpty ?? true ? 'Unknown' : profile!.bloodType),
          _Pill(text: '🩸 $donations Donations'),
          _Pill(text: '⭐ $points Points'),
        ]),
      ]),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.request});
  final BloodRequest request;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6ED),
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Active Mission', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('${request.hospitalName} • ${request.bloodType}'),
        const SizedBox(height: 8),
        Row(children: [
          Text(request.displayCode, style: const TextStyle(fontFamily: 'monospace', fontSize: 28, fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: request.displayCode)),
            icon: const Icon(Icons.copy_rounded),
          ),
        ]),
      ]),
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
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.location_off_rounded, color: AppColors.warning),
        const SizedBox(width: 8),
        const Expanded(child: Text('Location unavailable. Enable Location for better matching.')),
        TextButton(onPressed: onTap, child: const Text('Enable')),
      ]),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelect});
  final UrgencyLevel? selected;
  final ValueChanged<UrgencyLevel?> onSelect;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _FilterChip(label: 'All', selected: selected == null, onTap: () => onSelect(null)),
        _FilterChip(label: 'Critical', selected: selected == UrgencyLevel.critical, onTap: () => onSelect(UrgencyLevel.critical)),
        _FilterChip(label: 'Urgent', selected: selected == UrgencyLevel.urgent, onTap: () => onSelect(UrgencyLevel.urgent)),
        _FilterChip(label: 'Routine', selected: selected == UrgencyLevel.routine, onTap: () => onSelect(UrgencyLevel.routine)),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: const Column(children: [
        Icon(Icons.hourglass_empty_rounded, size: 44),
        SizedBox(height: 10),
        Text('No requests in your area right now.'),
        SizedBox(height: 4),
        Text('Check back soon.', style: TextStyle(color: AppColors.textSecondary)),
      ]),
    );
  }
}

