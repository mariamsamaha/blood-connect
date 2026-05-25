import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/ai_eligibility_result.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/ai_eligibility_service.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
final aiEligibilityServiceProvider = Provider<AiEligibilityService>(
  (ref) => AiEligibilityService(ref.watch(apiClientProvider)),
);

// ── Entry point called from donor_home_screen.dart ────────────────────────────
/// Shows the AI eligibility gate as a bottom sheet.
/// Returns true  → donor confirmed, proceed with acceptRequest.
/// Returns false → donor cancelled or is not eligible.
Future<bool> showAiEligibilityGate(
  BuildContext context,
  WidgetRef ref,
  UserProfile profile,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _AiGate(profile: profile),
    ),
  );
  return result ?? false;
}

// ═════════════════════════════════════════════════════════════════════════════
enum _Step { questions, checking, result }

class _AiGate extends ConsumerStatefulWidget {
  const _AiGate({required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_AiGate> createState() => _AiGateState();
}

class _AiGateState extends ConsumerState<_AiGate> {
  _Step _step = _Step.questions;
  bool? _feelingWell;
  bool? _recentIllness;
  AiEligibilityResult? _result;

  bool get _canCheck => _feelingWell != null && _recentIllness != null;

  Future<void> _runCheck() async {
    setState(() => _step = _Step.checking);
    final result = await ref.read(aiEligibilityServiceProvider).check(
          donorId: widget.profile.id,
          bloodType: widget.profile.bloodType,
          feelingWell: _feelingWell,
          recentIllness: _recentIllness,
        );
    if (!mounted) return;
    setState(() {
      _result = result;
      _step = _Step.result;
    });
  }

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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (_step) {
            _Step.questions => _QuestionsView(
                key: const ValueKey('q'),
                feelingWell: _feelingWell,
                recentIllness: _recentIllness,
                canCheck: _canCheck,
                onFeelingWell: (v) => setState(() => _feelingWell = v),
                onRecentIllness: (v) => setState(() => _recentIllness = v),
                onCancel: () => Navigator.pop(context, false),
                onCheck: _runCheck,
              ),
            _Step.checking => const _CheckingView(key: ValueKey('c')),
            _Step.result => _ResultView(
                key: const ValueKey('r'),
                result: _result!,
                onProceed: () => Navigator.pop(context, true),
                onCancel: () => Navigator.pop(context, false),
              ),
          },
        ),
      ),
    );
  }
}

// ── Step 1: Questions ─────────────────────────────────────────────────────────
class _QuestionsView extends StatelessWidget {
  const _QuestionsView({
    super.key,
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
                  child: Text('🤖', style: TextStyle(fontSize: 24)),
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

// ── Step 2: Checking ──────────────────────────────────────────────────────────
class _CheckingView extends StatelessWidget {
  const _CheckingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              color: AppColors.primaryRed,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Checking your eligibility…',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'The AI model is reviewing your health profile',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Result ────────────────────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  const _ResultView({
    super.key,
    required this.result,
    required this.onProceed,
    required this.onCancel,
  });

  final AiEligibilityResult result;
  final VoidCallback onProceed;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final status = result.status;
    final isEligible = status == EligibilityStatus.eligible;
    final isUncertain = status == EligibilityStatus.uncertain;
    final isError = status == EligibilityStatus.error;
    final isBlocked = status == EligibilityStatus.notEligible;

    final Color statusColor = isEligible
        ? AppColors.success
        : isUncertain
            ? AppColors.warning
            : isError
                ? AppColors.textSecondary
                : AppColors.error;

    final String emoji =
        isEligible ? '✅' : isUncertain ? '⚠️' : isError ? '⚙️' : '❌';

    final String headline = isEligible
        ? 'You look good to go!'
        : isUncertain
            ? 'Proceed with caution'
            : isError
                ? 'Check unavailable'
                : 'Not recommended today';

    final String proceedLabel = isEligible
        ? 'Accept request'
        : 'I understand, proceed anyway';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
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
          const SizedBox(height: 24),
          // Emoji + headline
          Center(
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 10),
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Score bar (hidden for error state)
          if (!isError) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Eligibility score',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${(result.score * 100).round()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: result.score,
                    minHeight: 10,
                    backgroundColor: AppColors.divider,
                    color: statusColor,
                  ),
                );
              },
            ),
          ],
          // Warnings
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHead(label: '⚠️  Things to note', color: AppColors.warning),
            const SizedBox(height: 8),
            ...result.warnings.map(
              (w) => _Bullet(text: w, color: AppColors.warning),
            ),
          ],
          // Tips
          if (result.tips.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionHead(
                label: '💡  Tips for a safe donation',
                color: AppColors.success),
            const SizedBox(height: 8),
            ...result.tips.map(
              (t) => _Bullet(text: t, color: AppColors.success),
            ),
          ],
          // AI disclaimer
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Text(
              '⚕️  This is an AI assessment, not medical advice. The final decision is always yours. When in doubt, consult a doctor.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: AppButton.ghost(
                  label: 'Not now',
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: isBlocked
                    ? AppButton.danger(
                        label: proceedLabel,
                        onPressed: onProceed,
                      )
                    : AppButton.primary(
                        label: proceedLabel,
                        onPressed: onProceed,
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

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
