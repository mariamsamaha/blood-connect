import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/donor_response_entry.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/blood_type_wheel.dart';
import 'package:bloodconnect/widgets/badge_card.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:bloodconnect/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  List<Map<String, dynamic>> _badges = const [];
  List<DonorResponseEntry> _history = const [];
  List<BloodRequest> _requestHistory = const [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = ref.read(authServiceProvider).currentUser;
    if (auth == null) return;
    final userService = ref.read(userServiceProvider);
    final donorService = ref.read(donorServiceProvider);
    final requestService = ref.read(requestServiceProvider);
    final p = await userService.getProfileByFirebaseUid(auth.uid);
    if (p == null) return;
    final badges = await userService.getAllBadgesWithProgress(p.id);
    final history = await donorService.getDonorResponseHistory(p.id);
    List<BloodRequest> reqHistory = const [];
    if (p.role == UserRole.recipient) {
      reqHistory = await requestService.getMyRequests(p.id);
    }
    if (!mounted) return;
    setState(() {
      _profile = p;
      _badges = badges;
      _history = history;
      _requestHistory = reqHistory;
      _loading = false;
    });
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null || _loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (_profile != null) {
              context.go(_profile!.homeRoute);
            } else {
              if (context.canPop()) {
                context.pop();
              }
            }
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _ProfileHead(profile: profile),
            const SizedBox(height: 16),
            if (profile.bloodType.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: AppShadows.card,
                ),
                child: Center(
                  child: BloodTypeWheel(
                    selectedType: profile.bloodType,
                    size: 220,
                    direction: CompatibilityDirection.selectedCanDonateTo,
                    label: '${profile.bloodType} can donate to',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (profile.role == UserRole.donor) ...[
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Donations',
                      value: '${profile.totalDonations}',
                      icon: Icons.volunteer_activism_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/coupons'),
                      child: StatCard(
                        title: 'Points',
                        value: '${profile.rewardPoints}',
                        icon: Icons.star_rounded,
                        color: AppColors.warning,
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: AppShadows.card,
                    ),
                    child: IconButton(
                      onPressed: () => context.push('/leaderboard'),
                      icon: const Icon(Icons.leaderboard_rounded),
                      tooltip: 'Leaderboard',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: SectionHeader(title: 'Badges'),
                  ),
                  if (_badges.isNotEmpty)
                    TextButton(
                      onPressed: () => context.push('/badges'),
                      child: const Text('See All'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_badges.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (_, i) {
                      final b = _badges[i];
                      final earned = b['is_earned'] as bool? ?? false;
                      return SizedBox(
                        width: 90,
                        child: BadgeCard(
                          icon: '${b['icon'] ?? '🏆'}',
                          name: '${b['name'] ?? 'Badge'}',
                          earned: earned,
                          progress: earned
                              ? 1.0
                              : (_parseInt(b['current_value']) /
                                      _parseInt(b['requirement_value'], fallback: 1))
                                  .clamp(0.0, 1.0),
                          progressLabel: earned
                              ? 'Earned'
                              : '${b['current_value']}/${b['requirement_value']}',
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: _badges.length,
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: SectionHeader(title: 'Donation History'),
                  ),
                  if (_history.isNotEmpty)
                    TextButton(
                      onPressed: () => context.push('/donation-history'),
                      child: const Text('See All'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_history.isNotEmpty)
                ..._history.take(5).map(
                      (h) => _HistoryTile(
                        name: h.hospitalName,
                        bloodType: h.bloodType,
                        type: h.responseType,
                        date: h.respondedAt,
                      ),
                    ),
              if (_history.isEmpty)
                _EmptySection(
                  icon: Icons.history_rounded,
                  message: 'No donation history yet',
                ),
              const SizedBox(height: 20),
              StatCard(
                title: 'Member Since',
                value: '2026',
                icon: Icons.calendar_month_rounded,
                color: AppColors.info,
              ),
            ] else if (profile.role == UserRole.recipient) ...[
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Total Requests',
                      value: '${_requestHistory.length}',
                      icon: Icons.bloodtype_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'Fulfilled',
                      value: '${_requestHistory.where((r) => r.status == RequestStatus.fulfilled).length}',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'Member Since',
                      value: '2026',
                      icon: Icons.calendar_month_rounded,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: SectionHeader(title: 'Request History'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_requestHistory.isEmpty)
                _EmptySection(
                  icon: Icons.history_rounded,
                  message: 'No previous requests yet',
                )
              else
                ..._requestHistory.map((r) => _RecipientHistoryItem(request: r)),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Verified',
                      value: '${profile.totalDonations}',
                      icon: Icons.verified_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'Member Since',
                      value: '2026',
                      icon: Icons.calendar_month_rounded,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            AppButton.secondary(
              label: 'Sign Out',
              onPressed: _signOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.name,
    required this.bloodType,
    required this.type,
    required this.date,
  });

  final String name;
  final String bloodType;
  final String type;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '$bloodType \u2022 $type',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${date.day}/${date.month}/${date.year}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientHistoryItem extends StatelessWidget {
  const _RecipientHistoryItem({required this.request});
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

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textTertiary),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProfileHead extends StatelessWidget {
  const _ProfileHead({required this.profile});
  final UserProfile profile;

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
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryRed,
                width: 2.5,
              ),
              boxShadow: AppShadows.glowRed,
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryRed.withValues(alpha: 0.1),
              child: Text(
                profile.name.isEmpty
                    ? '?'
                    : profile.name[0].toUpperCase(),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.primaryRed,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          if (profile.phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone_rounded, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    profile.phone,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          if (profile.cityArea.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    profile.cityArea,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  profile.bloodType.isEmpty ? 'Unknown' : profile.bloodType,
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  profile.role.name,
                  style: const TextStyle(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

