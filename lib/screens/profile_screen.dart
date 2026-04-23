import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/donor_response_entry.dart';
import 'package:bloodconnect/main.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  List<BloodRequest> _myRequests = [];
  List<DonorResponseEntry> _donorHistory = [];
  List<Map<String, dynamic>> _badges = [];
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
      final history = await donorService.getDonorResponseHistory(profile.id);
      final badges = await userService.getUserBadges(profile.id);

      if (mounted) {
        setState(() {
          _profile = profile;
          _myRequests = requests;
          _donorHistory = history;
          _badges = badges;
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  String _roleTitle() {
    if (_profile == null) return '';
    if (_profile!.accountType == AccountType.hospital) return 'Hospital';
    return _profile!.role == UserRole.recipient ? 'Recipient' : 'Donor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Could not load profile'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 16),
                      if (_profile!.role == UserRole.donor) _buildStatsSection(),
                      const SizedBox(height: 16),
                      _buildHistorySection(),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    final isDonor = _profile!.role == UserRole.donor;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Text(
                  _profile!.name.isNotEmpty ? _profile!.name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 44, color: Colors.red.shade600, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(_profile!.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(_profile!.email, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
            if (_profile!.phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_profile!.phone, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isDonor ? Icons.volunteer_activism : Icons.bloodtype, color: Colors.red.shade600, size: 18),
                const SizedBox(width: 6),
                Text(_roleTitle(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red.shade600)),
              ]),
            ),
            if (_profile!.bloodType.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.water_drop, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(_profile!.bloodType, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
              ),
            ],
            if (_profile!.accountType == AccountType.hospital) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text('Verified Hospital', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                ]),
              ),
            ],
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final donations = _profile!.totalDonations;
    final points = _profile!.rewardPoints;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.emoji_events, color: Colors.amber.shade600, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Your Achievements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _buildStatCard(icon: Icons.favorite, iconColor: Colors.red, value: '$donations', label: 'Donations')),
          const SizedBox(width: 16),
          Expanded(child: _buildStatCard(icon: Icons.star, iconColor: Colors.amber, value: '$points', label: 'Points')),
        ]),
        if (_badges.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Badges Earned', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _badges.map((badge) => _buildBadgeChip(badge)).toList()),
        ],
      ]),
    );
  }

  Widget _buildStatCard({required IconData icon, required Color iconColor, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: iconColor)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ]),
    );
  }

  Widget _buildBadgeChip(Map<String, dynamic> badge) {
    final icon = badge['icon']?.toString() ?? '🏅';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.shade200)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(badge['name']?.toString() ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade800)),
      ]),
    );
  }

  Widget _buildHistorySection() {
    final isRecipient = _profile!.role == UserRole.recipient;
    final title = isRecipient ? 'My Requests' : 'My Responses';
    final icon = isRecipient ? Icons.bloodtype : Icons.volunteer_activism;
    final data = isRecipient ? _myRequests : _donorHistory;
    final emptyMessage = isRecipient ? 'No requests yet' : 'No responses yet';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12))),
          Icon(icon, color: Colors.red.shade600, size: 24),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        if (data.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(emptyMessage, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ])))
        else if (isRecipient)
          ...(_myRequests.map((r) => _buildRequestTile(r)))
        else
          ...(_donorHistory.map((e) => _buildDonorHistoryTile(e))),
      ]),
    );
  }

  Widget _buildRequestTile(BloodRequest r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.hospitalName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _getStatusColor(r.mvpPrimaryStatusLabel).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(r.mvpPrimaryStatusLabel.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(r.mvpPrimaryStatusLabel))),
          ),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _buildChip(Icons.water_drop, r.bloodType, Colors.red.shade100),
            const SizedBox(width: 8),
            _buildChip(Icons.local_hospital, '${r.unitsNeeded} units', Colors.blue.shade100),
            const SizedBox(width: 8),
            _buildChip(Icons.tag, r.shortId, Colors.grey.shade200),
          ]),
        ),
        const SizedBox(height: 10),
        Text(DateFormat('MMM d, yyyy HH:mm').format(r.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _buildDonorHistoryTile(DonorResponseEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(e.hospitalName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _getResponseColor(e.responseType).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(e.responseType.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getResponseColor(e.responseType))),
          ),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _buildChip(Icons.water_drop, e.bloodType, Colors.red.shade100),
            const SizedBox(width: 8),
            _buildChip(Icons.tag, e.displayCode, Colors.grey.shade200),
          ]),
        ),
        const SizedBox(height: 10),
        Text(DateFormat('MMM d, yyyy HH:mm').format(e.respondedAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.grey.shade700),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
      ]),
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('open') || s.contains('matching') || s == 'active') return Colors.blue;
    if (s.contains('accepted') || s.contains('in_progress')) return Colors.orange;
    if (s.contains('verified') || s == 'fulfilled') return Colors.green;
    if (s.contains('cancel')) return Colors.grey;
    if (s.contains('expired')) return Colors.red;
    return Colors.grey;
  }

  Color _getResponseColor(String response) {
    final r = response.toLowerCase();
    if (r == 'accepted') return Colors.green;
    if (r == 'declined') return Colors.red;
    return Colors.grey;
  }
}