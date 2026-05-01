import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/donor_response_entry.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/badge_card.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:bloodconnect/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Widget structure:
/// - Scaffold + refresh
/// - Top profile card with blood-type ring
/// - Stats row
/// - Badges horizontal list
/// - Donation history timeline / empty state
/// - Settings
/// - Sign out button
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  List<Map<String, dynamic>> _badges = const [];
  List<DonorResponseEntry> _history = const [];
  bool _loading = true;
  bool _notify = true;

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
    final p = await userService.getProfileByFirebaseUid(auth.uid);
    if (p == null) return;
    final badges = await userService.getAllBadgesWithProgress(p.id);
    final history = await donorService.getDonorResponseHistory(p.id);
    if (!mounted) return;
    setState(() {
      _profile = p;
      _badges = badges;
      _history = history;
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _ProfileHead(profile: profile),
                  const SizedBox(height: 16),
                  if (profile.role == UserRole.donor) ...[
                    Row(children: [
                      Expanded(child: StatCard(title: 'Donations', value: '${profile.totalDonations}', icon: Icons.volunteer_activism_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(title: 'Points', value: '${profile.rewardPoints}', icon: Icons.star_rounded)),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => context.push('/leaderboard'),
                        icon: const Icon(Icons.leaderboard_rounded),
                        tooltip: 'Leaderboard',
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Row(children: [
                      const Expanded(child: SectionHeader(title: 'Badges')),
                      TextButton(
                        onPressed: () => context.push('/badges'),
                        child: const Text('See All'),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, i) {
                          final b = _badges[i];
                          final earned = b['is_earned'] as bool? ?? false;
                          return BadgeCard(
                            icon: '${b['icon'] ?? '🏅'}',
                            name: '${b['name'] ?? 'Badge'}',
                            earned: earned,
                            progress: earned
                                ? 1.0
                                : ((b['current_value'] as int? ?? 0) /
                                    (b['requirement_value'] as int? ?? 1))
                                        .clamp(0.0, 1.0),
                            progressLabel: earned
                                ? 'Earned'
                                : '${b['current_value']}/${b['requirement_value']}',
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemCount: _badges.length,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      const Expanded(child: SectionHeader(title: 'Donation History')),
                      TextButton(
                        onPressed: () => context.push('/donation-history'),
                        child: const Text('See All'),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (_history.isNotEmpty)
                      ..._history.take(5).map((h) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(child: Icon(Icons.bloodtype_rounded)),
                            title: Text(h.hospitalName),
                            subtitle: Text('${h.bloodType} • ${h.responseType}'),
                            trailing: Text(_formatDate(h.respondedAt)),
                          )),
                    if (_history.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                        child: const Column(children: [Icon(Icons.history_rounded), SizedBox(height: 8), Text('No donation history yet')]),
                      ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: StatCard(title: 'Member Since', value: '2026', icon: Icons.calendar_month_rounded)),
                    ]),
                  ] else if (profile.role == UserRole.recipient) ...[
                    Row(children: [
                      Expanded(child: StatCard(title: 'Requests', value: '${profile.totalDonations}', icon: Icons.bloodtype_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(title: 'Member Since', value: '2026', icon: Icons.calendar_month_rounded)),
                    ]),
                  ] else ...[
                    Row(children: [
                      Expanded(child: StatCard(title: 'Verified', value: '${profile.totalDonations}', icon: Icons.verified_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(title: 'Member Since', value: '2026', icon: Icons.calendar_month_rounded)),
                    ]),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Settings'),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Expanded(child: Text('Notifications')),
                        Switch(value: _notify, onChanged: (v) => setState(() => _notify = v)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  AppButton.secondary(label: 'Sign Out', onPressed: _signOut),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ProfileHead extends StatelessWidget {
  const _ProfileHead({required this.profile});
  final UserProfile profile;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primaryRed, width: 2)),
          child: CircleAvatar(radius: 36, child: Text(profile.name.isEmpty ? '?' : profile.name[0].toUpperCase())),
        ),
        const SizedBox(height: 8),
        Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
        Text(profile.email, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          Chip(label: Text(profile.bloodType.isEmpty ? 'Unknown' : profile.bloodType)),
          Chip(label: Text(profile.role.name)),
        ]),
      ]),
    );
  }
}

