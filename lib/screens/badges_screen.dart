import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/badge_card.dart';
import 'package:bloodconnect/widgets/section_header.dart';
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
    final profile = await ref
        .read(userServiceProvider)
        .getProfileByFirebaseUid(auth.uid);
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
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
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
                      _PointItem(
                        value: '$_totalPoints',
                        label: 'Total Points',
                        icon: '⭐',
                      ),
                      Container(width: 1, height: 40, color: Colors.white30),
                      _PointItem(
                        value: '${earned.length}',
                        label: 'Badges Earned',
                        icon: '🏅',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (earned.isNotEmpty) ...[
                  const SectionHeader(title: 'Earned'),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: earned
                        .map((b) => BadgeCard(
                              icon: '${b['icon'] ?? '🏅'}',
                              name: '${b['name']}',
                              earned: true,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                if (locked.isNotEmpty) ...[
                  const SectionHeader(title: 'Locked'),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: locked
                        .map((b) => BadgeCard(
                              icon: '${b['icon'] ?? '🏅'}',
                              name: '${b['name']}',
                              earned: false,
                              progress: ((b['current_value'] as int? ?? 0) /
                                      (b['requirement_value'] as int? ?? 1))
                                  .clamp(0.0, 1.0),
                              progressLabel:
                                  '${b['current_value']}/${b['requirement_value']}',
                            ))
                        .toList(),
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
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(icon, style: const TextStyle(fontSize: 24)),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}