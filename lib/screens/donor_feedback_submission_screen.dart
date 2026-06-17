import 'package:bloodconnect/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DonorFeedbackSubmissionScreen extends ConsumerStatefulWidget {
  final String donationId;
  final String donorId;
  final String feedbackType;
  final String targetId;
  final String targetName;

  const DonorFeedbackSubmissionScreen({
    super.key,
    required this.donationId,
    required this.donorId,
    required this.feedbackType,
    required this.targetId,
    required this.targetName,
  });

  @override
  ConsumerState<DonorFeedbackSubmissionScreen> createState() =>
      _DonorFeedbackSubmissionScreenState();
}

class _DonorFeedbackSubmissionScreenState
    extends ConsumerState<DonorFeedbackSubmissionScreen> {
  int _overall = 0;
  int _communication = 0;
  int _organization = 0;
  int _efficiency = 0;
  int _professionalism = 0;
  int _cleanliness = 0;
  int _waitingTime = 0;
  bool _isAnonymous = false;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  bool get _isHospital => widget.feedbackType == 'hospital_request';

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Rate ${widget.targetName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Your donation experience', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Help others by sharing your feedback.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          if (_isHospital) ...[
            _buildStarRow('Hospital Efficiency', _efficiency, (v) => _efficiency = v),
            _buildStarRow('Staff Professionalism', _professionalism, (v) => _professionalism = v),
            _buildStarRow('Cleanliness', _cleanliness, (v) => _cleanliness = v),
            _buildStarRow('Waiting Time (1=long, 5=short)', _waitingTime, (v) => _waitingTime = v),
          ] else ...[
            _buildStarRow('Communication', _communication, (v) => _communication = v),
            _buildStarRow('Organization', _organization, (v) => _organization = v),
          ],
          _buildStarRow('Overall', _overall, (v) => _overall = v),
          const SizedBox(height: 20),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              border: OutlineInputBorder(),
              hintText: 'Share your experience...',
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Submit anonymously'),
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit Feedback'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRow(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 14))),
          ...List.generate(5, (i) {
            final starIdx = i + 1;
            return IconButton(
              icon: Icon(
                starIdx <= value ? Icons.star : Icons.star_border,
                color: starIdx <= value ? Colors.amber : null,
              ),
              onPressed: () => setState(() => onChanged(starIdx)),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              splashRadius: 18,
            );
          }),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_overall == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide an overall rating')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(feedbackServiceProvider).submitFeedback(
        donationId: widget.donationId,
        donorId: widget.donorId,
        feedbackType: widget.feedbackType,
        targetId: widget.targetId,
        overallRating: _overall,
        communicationRating: _communication,
        organizationRating: _organization,
        hospitalEfficiencyRating: _efficiency,
        staffProfessionalismRating: _professionalism,
        cleanlinessRating: _cleanliness,
        waitingTimeRating: _waitingTime,
        comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
        isAnonymous: _isAnonymous,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
