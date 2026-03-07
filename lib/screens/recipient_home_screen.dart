import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/main.dart';

class RecipientHomeScreen extends ConsumerStatefulWidget {
  const RecipientHomeScreen({super.key});

  @override
  ConsumerState<RecipientHomeScreen> createState() => _RecipientHomeScreenState();
}

class _RecipientHomeScreenState extends ConsumerState<RecipientHomeScreen> {
  BloodRequest? _activeRequest;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveRequest();
  }

  Future<void> _loadActiveRequest() async {
    try {
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final requestService = ref.read(requestServiceProvider);

      final firebaseUser = authService.currentUser;
      if (firebaseUser == null) return;

      final profile = await userService.getProfileByFirebaseUid(firebaseUser.uid);
      if (profile == null) return;

      final request = await requestService.getActiveRequest(profile.id);
      
      if (mounted) {
        setState(() {
          _activeRequest = request;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading request: $e')),
        );
      }
    }
  }

  Future<void> _cancelRequest() async {
    if (_activeRequest == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text(
          'Are you sure you want to cancel this blood request? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final requestService = ref.read(requestServiceProvider);

      final firebaseUser = authService.currentUser;
      if (firebaseUser == null) return;

      final profile = await userService.getProfileByFirebaseUid(firebaseUser.uid);
      if (profile == null) return;

      await requestService.cancelRequest(_activeRequest!.id, profile.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled successfully')),
        );
        context.go('/donor/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel request: $e')),
        );
      }
    }
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.active:
        return Colors.blue;
      case RequestStatus.in_progress:
        return Colors.orange;
      case RequestStatus.fulfilled:
        return Colors.green;
      case RequestStatus.cancelled:
        return Colors.grey;
      case RequestStatus.expired:
        return Colors.red;
    }
  }

  String _getStatusText(RequestStatus status) {
    switch (status) {
      case RequestStatus.active:
        return 'MATCHING';
      case RequestStatus.in_progress:
        return 'ACCEPTED';
      case RequestStatus.fulfilled:
        return 'VERIFIED';
      case RequestStatus.cancelled:
        return 'CANCELLED';
      case RequestStatus.expired:
        return 'EXPIRED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Request'),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => context.go('/donor/home'),
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch to Donor View',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeRequest == null
              ? _buildNoRequestView()
              : _buildRequestView(_activeRequest!),
    );
  }

  Widget _buildNoRequestView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bloodtype_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No Active Request',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You don\'t have any active blood requests',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push('/create-request'),
              icon: const Icon(Icons.add),
              label: const Text('Create Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestView(BloodRequest request) {
    final timeLeft = request.expiresAt.difference(DateTime.now());
    final hoursLeft = timeLeft.inHours;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verification Code Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[600]!, Colors.red[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Verification Code',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  request.displayCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Show this code at the hospital',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(request.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusText(request.status),
                        style: TextStyle(
                          color: _getStatusColor(request.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      hoursLeft > 0 ? '${hoursLeft}h left' : 'Expired',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  Icons.opacity,
                  'Blood Type',
                  '${request.bloodType} (${request.unitsNeeded} units)',
                ),
                _buildDetailRow(
                  Icons.local_hospital,
                  'Hospital',
                  request.hospitalName,
                ),
                _buildDetailRow(
                  Icons.people,
                  'Nearby Donors',
                  '${request.nearbyDonorsCount} potential donors',
                ),
                _buildDetailRow(
                  Icons.calendar_today,
                  'Created',
                  DateFormat('MMM dd, yyyy • hh:mm a').format(request.createdAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          if (request.status == RequestStatus.active || request.status == RequestStatus.in_progress)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelRequest,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[600],
                  side: BorderSide(color: Colors.red[600]!),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.red[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}