import 'dart:async';

import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/providers/notification_provider.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:bloodconnect/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RecipientHomeScreen extends ConsumerStatefulWidget {
  const RecipientHomeScreen({super.key});
  @override
  ConsumerState<RecipientHomeScreen> createState() =>
      _RecipientHomeScreenState();
}

class _RecipientHomeScreenState extends ConsumerState<RecipientHomeScreen> {
  BloodRequest? _active;
  List<BloodRequest> _history = const [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _active != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final requestService = ref.read(requestServiceProvider);
      final user = auth.currentUser;
      if (user == null) return;
      final profile = await userService.getProfileByFirebaseUid(user.uid);
      if (profile == null) return;
      final active = await requestService.getActiveRequest(profile.id);
      final all = await requestService.getMyRequests(profile.id);
      if (!mounted) return;
      setState(() {
        _active = active;
        _history =
            all.where((e) => active == null || e.id != active.id).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    final r = _active;
    if (r == null) return;
    final auth = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);
    final requestService = ref.read(requestServiceProvider);
    final user = auth.currentUser;
    if (user == null) return;
    final profile = await userService.getProfileByFirebaseUid(user.uid);
    if (profile == null) return;
    final ok = await requestService.cancelRequest(r.id, profile.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Request cancelled' : 'Unable to cancel request'),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadCountNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('BloodConnect'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications'),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _load,
        child: _loading
            ? _buildSkeleton()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (_active == null) ...[
                    _HeroCreateCard(
                      onCreate: () => context.push('/create-request'),
                    ),
                    const SizedBox(height: 24),
                    const _HowItWorks(),
                  ] else ...[
                    _ActiveRequestCard(
                      request: _active!,
                      onCancel: _cancel,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildStoriesCard(),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Request History'),
                  const SizedBox(height: 12),
                  if (_history.isEmpty)
                    const _HistoryEmpty()
                  else
                    ..._history.map((r) => _HistoryItem(request: r)),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) context.go('/profile');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const ShimmerLoading(
          child: SizedBox(
            height: 160,
            child: Card(),
          ),
        ),
        const SizedBox(height: 24),
        const ShimmerLoading(
          child: SectionHeader(title: 'Request History'),
        ),
        const SizedBox(height: 12),
        ...List.generate(3, (_) => const ShimmerLoading(
          child: Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: SkeletonListItem(),
          ),
        )),
      ],
    );
  }

  Widget _buildStoriesCard() {
    return GestureDetector(
      onTap: () => context.push('/stories'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
}

class _HeroCreateCard extends StatelessWidget {
  const _HeroCreateCard({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: AppGradients.primary,
        boxShadow: AppShadows.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.bloodtype_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'Need Blood?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create an urgent request and notify compatible donors near you.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Create Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryRed,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.info_outline, size: 18, color: AppColors.primaryRed),
              ),
              const SizedBox(width: 10),
              Text(
                'How it works',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Step(
            icon: Icons.edit_note_rounded,
            iconColor: AppColors.primaryRed,
            title: '1. Post a request',
            subtitle: 'Select blood type, quantity and hospital',
          ),
          const SizedBox(height: 12),
          _Step(
            icon: Icons.travel_explore_rounded,
            iconColor: AppColors.info,
            title: '2. Match nearby donors',
            subtitle: 'Compatible donors near you get notified instantly',
          ),
          const SizedBox(height: 12),
          _Step(
            icon: Icons.verified_rounded,
            iconColor: AppColors.success,
            title: '3. Hospital verifies',
            subtitle: 'Donation confirmed with a secure 4-digit code',
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveRequestCard extends StatelessWidget {
  const _ActiveRequestCard({
    required this.request,
    required this.onCancel,
  });

  final BloodRequest request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final seconds =
        request.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999999);
    final hh = (seconds ~/ 3600).toString().padLeft(2, '0');
    final mm = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    final progress = request.status == RequestStatus.active ? 0.45 : 0.85;
    final isFinding = request.status == RequestStatus.active;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.bloodtype_rounded,
                  color: AppColors.primaryRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request ${request.shortId}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      isFinding ? 'Finding Donors' : 'Donor Accepted',
                      style: TextStyle(
                        color: isFinding
                            ? AppColors.warning
                            : AppColors.success,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _DetailChip(
                icon: Icons.local_hospital_outlined,
                label: request.hospitalName,
              ),
              const SizedBox(width: 8),
              _DetailChip(
                icon: Icons.bloodtype_outlined,
                label: request.bloodType,
              ),
              const SizedBox(width: 8),
              _DetailChip(
                icon: Icons.inventory_2_outlined,
                label: '${request.unitsNeeded} units',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                isFinding ? AppColors.warning : AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: seconds < 3600
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: AppAnimations.fast,
                style: TextStyle(
                  color: seconds < 3600
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontWeight:
                      seconds < 3600 ? FontWeight.w600 : FontWeight.normal,
                ),
                child: Text('Expires in $hh:$mm:$ss'),
              ),
            ],
          ),
          if (request.status == RequestStatus.in_progress) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_car_rounded,
                    size: 18,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Donor is on the way to hospital',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppButton.secondary(
            label: 'Cancel Request',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.request});
  final BloodRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.bloodtype_rounded,
              size: 18,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.shortId,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  request.hospitalName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: request.status == RequestStatus.fulfilled
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              request.status.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: request.status == RequestStatus.fulfilled
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 40,
            color: AppColors.textTertiary,
          ),
          SizedBox(height: 8),
          Text(
            'No previous requests yet',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
