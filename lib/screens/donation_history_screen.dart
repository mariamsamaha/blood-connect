import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/empty_state.dart';
import 'package:bloodconnect/widgets/shimmer_loading.dart';
import 'package:bloodconnect/widgets/urgency_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DonationHistoryScreen extends ConsumerStatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  ConsumerState<DonationHistoryScreen> createState() =>
      _DonationHistoryScreenState();
}

class _DonationHistoryScreenState
    extends ConsumerState<DonationHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

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

    final history =
        await ref.read(donorServiceProvider).getFullDonationHistory(profile.id);
    if (!mounted) return;
    setState(() {
      _history = history;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPoints = _history.fold<int>(
      0,
      (sum, h) {
        final val = h['points_earned'];
        final pts = val is int
            ? val
            : int.tryParse(val?.toString() ?? '') ?? 0;
        return sum + pts;
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Donation History')),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const ShimmerLoading(
                  child: SizedBox(height: 100, child: Card()),
                ),
                const SizedBox(height: 24),
                ...List.generate(4, (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonListItem(),
                )),
              ],
            )
          : _history.isEmpty
              ? const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No donations yet',
                  subtitle: 'Accept a blood request to get started',
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
                          _SummaryItem(
                            value: '${_history.length}',
                            label: 'Donations',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white30,
                          ),
                          _SummaryItem(
                            value: '$totalPoints',
                            label: 'Points Earned',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ..._history.map((h) {
                      final date = h['donation_date'] != null
                          ? DateFormat('MMM d, yyyy')
                              .format(
                                DateTime.parse(h['donation_date'].toString()),
                              )
                          : 'Unknown date';
                      final rawPoints = h['points_earned'];
                      final points = rawPoints is int
                          ? rawPoints
                          : int.tryParse(rawPoints?.toString() ?? '') ?? 10;
                      final urgency =
                          h['urgency_level'] as String? ?? 'routine';

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: AppAnimations.medium,
                        curve: AppAnimations.smooth,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: AppShadows.card,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryRed
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${h['blood_type']}',
                                  style: const TextStyle(
                                    color: AppColors.primaryRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${h['hospital_name']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      date,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    UrgencyBadge(
                                      level: UrgencyLevel.values.firstWhere(
                                        (u) => u.name == urgency,
                                        orElse: () => UrgencyLevel.routine,
                                      ),
                                      size: BadgeSize.sm,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.warning.withValues(alpha: 0.1),
                                      AppColors.warning.withValues(alpha: 0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                  border: Border.all(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '+$points pts',
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
