import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/donor_response_entry.dart';
import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/routing/app_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  List<BloodRequest> _myRequests = [];
  List<DonorResponseEntry> _donorHistory = [];
  bool _isLoading = true;

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
      final requestService = ref.read(requestServiceProvider);
      final donorService = ref.read(donorServiceProvider);

      final firebaseUser = authService.currentUser;
      if (firebaseUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final profile = await userService.getProfileByFirebaseUid(firebaseUser.uid);
      if (profile == null) {
        setState(() => _isLoading = false);
        return;
      }

      final requests = await requestService.getMyRequests(profile.id);
      final donorHistory = await donorService.getDonorResponseHistory(profile.id);

      if (mounted) {
        setState(() {
          _profile = profile;
          _myRequests = requests;
          _donorHistory = donorHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  Future<void> _switchActiveMode(ActiveMode mode) async {
    if (_profile == null || _profile!.accountType != AccountType.regular) return;
    if (_profile!.activeMode == mode) return;

    final fb = FirebaseAuth.instance.currentUser;
    if (fb == null) return;

    final userService = ref.read(userServiceProvider);
    final ok = await userService.updateActiveMode(fb.uid, mode);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not switch view. If you have an active blood request, cancel it first.',
          ),
        ),
      );
      return;
    }

    final updated = await userService.getProfileByFirebaseUid(fb.uid);
    if (!mounted || updated == null) return;
    setState(() => _profile = updated);
    context.go(homeRouteForProfile(updated));
  }

  String _roleTitle() {
    if (_profile == null) return '';
    if (_profile!.accountType == AccountType.hospital) return 'Hospital';
    return _profile!.activeMode == ActiveMode.recipient_view ? 'Recipient' : 'Donor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Could not load profile'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileCard(),
                        if (_profile!.accountType == AccountType.regular) ...[
                          const SizedBox(height: 16),
                          _buildRoleSwitcher(),
                        ],
                        const SizedBox(height: 24),
                        _buildRequestHistorySection(),
                        const SizedBox(height: 24),
                        _buildLogoutButton(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.red.shade100,
            child: Text(
              _profile!.name.isNotEmpty ? _profile!.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 36,
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _profile!.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _profile!.email,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (_profile!.phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _profile!.phone,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _roleTitle(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ),
          if (_profile!.bloodType.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Blood type: ${_profile!.bloodType}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
          if (_profile!.cityArea.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'City / area: ${_profile!.cityArea}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
          if (_profile!.accountType == AccountType.hospital) ...[
            const SizedBox(height: 12),
            Text(
              _profile!.hospitalVerified == true
                  ? 'Hospital account (verified for MVP matching).'
                  : 'Hospital account. Complete verification in the hospital dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleSwitcher() {
    final current = _profile!.activeMode == ActiveMode.recipient_view
        ? 'recipient'
        : 'donor';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active view',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'donor',
                label: Text('Donor'),
                icon: Icon(Icons.volunteer_activism, size: 18),
              ),
              ButtonSegment(
                value: 'recipient',
                label: Text('Recipient'),
                icon: Icon(Icons.bloodtype, size: 18),
              ),
            ],
            selected: {current},
            onSelectionChanged: (Set<String> sel) {
              final v = sel.first;
              _switchActiveMode(
                v == 'recipient'
                    ? ActiveMode.recipient_view
                    : ActiveMode.donor_view,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestHistorySection() {
    final isRecipient = _profile!.activeMode == ActiveMode.recipient_view;
    final title = isRecipient ? 'My requests' : 'Requests I responded to';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.red.shade600, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isRecipient) _buildRecipientHistoryList() else _buildDonorHistoryList(),
        ],
      ),
    );
  }

  Widget _buildRecipientHistoryList() {
    if (_myRequests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No requests yet.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _myRequests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = _myRequests[index];
        return _requestHistoryTile(
          title: r.hospitalName,
          subtitle:
              '${r.bloodType} • ${r.unitsNeeded} unit(s) • ${r.shortId}',
          status: r.mvpPrimaryStatusLabel,
          date: r.createdAt,
        );
      },
    );
  }

  Widget _buildDonorHistoryList() {
    if (_donorHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No responses yet.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _donorHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final e = _donorHistory[index];
        return _requestHistoryTile(
          title: e.hospitalName,
          subtitle: '${e.bloodType} • Code ${e.displayCode}',
          status: e.responseType,
          date: e.respondedAt,
        );
      },
    );
  }

  Widget _requestHistoryTile({
    required String title,
    required String subtitle,
    required String status,
    required DateTime date,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM d, yyyy • HH:mm').format(date),
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('open') || s.contains('matching')) return Colors.blue;
    if (s.contains('accepted')) return Colors.orange;
    if (s.contains('verified') || s.contains('closed') || s == 'fulfilled') {
      return Colors.green;
    }
    if (s.contains('cancel') || s.contains('declin')) return Colors.grey;
    if (s.contains('expired')) return Colors.red;
    switch (s) {
      case 'active':
      case 'in_progress':
        return Colors.orange;
      case 'fulfilled':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout),
        label: const Text('Log out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade700,
          side: BorderSide(color: Colors.red.shade300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
