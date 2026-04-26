import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/theme/app_theme.dart';
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
    final profile = await ref
        .read(userServiceProvider)
        .getProfileByFirebaseUid(auth.uid);
    if (profile == null || !mounted) return;

    final history = await ref
        .read(donorServiceProvider)
        .getFullDonationHistory(profile.id);
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
      (sum, h) => sum + (h['points_earned'] as int? ?? 0),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Donation History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 64, color: AppColors.divider),
                      SizedBox(height: 12),
                      Text('No donations yet'),
                      SizedBox(height: 4),
                      Text(
                        'Accept a blood request to get started',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
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
                          _SummaryItem(
                            value: '${_history.length}',
                            label: 'Donations',
                          ),
                          Container(
                            width: 1, height: 40,
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
                          ? DateFormat('MMM d, yyyy').format(
                              DateTime.parse(h['donation_date'].toString()))
                          : 'Unknown date';
                      final points = h['points_earned'] as int? ?? 10;
                      final urgency = h['urgency_level'] as String? ?? 'routine';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${h['blood_type']}',
                                style: const TextStyle(
                                  color: AppColors.primaryRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
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
                                  const SizedBox(height: 4),
                                  UrgencyBadge(
                                    level: UrgencyLevel.values.firstWhere(
                                      (u) => u.name == urgency,
                                      orElse: () => UrgencyLevel.routine,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withAlpha(25),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: Colors.amber.withAlpha(77),
                                ),
                              ),
                              child: Text(
                                '+$points pts',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ]),
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
    return Column(children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white70)),
    ]);
  }
}