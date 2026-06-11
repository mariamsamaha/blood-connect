import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/blood_type_chip.dart';
import 'package:bloodconnect/widgets/empty_state.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:bloodconnect/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() =>
      _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List<Map<String, dynamic>> _leaders = [];
  int? _myRank;
  int? _myPoints;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider).currentUser;
      if (auth == null) return;
      final profile =
          await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
      if (profile == null || !mounted) return;

      final donors = ref.read(donorServiceProvider);
      final results = await Future.wait([
        donors.getLeaderboard(),
        donors.getMyRank(profile.id),
      ]);

      if (!mounted) return;
      setState(() {
        _leaders = results[0] as List<Map<String, dynamic>>;
        _myRank = results[1] as int?;
        _myPoints = profile.rewardPoints;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const ShimmerLoading(
                  child: SizedBox(
                    height: 120,
                    child: Card(),
                  ),
                ),
                const SizedBox(height: 24),
                const ShimmerLoading(child: SectionHeader(title: 'Top Donors')),
                const SizedBox(height: 12),
                ...List.generate(5, (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: SkeletonListItem(),
                )),
              ],
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_myRank != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.primary,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            value: '#$_myRank',
                            label: 'Your Rank',
                            icon: Icons.emoji_events_rounded,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white30,
                          ),
                          _StatItem(
                            value: '$_myPoints',
                            label: 'Your Points',
                            icon: Icons.star_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  SectionHeader(
                    title: 'Top Donors',
                    showDivider: true,
                  ),
                  const SizedBox(height: 12),

                  if (_leaders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: EmptyState(
                        icon: Icons.people_outline,
                        title: 'No donors yet',
                        subtitle: 'Be the first to donate and earn points!',
                      ),
                    )
                  else
                    ..._leaders.asMap().entries.map((entry) {
                      final index = entry.key;
                      final d = entry.value;
                      final rawRank = d['rank'];
                      final rank = rawRank is int
                          ? rawRank
                          : int.tryParse(rawRank?.toString() ?? '') ?? (index + 1);

                      final rawDonations = d['total_donations'];
                      final donations = rawDonations is int
                          ? rawDonations
                          : int.tryParse(rawDonations?.toString() ?? '') ?? 0;

                      final rawPoints = d['reward_points'];
                      final points = rawPoints is int
                          ? rawPoints
                          : int.tryParse(rawPoints?.toString() ?? '') ?? 0;

                      return _LeaderCard(
                        rank: rank,
                        name: '${d['name']}',
                        bloodType: '${d['blood_type']}',
                        donations: donations,
                        points: points,
                      );
                    }),

                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Updates after each verified donation',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({
    required this.rank,
    required this.name,
    required this.bloodType,
    required this.donations,
    required this.points,
  });

  final int rank;
  final String name;
  final String bloodType;
  final int donations;
  final int points;

  @override
  Widget build(BuildContext context) {
    final (medal, bg, borderColor, shadow) = switch (rank) {
      1 => ('\u{1F947}', const Color(0xFFFFF8E1), AppColors.gold, AppShadows.glowGold),
      2 => ('\u{1F948}', const Color(0xFFF5F5F5), AppColors.textTertiary, null),
      3 => ('\u{1F949}', const Color(0xFFFBE9E7), AppColors.primaryRed.withValues(alpha: 0.3), null),
      _ => ('', Colors.transparent, AppColors.divider, null),
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppAnimations.medium,
      curve: AppAnimations.smooth,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: rank <= 3 ? bg : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: borderColor,
            width: rank <= 3 ? 1.5 : 1,
          ),
          boxShadow: shadow,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: rank <= 3
                  ? Text(
                      medal,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22),
                    )
                  : Text(
                      '#$rank',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            BloodTypeChip(
              type: bloodType,
              selected: false,
              onTap: null,
              compact: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$donations donation${donations == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: rank == 1
                    ? LinearGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.15),
                          AppColors.gold.withValues(alpha: 0.05),
                        ],
                      )
                    : null,
                color: rank == 1 ? null : AppColors.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: rank == 1
                    ? Border.all(color: AppColors.gold.withValues(alpha: 0.3))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rank == 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.star_rounded, size: 12, color: AppColors.gold),
                    ),
                  Text(
                    '$points pts',
                    style: TextStyle(
                      color: rank == 1 ? AppColors.gold : AppColors.primaryRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
