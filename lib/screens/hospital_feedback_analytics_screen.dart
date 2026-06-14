import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/donor_feedback.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/empty_state.dart';
import 'package:bloodconnect/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HospitalFeedbackAnalyticsScreen extends ConsumerStatefulWidget {
  final String hospitalId;
  const HospitalFeedbackAnalyticsScreen({super.key, required this.hospitalId});

  @override
  ConsumerState<HospitalFeedbackAnalyticsScreen> createState() =>
      _HospitalFeedbackAnalyticsScreenState();
}

class _HospitalFeedbackAnalyticsScreenState
    extends ConsumerState<HospitalFeedbackAnalyticsScreen> {
  HospitalFeedbackAnalytics? _analytics;
  List<Map<String, dynamic>> _feedbacks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await ref.read(feedbackServiceProvider)
          .getHospitalFeedback(widget.hospitalId);
      if (!mounted) return;
      setState(() {
        _analytics = HospitalFeedbackAnalytics.fromJson(
            result['analytics'] as Map<String, dynamic>? ?? {});
        _feedbacks = (result['feedbacks'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback & Ratings')),
      body: _loading
          ? const ShimmerLoading(
              child: SizedBox(height: 400, child: Card()),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_analytics != null) ...[
                    Text('Rating Summary', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _buildRatingRow('Overall', _analytics!.avgOverall, theme),
                    _buildRatingRow('Efficiency', _analytics!.avgEfficiency, theme),
                    _buildRatingRow('Professionalism', _analytics!.avgProfessionalism, theme),
                    _buildRatingRow('Cleanliness', _analytics!.avgCleanliness, theme),
                    _buildRatingRow('Waiting Time', _analytics!.avgWaitingTime, theme),
                    const SizedBox(height: 12),
                    _buildDistributionBar(theme),
                  ],
                  const SizedBox(height: 24),
                  Text('Individual Feedback (${_feedbacks.length})',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (_feedbacks.isEmpty)
                    const EmptyState(icon: Icons.feedback_outlined, title: 'No feedback yet')
                  else
                    ..._feedbacks.map((f) => _buildFeedbackCard(f, theme)),
                ],
              ),
            ),
    );
  }

  Widget _buildRatingRow(String label, double value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: theme.textTheme.bodyMedium)),
          const Spacer(),
          ...List.generate(5, (i) {
            final filled = i < value.round();
            return Icon(
              filled ? Icons.star : Icons.star_border,
              color: filled ? Colors.amber : theme.disabledColor,
              size: 20,
            );
          }),
          const SizedBox(width: 8),
          SizedBox(width: 36, child: Text(value.toStringAsFixed(1), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(ThemeData theme) {
    if (_analytics == null) return const SizedBox.shrink();
    final total = _analytics!.totalFeedbacks;
    if (total == 0) return const SizedBox.shrink();
    final counts = [
      _analytics!.rating1Count,
      _analytics!.rating2Count,
      _analytics!.rating3Count,
      _analytics!.rating4Count,
      _analytics!.rating5Count,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distribution', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...List.generate(5, (i) {
              final star = i + 1;
              final pct = total > 0 ? counts[i] / total : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(width: 24, child: Text('$star', textAlign: TextAlign.right)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: pct, minHeight: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 24, child: Text('${counts[i]}', textAlign: TextAlign.right)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> item, ThemeData theme) {
    final name = item['donor_name'] as String? ?? 'Anonymous';
    final overall = item['overall_rating'] as int? ?? 0;
    final comment = item['comment'] as String?;
    final createdAt = item['created_at'] is DateTime
        ? item['created_at'] as DateTime
        : DateTime.tryParse(item['created_at']?.toString() ?? '');
    final dateStr = createdAt != null ? DateFormat('MMM d, yyyy').format(createdAt) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(5, (i) => Icon(
                  i < overall ? Icons.star : Icons.star_border,
                  color: Colors.amber, size: 18,
                )),
                const Spacer(),
                Text(dateStr, style: theme.textTheme.bodySmall),
              ],
            ),
            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(comment, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 4),
            Text('- $name', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
