import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/urgency_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DonorMissionScreen extends ConsumerStatefulWidget {
  const DonorMissionScreen({super.key});

  @override
  ConsumerState<DonorMissionScreen> createState() =>
      _DonorMissionScreenState();
}

class _DonorMissionScreenState extends ConsumerState<DonorMissionScreen> {
  BloodRequest? _mission;
  bool _loading = true;
  bool _withdrawing = false;

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

    final mission =
        await ref.read(donorServiceProvider).getActiveMission(profile.id);
    if (!mounted) return;
    setState(() {
      _mission = mission;
      _loading = false;
    });
  }

  Future<void> _withdraw() async {
    final mission = _mission;
    if (mission == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Withdraw from mission?'),
        content: const Text(
          'The request will go back to active so another donor can accept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Withdraw',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _withdrawing = true);

    try {
      final auth = ref.read(authServiceProvider).currentUser;
      if (auth == null) return;
      final profile =
          await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
      if (profile == null) return;

      await ref.read(donorServiceProvider).withdrawAcceptance(
            requestId: mission.id,
            donorId: profile.id,
          );
      if (!mounted) return;
      context.go('/donor/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to withdraw: $e')),
      );
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mission = _mission;
    if (mission == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mission')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_outlined, size: 40, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),
              const Text(
                'No active mission',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Active Mission')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppAnimations.medium,
            curve: AppAnimations.smooth,
            builder: (context, value, child) {
              return Opacity(opacity: value, child: child);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.primary,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Show this code at the hospital',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    mission.shortId,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 6,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: mission.shortId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded,
                        color: Colors.white70, size: 16),
                    label: const Text(
                      'Copy Code',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: AppShadows.glowRed,
                      ),
                      child: Text(
                        mission.bloodType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    UrgencyBadge(level: mission.urgencyLevel),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.local_hospital_rounded,
                  label: 'Hospital',
                  value: mission.hospitalName,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.bloodtype_rounded,
                  label: 'Units needed',
                  value: '${mission.unitsNeeded} unit(s)',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Distance',
                  value: mission.distanceKm != null
                      ? '${mission.distanceKm!.toStringAsFixed(1)} km'
                      : 'Unknown',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.route_rounded, size: 18, color: AppColors.primaryRed),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Mission Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _StatusStep(
                  icon: Icons.check_circle,
                  label: 'Request accepted',
                  done: true,
                ),
                _StatusStep(
                  icon: Icons.directions_car_rounded,
                  label: 'Travel to hospital',
                  done: false,
                ),
                _StatusStep(
                  icon: Icons.verified_rounded,
                  label: 'Hospital verifies donation',
                  done: false,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Need help? Contact the hospital if you have any issues.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton.secondary(
            label: _withdrawing ? 'Withdrawing...' : 'Withdraw from Mission',
            onPressed: _withdrawing ? null : _withdraw,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _StatusStep extends StatelessWidget {
  const _StatusStep({
    required this.icon,
    required this.label,
    required this.done,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final bool done;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: done
                    ? AppColors.primaryRed.withValues(alpha: 0.1)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppColors.primaryRed : AppColors.divider,
                size: 22,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                decoration: BoxDecoration(
                  gradient: done
                      ? LinearGradient(
                          colors: [AppColors.primaryRed, AppColors.divider],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: done ? null : AppColors.divider,
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            label,
            style: TextStyle(
              color: done ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: done ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
