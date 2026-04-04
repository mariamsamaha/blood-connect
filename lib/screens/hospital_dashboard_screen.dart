import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital_request_match.dart';
import 'package:bloodconnect/models/user_profile.dart';

class HospitalDashboardScreen extends ConsumerStatefulWidget {
  const HospitalDashboardScreen({super.key});

  @override
  ConsumerState<HospitalDashboardScreen> createState() =>
      _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState
    extends ConsumerState<HospitalDashboardScreen> {
  final _codeController = TextEditingController();
  final _staffController = TextEditingController();
  List<HospitalRequestMatch> _matches = [];
  HospitalRequestMatch? _selected;
  bool _searching = false;
  bool _verifying = false;
  String? _error;
  List<Map<String, dynamic>> _audit = [];

  @override
  void dispose() {
    _codeController.dispose();
    _staffController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final auth = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);
    final hospitalService = ref.read(hospitalServiceProvider);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() {
      _searching = true;
      _error = null;
      _matches = [];
      _selected = null;
      _audit = [];
    });

    try {
      final profile = await userService.getProfileByFirebaseUid(user.uid);
      if (profile == null || profile.accountType != AccountType.hospital) {
        setState(() {
          _searching = false;
          _error = 'Hospital profile required.';
        });
        return;
      }

      final list = await hospitalService.searchByDisplayCode(
        hospitalUserId: profile.id,
        fourDigitInput: _codeController.text,
      );

      if (!mounted) return;
      setState(() {
        _matches = list;
        _searching = false;
        if (list.isEmpty) {
          _error =
              'No active request for this 4-digit code at your hospital.';
        }
        if (list.length == 1) {
          _selected = list.first;
          _loadAudit(list.first.request.id);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadAudit(String requestId) async {
    final hospitalService = ref.read(hospitalServiceProvider);
    final rows = await hospitalService.getRecentAuditForRequest(requestId);
    if (mounted) setState(() => _audit = rows);
  }

  Future<void> _verify() async {
    final sel = _selected;
    if (sel == null) return;

    final auth = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);
    final hospitalService = ref.read(hospitalServiceProvider);
    final user = auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm verification'),
        content: Text(
          'Mark donation verified for code ${sel.request.displayCode}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _verifying = true);
    try {
      final profile = await userService.getProfileByFirebaseUid(user.uid);
      if (profile == null) throw Exception('Profile not found');

      final err = await hospitalService.verifyDonation(
        hospitalUserId: profile.id,
        requestId: sel.request.id,
        staffName: _staffController.text.trim().isEmpty
            ? null
            : _staffController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _verifying = false);

      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verified — request closed (MVP audit + inventory log).')),
      );
      setState(() {
        _selected = null;
        _matches = [];
        _codeController.clear();
        _audit = [];
      });
    } catch (e) {
      if (mounted) {
        setState(() => _verifying = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Hospital — verify donation'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Enter the 4-digit code from the patient/donor (MVP manual verification).',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              counterText: '',
              hintText: '0000',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(_searching ? 'Searching…' : 'Search'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_matches.length > 1) ...[
            const SizedBox(height: 20),
            const Text('Select a match', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._matches.map((m) => ListTile(
                  title: Text('${m.request.bloodType} · ${m.request.displayCode}'),
                  subtitle: Text(m.request.status.name),
                  onTap: () {
                    setState(() => _selected = m);
                    _loadAudit(m.request.id);
                  },
                )),
          ],
          if (_selected != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request ID: ${_selected!.request.shortId}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Code: ${_selected!.request.displayCode}'),
                    Text('Status: ${_selected!.request.mvpPrimaryStatusLabel}'),
                    if (_selected!.donorName != null)
                      Text('Donor: ${_selected!.donorName}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _staffController,
              decoration: const InputDecoration(
                labelText: 'Staff name (optional)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _verifying ||
                      _selected!.request.status != RequestStatus.in_progress
                  ? null
                  : _verify,
              icon: _verifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(
                _selected!.request.status == RequestStatus.in_progress
                    ? 'Verify donation (terminal: verified/closed)'
                    : 'Wait until a donor has accepted (in progress)',
              ),
            ),
            if (_audit.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Audit trail', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._audit.map((row) {
                final t = row['created_at'];
                final dt = t is DateTime
                    ? t
                    : DateTime.tryParse(t?.toString() ?? '') ?? DateTime.now();
                return ListTile(
                  dense: true,
                  title: Text(row['event_type']?.toString() ?? ''),
                  subtitle: Text(row['detail']?.toString() ?? ''),
                  trailing: Text(DateFormat('MMM d HH:mm').format(dt),
                      style: const TextStyle(fontSize: 11)),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }
}
