import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/empty_state.dart';
import 'package:bloodconnect/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class InventoryManagementScreen extends ConsumerStatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  ConsumerState<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends ConsumerState<InventoryManagementScreen> {
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _hospitalId;

  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authServiceProvider).currentUser;
    if (auth == null) return;
    final profile = await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
    if (profile == null || !mounted) return;
    _hospitalId = profile.id;
    await Future.wait([_loadInventory(), _loadHistory()]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadInventory() async {
    if (_hospitalId == null) return;
    final inv = await ref.read(hospitalServiceProvider).getInventory(_hospitalId!);
    if (!mounted) return;
    setState(() => _inventory = inv);
  }

  Future<void> _loadHistory() async {
    if (_hospitalId == null) return;
    final h = await ref.read(hospitalServiceProvider).getInventoryHistory(_hospitalId!);
    if (!mounted) return;
    setState(() => _history = h);
  }

  Map<String, Map<String, dynamic>> _inventoryMap() {
    final map = <String, Map<String, dynamic>>{};
    for (final item in _inventory) {
      map[item['blood_type'] as String? ?? ''] = item;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invMap = _inventoryMap();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _loading = true);
              await Future.wait([_loadInventory(), _loadHistory()]);
              if (mounted) setState(() => _loading = false);
            },
          ),
        ],
      ),
      body: _loading
          ? const ShimmerLoading(
              child: SizedBox(height: 400, child: Card()),
            )
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await Future.wait([_loadInventory(), _loadHistory()]);
                if (mounted) setState(() => _loading = false);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Current Inventory', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ..._bloodTypes.map((bt) => _buildInventoryCard(bt, invMap[bt], theme)),
                  const SizedBox(height: 24),
                  Text('Change History', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (_history.isEmpty)
                    const EmptyState(icon: Icons.history, title: 'No changes yet')
                  else
                    ..._history.take(30).map((h) => _buildHistoryItem(h, theme)),
                ],
              ),
            ),
    );
  }

  Widget _buildInventoryCard(String bloodType, Map<String, dynamic>? item, ThemeData theme) {
    final units = item?['units_available'] as int? ?? 0;
    final threshold = item?['minimum_threshold'] as int? ?? 0;
    final isLow = item?['is_low'] as bool? ?? false;
    final isCritical = units <= 0;

    final statusColor = isCritical
        ? AppColors.error
        : isLow
            ? AppColors.warning
            : AppColors.success;
    final statusLabel = isCritical
        ? 'Critical'
        : isLow
            ? 'Low'
            : 'OK';
    final statusIcon = isCritical
        ? Icons.emergency_rounded
        : isLow
            ? Icons.warning_amber_rounded
            : Icons.check_circle_rounded;
    final progress = threshold > 0 ? (units / (threshold * 2)).clamp(0.0, 1.0) : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: blood type badge + status + action buttons ─────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isCritical
                        ? AppColors.error.withValues(alpha: 0.1)
                        : isLow
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    bloodType,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _bloodTypeName(bloodType),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$units units',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Threshold: $threshold',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Progress bar ─────────────────────────────────────────────
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),

            // ── Action row ────────────────────────────────────────────────
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAdjustDialog(bloodType, units, threshold),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Units', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryRed,
                        side: BorderSide(color: AppColors.primaryRed.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () => _showThresholdDialog(bloodType, threshold),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Threshold', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _bloodTypeName(String bt) {
    const names = {
      'A+': 'A Positive', 'A-': 'A Negative',
      'B+': 'B Positive', 'B-': 'B Negative',
      'O+': 'O Positive', 'O-': 'O Negative',
      'AB+': 'AB Positive', 'AB-': 'AB Negative',
    };
    return names[bt] ?? bt;
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, ThemeData theme) {
    final bt = item['blood_type'] as String? ?? '';
    final ct = item['change_type'] as String? ?? '';
    final changed = item['units_changed'] as int? ?? 0;
    final reason = item['reason'] as String? ?? '';
    final createdAt = item['created_at'] is DateTime
        ? item['created_at'] as DateTime
        : DateTime.tryParse(item['created_at']?.toString() ?? '');
    final dateStr = createdAt != null ? DateFormat('MMM d, HH:mm').format(createdAt) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          changed > 0 ? Icons.add_circle : Icons.remove_circle,
          color: changed > 0 ? Colors.green : Colors.red,
          size: 20,
        ),
        title: Text('$bt — ${changed > 0 ? "+$changed" : "$changed"} ($ct)',
            style: theme.textTheme.bodyMedium),
        subtitle: Text('$reason  •  $dateStr', style: theme.textTheme.bodySmall),
      ),
    );
  }

  void _showAdjustDialog(String bloodType, int currentUnits, int threshold) {
    final unitsCtrl = TextEditingController();
    final isRemove = ValueNotifier(false);
    final isSubmitting = ValueNotifier(false);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    isRemove.value ? Icons.remove_circle_outline : Icons.add_circle_outline,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$bloodType Inventory',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$currentUnits units available',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Threshold info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Threshold: $threshold units',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Mode toggle
                Row(
                  children: [
                    const Text('Mode: ', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: 'Add',
                      selected: !isRemove.value,
                      onTap: () => isRemove.value = false,
                    ),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: 'Remove',
                      selected: isRemove.value,
                      onTap: () => isRemove.value = true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: unitsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isRemove.value ? 'Units to remove' : 'Units to add',
                    hintText: 'Enter number of units',
                    prefixIcon: Icon(
                      isRemove.value ? Icons.remove_circle_outline : Icons.add_circle_outline,
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting.value ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ValueListenableBuilder(
              valueListenable: isSubmitting,
              builder: (ctx2, submitting, _) {
                return ElevatedButton(
                  onPressed: submitting ? null : () => _submitAdjust(ctx, bloodType, unitsCtrl, isRemove, isSubmitting),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRemove.value ? AppColors.error : AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isRemove.value ? 'Remove' : 'Add Units'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAdjust(
    BuildContext dialogCtx,
    String bloodType,
    TextEditingController unitsCtrl,
    ValueNotifier<bool> isRemove,
    ValueNotifier<bool> isSubmitting,
  ) async {
    final units = int.tryParse(unitsCtrl.text);
    if (units == null || units <= 0) {
      ScaffoldMessenger.of(dialogCtx).showSnackBar(
        const SnackBar(content: Text('Enter a valid number of units')),
      );
      return;
    }
    if (_hospitalId == null) return;

    isSubmitting.value = true;

    final result = isRemove.value
        ? await ref.read(hospitalServiceProvider).removeInventoryUnits(
            hospitalId: _hospitalId!, bloodType: bloodType, units: units)
        : await ref.read(hospitalServiceProvider).addInventoryUnits(
            hospitalId: _hospitalId!, bloodType: bloodType, units: units);

    if (!dialogCtx.mounted) return;

    if (result != null && result['success'] == true) {
      Navigator.pop(dialogCtx);
      await _loadInventory();
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$bloodType: ${isRemove.value ? "removed" : "added"} $units units'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      isSubmitting.value = false;
      final errorMsg = result?['error_message']?.toString() ?? 'Operation failed';
      ScaffoldMessenger.of(dialogCtx).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showThresholdDialog(String bloodType, int currentThreshold) {
    final ctrl = TextEditingController(text: currentThreshold.toString());
    final isSubmitting = ValueNotifier(false);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.tune_rounded, color: AppColors.info, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Threshold — $bloodType',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Current: $currentThreshold units',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minimum threshold (units)',
                hintText: 'e.g. 10',
                prefixIcon: const Icon(Icons.trending_flat_rounded, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              autofocus: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting.value ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ValueListenableBuilder(
              valueListenable: isSubmitting,
              builder: (_, submitting, __) {
                return ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () => _submitThreshold(ctx, bloodType, ctrl, isSubmitting),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitThreshold(
    BuildContext dialogCtx,
    String bloodType,
    TextEditingController ctrl,
    ValueNotifier<bool> isSubmitting,
  ) async {
    final threshold = int.tryParse(ctrl.text);
    if (threshold == null || threshold < 0) {
      ScaffoldMessenger.of(dialogCtx).showSnackBar(
        const SnackBar(content: Text('Enter a valid threshold value')),
      );
      return;
    }
    if (_hospitalId == null) return;

    isSubmitting.value = true;
    final ok = await ref.read(hospitalServiceProvider).setInventoryThreshold(
      hospitalId: _hospitalId!,
      bloodType: bloodType,
      threshold: threshold,
    );

    if (!dialogCtx.mounted) return;

    if (ok) {
      Navigator.pop(dialogCtx);
      await _loadInventory();
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$bloodType threshold set to $threshold'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      isSubmitting.value = false;
      ScaffoldMessenger.of(dialogCtx).showSnackBar(
        const SnackBar(
          content: Text('Failed to set threshold — try again'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryRed.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected
                ? AppColors.primaryRed.withValues(alpha: 0.3)
                : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primaryRed : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
