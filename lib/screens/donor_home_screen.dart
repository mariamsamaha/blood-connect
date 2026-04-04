import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/main.dart';

class DonorHomeScreen extends ConsumerStatefulWidget {
  const DonorHomeScreen({super.key});

  @override
  ConsumerState<DonorHomeScreen> createState() => _DonorHomeScreenState();
}

class _DonorHomeScreenState extends ConsumerState<DonorHomeScreen> {
  List<BloodRequest> _matchingRequests = [];
  BloodRequest? _activeMission;
  Map<String, int> _stats = {};
  bool _isLoading = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _locationError = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final donorService = ref.read(donorServiceProvider);
      final locationService = ref.read(locationServiceProvider);

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
      // Register FCM token for push notifications (donor request alerts)
      _registerFcmTokenIfNeeded(firebaseUser.uid);

      // Load donor stats
      final stats = await donorService.getDonorStats(profile.id);
      BloodRequest? mission = await donorService.getActiveMission(profile.id);

      double? lat = profile.latitude;
      double? lng = profile.longitude;
      if (lat == null || lng == null) {
        final pos = await locationService.getCurrentPosition();
        lat = pos?.latitude;
        lng = pos?.longitude;
      }
      // Fallback: when no location, use default center and large radius so donors still see requests
      const defaultLat = 30.0444;
      const defaultLng = 31.2357;
      const defaultRadiusKm = 300;
      final useFallbackLocation = lat == null || lng == null;
      final searchLat = lat ?? defaultLat;
      final searchLng = lng ?? defaultLng;
      final radiusKm = useFallbackLocation
          ? defaultRadiusKm
          : math.max(100, profile.notificationRadiusKm);

      List<BloodRequest> requests = await donorService.findMatchingRequests(
        donorId: profile.id,
        donorBloodType: profile.bloodType,
        donorLat: searchLat,
        donorLng: searchLng,
        radiusKm: radiusKm,
      );

      if (useFallbackLocation) {
        _locationError = 'Location unavailable – showing requests within ${defaultRadiusKm} km of default area. Enable location for accurate matching.';
      } else {
        _locationError = null;
      }

      if (mounted) {
        setState(() {
          _stats = stats;
          _activeMission = mission;
          _matchingRequests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        });
      }
    }
  }

  Future<void> _acceptRequest(BloodRequest request) async {
    final authService = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);
    final donorService = ref.read(donorServiceProvider);
    final locationService = ref.read(locationServiceProvider);

    final firebaseUser = authService.currentUser;
    if (firebaseUser == null) return;
    final profile = await userService.getProfileByFirebaseUid(firebaseUser.uid);
    if (profile == null) return;

    double? lat = profile.latitude;
    double? lng = profile.longitude;
    if (lat == null || lng == null) {
      final pos = await locationService.getCurrentPosition();
      lat = pos?.latitude;
      lng = pos?.longitude;
    }
    if (lat == null || lng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location required to accept')),
        );
      }
      return;
    }

    try {
      await donorService.acceptRequest(
        requestId: request.id,
        donorId: profile.id,
        donorLat: lat,
        donorLng: lng,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You accepted this request. Head to the hospital!')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not accept: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
        _load();
      }
    }
  }

  Future<void> _registerFcmTokenIfNeeded(String firebaseUid) async {
    try {
      final userService = ref.read(userServiceProvider);
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) return;
      final token = await messaging.getToken();
      if (token != null) await userService.updateFcmToken(firebaseUid, token);
    } catch (_) {
      // FCM or DB column may be unavailable; ignore
    }
  }

  Future<void> _declineRequest(BloodRequest request) async {
    final authService = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);
    final donorService = ref.read(donorServiceProvider);

    final firebaseUser = authService.currentUser;
    if (firebaseUser == null) return;
    final profile = await userService.getProfileByFirebaseUid(firebaseUser.uid);
    if (profile == null) return;

    try {
      await donorService.declineRequest(requestId: request.id, donorId: profile.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request declined')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Donor Home'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    if (_activeMission != null) ...[
                      _buildActiveMissionCard(_activeMission!),
                      const SizedBox(height: 20),
                    ],
                    _buildStats(),
                    const SizedBox(height: 20),
                    _buildMatchingRequestsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[600]!, Colors.red[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bloodtype, color: Colors.white, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome to Donor View',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Help save lives — accept urgent requests near you',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMissionCard(BloodRequest request) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
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
              Icon(Icons.assignment, color: Colors.orange.shade700, size: 24),
              const SizedBox(width: 10),
              Text(
                'Your current mission',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Verification code at hospital: ${request.displayCode}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            request.hospitalName,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${request.bloodType} • ${request.unitsNeeded} unit(s)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.volunteer_activism,
            title: 'Total Donations',
            value: '${_stats['totalDonations'] ?? 0}',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            icon: Icons.stars,
            title: 'Reward Points',
            value: '${_stats['rewardPoints'] ?? 0}',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
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
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingRequestsSection() {
    return Container(
      width: double.infinity,
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
              Icon(Icons.location_on, color: Colors.red[600], size: 20),
              const SizedBox(width: 10),
              Text(
                'Nearby Urgent Requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          if (_locationError != null) ...[
            const SizedBox(height: 12),
            Text(
              _locationError!,
              style: TextStyle(color: Colors.orange[800], fontSize: 14),
            ),
          ],
          const SizedBox(height: 15),
          if (_matchingRequests.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No urgent requests in your area right now',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            )
          else
            ..._matchingRequests.map((r) => _buildRequestCard(r)),
        ],
      ),
    );
  }

  Widget _buildRequestCard(BloodRequest request) {
    final urgencyColor = request.urgencyLevel == UrgencyLevel.critical
        ? Colors.red
        : request.urgencyLevel == UrgencyLevel.urgent
            ? Colors.orange
            : Colors.blue;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgencyColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.urgencyLevel.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: urgencyColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  request.bloodType,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (request.distanceKm != null)
                  Text(
                    '${request.distanceKm!.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.hospitalName,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${request.unitsNeeded} unit(s) • ${DateFormat('MMM d, HH:mm').format(request.createdAt)}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _declineRequest(request),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[400]!),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptRequest(request),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
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
}
