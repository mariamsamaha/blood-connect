import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/badge_card.dart';
import 'package:bloodconnect/widgets/empty_state.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:bloodconnect/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BadgesScreen extends ConsumerStatefulWidget {
  const BadgesScreen({super.key});

  @override
  ConsumerState<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends ConsumerState<BadgesScreen> {
  List<Map<String, dynamic>> _badges = [];
  bool _loading = true;
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authServiceProvider).currentUser;
    if (auth == null) return;
    final profile =
        await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
    if (profile == null || !mounted) return;

    final badges =
        await ref.read(userServiceProvider).getAllBadgesWithProgress(profile.id);
    if (!mounted) return;
    setState(() {
      _badges = badges;
      _totalPoints = profile.rewardPoints;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final earned = _badges.where((b) => b['is_earned'] == true).toList();
    final locked = _badges.where((b) => b['is_earned'] != true).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Badges & Rewards')),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const ShimmerLoading(
                  child: SizedBox(
                    height: 100,
                    child: Card(),
                  ),
                ),
                const SizedBox(height: 24),
                const ShimmerLoading(child: SectionHeader(title: 'Earned')),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(3, (_) => const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: ShimmerLoading(
                        child: SizedBox(
                          height: 100,
                          child: Card(),
                        ),
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 24),
                const ShimmerLoading(child: SectionHeader(title: 'Locked')),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(3, (_) => const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: ShimmerLoading(
                        child: SizedBox(
                          height: 100,
                          child: Card(),
                        ),
                      ),
                    ),
                  )),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
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
                      _PointItem(
                        value: '$_totalPoints',
                        label: 'Total Points',
                        icon: Icons.star_rounded,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white30,
                      ),
                      _PointItem(
                        value: '${earned.length}',
                        label: 'Badges Earned',
                        icon: Icons.emoji_events_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (earned.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Earned',
                    showDivider: true,
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: earned
                        .map(
                          (b) => BadgeCard(
                            icon: '${b['icon'] ?? '\u{1F3C6}'}',
                            name: '${b['name']}',
                            earned: true,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  const EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: 'No badges earned yet',
                    subtitle: 'Complete donations to earn badges!',
                  ),
                  const SizedBox(height: 24),
                ],
                if (locked.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Locked',
                    showDivider: true,
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: locked
                        .map(
                          (b) => BadgeCard(
                            icon: '${b['icon'] ?? '\u{1F3C6}'}',
                            name: '${b['name']}',
                            earned: false,
                            progress: (_parseInt(b['current_value']) /
                                    _parseInt(b['requirement_value'], fallback: 1))
                                .clamp(0.0, 1.0),
                            progressLabel:
                                '${b['current_value']}/${b['requirement_value']}',
                          ),
                        )
                        .toList(),
                  ),
                ] else ...[
                  const EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'No badges to unlock',
                    subtitle: 'Donate to discover available badges!',
                  ),
                ],
              ],
            ),
    );
  }
}

class _PointItem extends StatelessWidget {
  const _PointItem({
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
          child: Icon(icon, color: Colors.white70, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
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

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
