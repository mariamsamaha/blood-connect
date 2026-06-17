import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/screens/ai_prediction_screen.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Entry point called from donor_home_screen.dart ────────────────────────────
/// Shows the AI eligibility gate as a bottom sheet.
/// Returns true  → donor confirmed, proceed with acceptRequest.
/// Returns false → donor cancelled or is not eligible.
Future<bool> showAiEligibilityGate(
  BuildContext context,
  WidgetRef ref,
  UserProfile profile,
) async {
  // Step 1 — show the 2-question modal
  final shouldProceed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _AiGate(profile: profile),
  );

  // Donor cancelled or dismissed
  if (shouldProceed != true) return false;
  if (!context.mounted) return false;

  // Step 2 — forward to the full AI prediction screen
  final confirmed = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => const AiPredictionScreen(gateMode: true),
      fullscreenDialog: true,
    ),
  );

  return confirmed == true;
}

// ═════════════════════════════════════════════════════════════════════════════
class _AiGate extends ConsumerStatefulWidget {
  const _AiGate({required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_AiGate> createState() => _AiGateState();
}

class _AiGateState extends ConsumerState<_AiGate> {
  bool? _feelingWell;
  bool? _recentIllness;

  bool get _canCheck => _feelingWell != null && _recentIllness != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: _QuestionsView(
          feelingWell: _feelingWell,
          recentIllness: _recentIllness,
          canCheck: _canCheck,
          onFeelingWell: (v) => setState(() => _feelingWell = v),
          onRecentIllness: (v) => setState(() => _recentIllness = v),
          onCancel: () => Navigator.pop(context, false),
          // Pop the sheet with true → showAiEligibilityGate will then
          // push AiPredictionScreen
          onCheck: () => Navigator.pop(context, true),
        ),
      ),
    );
  }
}

// ── Step 1: Questions ─────────────────────────────────────────────────────────
class _QuestionsView extends StatelessWidget {
  const _QuestionsView({
    required this.feelingWell,
    required this.recentIllness,
    required this.canCheck,
    required this.onFeelingWell,
    required this.onRecentIllness,
    required this.onCancel,
    required this.onCheck,
  });

  final bool? feelingWell;
  final bool? recentIllness;
  final bool canCheck;
  final void Function(bool) onFeelingWell;
  final void Function(bool) onRecentIllness;
  final VoidCallback onCancel;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primaryRed,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Eligibility Check',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Text(
                      'Quick check before you accept',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Question 1
          _Question(
            label: 'Are you feeling well right now?',
            hint: 'No fever, fatigue, or headache',
            value: feelingWell,
            onYes: () => onFeelingWell(true),
            onNo: () => onFeelingWell(false),
          ),
          const SizedBox(height: 20),
          // Question 2
          _Question(
            label: 'Any illness or medication in the past 2 weeks?',
            hint: 'Cold, antibiotics, infection, or surgery',
            value: recentIllness,
            onYes: () => onRecentIllness(true),
            onNo: () => onRecentIllness(false),
            invertColors: true, // Yes = warning for this question
          ),
          const SizedBox(height: 32),
          // Buttons
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Cancel',
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton.primary(
                  label: 'Check eligibility',
                  onPressed: canCheck ? onCheck : null,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.label,
    required this.hint,
    required this.value,
    required this.onYes,
    required this.onNo,
    this.invertColors = false,
  });

  final String label;
  final String hint;
  final bool? value;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final bool invertColors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _AnswerChip(
              label: 'Yes',
              selected: value == true,
              selectedColor:
                  invertColors ? AppColors.warning : AppColors.success,
              onTap: onYes,
            ),
            const SizedBox(width: 12),
            _AnswerChip(
              label: 'No',
              selected: value == false,
              selectedColor:
                  invertColors ? AppColors.success : AppColors.error,
              onTap: onNo,
            ),
          ],
        ),
      ],
    );
  }
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withValues(alpha: 0.12)
                : AppColors.background,
            border: Border.all(
              color: selected ? selectedColor : AppColors.divider,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? selectedColor : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
