import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HospitalSlotManagementScreen extends ConsumerStatefulWidget {
  const HospitalSlotManagementScreen({super.key});

  @override
  ConsumerState<HospitalSlotManagementScreen> createState() =>
      _HospitalSlotManagementScreenState();
}

class _HospitalSlotManagementScreenState
    extends ConsumerState<HospitalSlotManagementScreen> {
  List<Map<String, dynamic>> _slots = [];
  bool _loading = true;
  String? _hospitalId;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);
  int _intervalMins = 30;
  int _maxDonors = 5;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider).currentUser;
      if (auth == null) return;
      final profile = await ref
          .read(userServiceProvider)
          .getProfileByFirebaseUid(auth.uid);
      if (profile == null || !mounted) return;
      _hospitalId = profile.id;

      final service = ref.read(appointmentServiceProvider);
      final slots = await service.getHospitalSlots(profile.id);
      if (!mounted) return;
      setState(() => _slots = slots);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSlots() async {
    if (_hospitalId == null) return;
    setState(() => _creating = true);
    try {
      final service = ref.read(appointmentServiceProvider);
      final slots = <Map<String, dynamic>>[];

      DateTime current = _startDate;
      while (!current.isAfter(_endDate)) {
        int hour = _startTime.hour;
        int minute = _startTime.minute;
        while (hour < _endTime.hour ||
            (hour == _endTime.hour && minute < _endTime.minute)) {
          slots.add({
            'slot_date': DateFormat('yyyy-MM-dd').format(current),
            'slot_time':
                '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
            'max_donors': _maxDonors,
          });
          minute += _intervalMins;
          if (minute >= 60) {
            hour += minute ~/ 60;
            minute = minute % 60;
          }
        }
        current = current.add(const Duration(days: 1));
      }

      await service.createSlots(hospitalId: _hospitalId!, slots: slots);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created ${slots.length} slots')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Slot Management')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Slots',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: _DateTile(
                            label: 'From',
                            date: _startDate,
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 90)),
                              );
                              if (d != null) setState(() => _startDate = d);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateTile(
                            label: 'To',
                            date: _endDate,
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: _startDate,
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 90)),
                              );
                              if (d != null) setState(() => _endDate = d);
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: _TimeTile(
                            label: 'Start',
                            time: _startTime,
                            onTap: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (t != null) setState(() => _startTime = t);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeTile(
                            label: 'End',
                            time: _endTime,
                            onTap: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (t != null) setState(() => _endTime = t);
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: _NumberPicker(
                            label: 'Interval (min)',
                            value: _intervalMins,
                            min: 15,
                            max: 120,
                            step: 15,
                            onChanged: (v) => setState(() => _intervalMins = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NumberPicker(
                            label: 'Max donors/slot',
                            value: _maxDonors,
                            min: 1,
                            max: 20,
                            step: 1,
                            onChanged: (v) => setState(() => _maxDonors = v),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      AppButton.primary(
                        label: _creating ? 'Creating...' : 'Create Slots',
                        onPressed: _creating ? null : _createSlots,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Upcoming Slots (${_slots.length})',
                ),
                const SizedBox(height: 12),
                if (_slots.isEmpty)
                  const Center(child: Text('No slots created yet'))
                else
                  ..._slots.map((s) {
                    final date =
                        DateTime.parse(s['slot_date'].toString());
                    final time =
                        s['slot_time'].toString().substring(0, 5);
                    final booked = s['current_count'] as int? ?? 0;
                    final max = s['max_donors'] as int? ?? 5;
                    return ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(
                        '${DateFormat('EEE, MMM d').format(date)} • $time',
                      ),
                      subtitle: Text('$booked/$max booked'),
                      trailing: booked == max
                          ? const Chip(label: Text('Full'))
                          : null,
                    );
                  }),
              ],
            ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(DateFormat('MMM d, yyyy').format(date),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(time.format(context),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _NumberPicker extends StatelessWidget {
  const _NumberPicker({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            onPressed:
                value <= min ? null : () => onChanged((value - step).clamp(min, max)),
            icon: const Icon(Icons.remove),
            iconSize: 20,
          ),
          Text('$value',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            onPressed:
                value >= max ? null : () => onChanged((value + step).clamp(min, max)),
            icon: const Icon(Icons.add),
            iconSize: 20,
          ),
        ]),
      ]),
    );
  }
}