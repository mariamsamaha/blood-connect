import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/blood_type_chip.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
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
      final profile = await ref
          .read(userServiceProvider)
          .getProfileByFirebaseUid(auth.uid);
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
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_myRank != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryRed, AppColors.deepRed],
                        ),
                        borderRadius: BorderRadius.circular(16),
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
                              width: 1, height: 40, color: Colors.white30),
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

                  const SectionHeader(title: 'Top Donors'),
                  const SizedBox(height: 12),

                  if (_leaders.isEmpty)
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline,
                              size: 48, color: AppColors.divider),
                          SizedBox(height: 8),
                          Text('No donors yet'),
                        ],
                      ),
                    )
                  else
                    ..._leaders.asMap().entries.map((entry) {
                      final index = entry.key;
                      final d = entry.value;
                      final rank = d['rank'] as int? ?? index + 1;
                      return _LeaderCard(
                        rank: rank,
                        name: '${d['name']}',
                        bloodType: '${d['blood_type']}',
                        donations: d['total_donations'] as int? ?? 0,
                        points: d['reward_points'] as int? ?? 0,
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
    return Column(children: [
      Icon(icon, color: Colors.white70, size: 20),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
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
    final (medal, bg) = switch (rank) {
      1 => ('🥇', const Color(0xFFFFF8E1)),
      2 => ('🥈', const Color(0xFFF5F5F5)),
      3 => ('🥉', const Color(0xFFFBE9E7)),
      _ => ('', Colors.transparent),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: rank <= 3
            ? bg
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rank <= 3
              ? AppColors.primaryRed.withAlpha(51)
              : AppColors.divider,
        ),
      ),
      child: Row(children: [
        SizedBox(
          width: 36,
          child: rank <= 3
              ? Text(medal, style: const TextStyle(fontSize: 22))
              : Text(
                  '#$rank',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        BloodTypeChip(type: bloodType, selected: false, onTap: null),
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
            color: AppColors.primaryRed.withAlpha(25),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$points pts',
            style: const TextStyle(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ]),
    );
  }
}