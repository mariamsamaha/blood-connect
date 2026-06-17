import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/empty_state.dart';
import 'package:bloodconnect/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets hospital staff see which blood types are currently below
/// threshold (per the same low-inventory alerts the backend's
/// check_and_alert_low_inventory() scheduler creates every 5 minutes,
/// or a manual "Check now" trigger), and resolve them once restocked.
class LowInventoryAlertsScreen extends ConsumerStatefulWidget {
  const LowInventoryAlertsScreen({super.key});

  @override
  ConsumerState<LowInventoryAlertsScreen> createState() =>
      _LowInventoryAlertsScreenState();
}

class _LowInventoryAlertsScreenState
    extends ConsumerState<LowInventoryAlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  bool _checking = false;
  String? _hospitalId;
  final Set<String> _resolving = {};

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
    _hospitalId = profile.id;
    final alerts =
        await ref.read(hospitalServiceProvider).getLowInventoryAlerts(_hospitalId!);
    if (!mounted) return;
    setState(() {
      _alerts = alerts;
      _loading = false;
    });
  }

  /// Only the most recent pending/notified alert per blood type matters
  /// for display — the backend can have multiple historical rows per
  /// type (e.g. one per scheduler run before a previous one was
  /// resolved), but the resolve action clears all of them for that
  /// type at once, so showing duplicates would be confusing.
  List<Map<String, dynamic>> get _activeAlertsByType {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final alert in _alerts) {
      final status = alert['alert_status'] as String?;
      if (status != 'pending' && status != 'notified') continue;
      final bloodType = alert['blood_type'] as String? ?? '';
      if (seen.contains(bloodType)) continue;
      seen.add(bloodType);
      result.add(alert);
    }
    return result;
  }

  Future<void> _triggerCheck() async {
    setState(() => _checking = true);
    try {
      await ref.read(hospitalServiceProvider).triggerLowInventoryCheck();
      await _load();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resolve(String bloodType) async {
    if (_hospitalId == null) return;
    setState(() => _resolving.add(bloodType));
    final ok = await ref.read(hospitalServiceProvider).resolveLowInventoryAlert(
          hospitalId: _hospitalId!,
          bloodType: bloodType,
        );
    if (!mounted) return;
    setState(() => _resolving.remove(bloodType));
    if (ok) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$bloodType alert resolved')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not resolve alert — try again')),
      );
    }
  }

  Color _alertColor(int unitsAvailable, int threshold) {
    if (unitsAvailable <= 0) return AppColors.primaryRed;
    if (unitsAvailable < threshold / 2) return AppColors.warning;
    return AppColors.hospitalAlert;
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeAlertsByType;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Low Inventory Alerts'),
        actions: [
          IconButton(
            icon: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Check now',
            onPressed: _checking ? null : _triggerCheck,
          ),
        ],
      ),
      body: _loading
          ? const ShimmerLoading(child: SizedBox(height: 400, child: Card()))
          : RefreshIndicator(
              onRefresh: _load,
              child: active.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No active low-inventory alerts',
                          subtitle:
                              'All blood types are currently above their minimum threshold.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: active.length,
                      itemBuilder: (context, index) {
                        final alert = active[index];
                        final bloodType = alert['blood_type'] as String? ?? '';
                        final unitsAvailable =
                            (alert['units_available_at_alert'] as num?)?.toInt() ?? 0;
                        final threshold =
                            (alert['threshold_at_alert'] as num?)?.toInt() ?? 0;
                        final shortId = alert['short_id'] as String?;
                        final color = _alertColor(unitsAvailable, threshold);
                        final isResolving = _resolving.contains(bloodType);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  bloodType,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$unitsAvailable / $threshold units',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      shortId != null
                                          ? 'Donor alert sent · $shortId'
                                          : 'Donor alert sent',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 36,
                                child: OutlinedButton(
                                  onPressed:
                                      isResolving ? null : () => _resolve(bloodType),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.success,
                                    side: BorderSide(
                                      color: AppColors.success.withValues(alpha: 0.4),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  child: isResolving
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Resolve'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}