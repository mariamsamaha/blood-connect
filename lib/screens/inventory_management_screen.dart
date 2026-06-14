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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isLow ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(bloodType, style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isLow ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer,
              )),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$bloodType — $units units', style: theme.textTheme.titleMedium),
                  Text('Threshold: $threshold', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () => _showAdjustDialog(bloodType, units, threshold),
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    icon: const Icon(Icons.settings, size: 20),
                    onPressed: () => _showThresholdDialog(bloodType, threshold),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('$bloodType Inventory'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current: $currentUnits units  |  Threshold: $threshold'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Mode: '),
                  FilterChip(label: const Text('Add'), selected: !isRemove.value, onSelected: (_) => isRemove.value = false),
                  const SizedBox(width: 8),
                  FilterChip(label: const Text('Remove'), selected: isRemove.value, onSelected: (_) => isRemove.value = true),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unitsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Units', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final units = int.tryParse(unitsCtrl.text);
                if (units == null || units <= 0) return;
                if (_hospitalId == null) return;

                final result = isRemove.value
                    ? await ref.read(hospitalServiceProvider).removeInventoryUnits(
                        hospitalId: _hospitalId!, bloodType: bloodType, units: units)
                    : await ref.read(hospitalServiceProvider).addInventoryUnits(
                        hospitalId: _hospitalId!, bloodType: bloodType, units: units);

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (result != null && result['success'] == true) {
                  await _loadInventory();
                  await _loadHistory();
                } else {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(result?['error_message']?.toString() ?? 'Operation failed')),
                    );
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showThresholdDialog(String bloodType, int currentThreshold) {
    final ctrl = TextEditingController(text: currentThreshold.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set Threshold — $bloodType'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minimum threshold (units)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final threshold = int.tryParse(ctrl.text);
              if (threshold == null || threshold < 0 || _hospitalId == null) return;
              final ok = await ref.read(hospitalServiceProvider).setInventoryThreshold(
                hospitalId: _hospitalId!, bloodType: bloodType, threshold: threshold);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (ok) {
                await _loadInventory();
                await _loadHistory();
              } else {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Failed to set threshold')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
