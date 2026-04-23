import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/user_profile.dart';

class ScheduleAppointmentScreen extends ConsumerStatefulWidget {
  const ScheduleAppointmentScreen({super.key});

  @override
  ConsumerState<ScheduleAppointmentScreen> createState() => _ScheduleAppointmentScreenState();
}

class _ScheduleAppointmentScreenState extends ConsumerState<ScheduleAppointmentScreen> {
  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _myAppointments = [];
  bool _isLoading = true;
  String? _selectedHospitalId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final appointmentService = ref.read(appointmentServiceProvider);

      final firebaseUser = authService.currentUser;
      if (firebaseUser == null) return;

      final profile = await userService.getProfileByFirebaseUid(firebaseUser.uid);
      if (profile == null) return;

      // Get my appointments
      final myAppts = await appointmentService.getDonorAppointments(profile.id);

      if (mounted) {
        setState(() {
          _slots = [];
          _myAppointments = myAppts;
          _selectedHospitalId = profile.id;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _bookSlot(Map<String, dynamic> slot) async {
    if (_selectedHospitalId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Book Appointment'),
        content: Text(
          'Book ${DateFormat('MMM d, yyyy').format(slot['slot_date'] as DateTime)} '
          'at ${slot['slot_time']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Book'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final appointmentService = ref.read(appointmentServiceProvider);
      await appointmentService.bookSlot(
        slotId: slot['id'].toString(),
        donorId: _selectedHospitalId!,
        bloodType: 'O+',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment booked!')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Schedule Appointment'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMyAppointments(),
                  const SizedBox(height: 24),
                  _buildAvailableSlots(),
                ],
              ),
            ),
    );
  }

  Widget _buildMyAppointments() {
    if (_myAppointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No appointments yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Appointments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._myAppointments.map((appt) => _buildAppointmentTile(appt)),
        ],
      ),
    );
  }

  Widget _buildAppointmentTile(Map<String, dynamic> appt) {
    final status = appt['status']?.toString() ?? '';
    final statusColor = status == 'scheduled' ? Colors.green : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt['hospital_name']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${DateFormat('MMM d, yyyy').format(appt['slot_date'] as DateTime)} at ${appt['slot_time']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableSlots() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Slots',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_slots.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No slots available. Contact hospital to schedule.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._slots.map((slot) => _buildSlotTile(slot)),
        ],
      ),
    );
  }

  Widget _buildSlotTile(Map<String, dynamic> slot) {
    final available = slot['available_slots'] as int? ?? 0;
    final isAvailable = available > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAvailable ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: isAvailable ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(slot['slot_date'] as DateTime),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${slot['slot_time']} - ${available} slots left',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isAvailable ? () => _bookSlot(slot) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Book'),
          ),
        ],
      ),
    );
  }
}