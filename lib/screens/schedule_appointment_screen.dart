import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Widget structure:
/// - Scaffold
///   - Hospital chip selector
///   - Date strip
///   - Time slots 2-column grid
///   - My appointments list
///   - Fixed bottom "Book" action
class ScheduleAppointmentScreen extends ConsumerStatefulWidget {
  const ScheduleAppointmentScreen({super.key});
  @override
  ConsumerState<ScheduleAppointmentScreen> createState() => _ScheduleAppointmentScreenState();
}

class _ScheduleAppointmentScreenState extends ConsumerState<ScheduleAppointmentScreen> {
  List<Map<String, dynamic>> _slots = const [];
  List<Map<String, dynamic>> _appointments = const [];
  List<String> _hospitals = const [];
  bool _loading = true;
  int _hospitalIndex = 0;
  int _dateIndex = 0;
  int _slotIndex = -1;
  String? _recipientId;
  String _bloodType = 'O+';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = ref.read(authServiceProvider).currentUser;
    if (auth == null) return;
    final user = await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
    if (user == null) return;
    final service = ref.read(appointmentServiceProvider);
    final slots = await service.getAvailableSlots(null);
    final mine = await service.getDonorAppointments(user.id);
    final hospitals = <String>{
      'All',
      ...slots
          .map((e) => (e['hospital_name'] ?? '').toString())
          .where((e) => e.trim().isNotEmpty),
    }.toList();
    if (!mounted) return;
    setState(() {
      _slots = slots;
      _appointments = mine;
      _hospitals = hospitals;
      _recipientId = user.id;
      _bloodType = user.bloodType;
      _hospitalIndex = 0;
      _slotIndex = -1;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredSlots {
    if (_hospitals.isEmpty || _hospitalIndex <= 0) return _slots;
    final selectedHospital = _hospitals[_hospitalIndex];
    return _slots
        .where((s) => (s['hospital_name'] ?? '').toString() == selectedHospital)
        .toList();
  }

  Future<void> _book() async {
    final slots = _filteredSlots;
    if (_slotIndex < 0 || _slotIndex >= slots.length || _recipientId == null) return;
    await ref.read(appointmentServiceProvider).bookSlot(
          slotId: slots[_slotIndex]['id'].toString(),
          donorId: _recipientId!,
          bloodType: _bloodType,
        );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final dates = List.generate(8, (i) => DateTime.now().add(Duration(days: i)));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/recipient/home');
            }
          },
        ),
        title: const Text('Schedule Appointment'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                const SectionHeader(title: 'Hospital'),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      _hospitals.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_hospitals[i]),
                          selected: i == _hospitalIndex,
                          onSelected: (_) {
                            setState(() {
                              _hospitalIndex = i;
                              _slotIndex = -1;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(dates.length, (i) {
                      final d = dates[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${d.day}/${d.month}'),
                          selected: _dateIndex == i,
                          onSelected: (_) => setState(() => _dateIndex = i),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: _filteredSlots.length,
                  itemBuilder: (_, i) {
                    final s = _filteredSlots[i];
                    final available = (s['available_slots'] as int? ?? 0) > 0;
                    final selected = _slotIndex == i;
                    return InkWell(
                      onTap: available ? () => setState(() => _slotIndex = i) : null,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primaryRed : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: available ? AppColors.divider : Colors.grey.shade400),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            '${s['hospital_name'] ?? 'Hospital'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.white70 : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('${s['slot_time']}', style: TextStyle(color: selected ? Colors.white : null)),
                          const Spacer(),
                          Text(available ? '${s['available_slots']} slots left' : 'Full', style: TextStyle(color: selected ? Colors.white70 : AppColors.textSecondary)),
                        ]),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'My Appointments'),
                const SizedBox(height: 8),
                ..._appointments.map((a) {
                    final date = DateTime.parse(a['slot_date'].toString());
                    final time = a['slot_time'].toString().substring(0, 5);
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: Theme.of(context).cardColor,
                      title: Text('${a['hospital_name']}'),
                      subtitle: Text('${DateFormat('EEE, MMM d').format(date)} • $time'),
                      trailing: Chip(label: Text('${a['status']}')),
                    );
                  }),
              ],
            ),
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, border: const Border(top: BorderSide(color: AppColors.divider))),
          child: AppButton.primary(
            label: _slotIndex < 0 ? 'Select a Slot' : 'Book Appointment',
            onPressed: _slotIndex < 0 ? null : _book,
          ),
        ),
      ),
    );
  }
}

