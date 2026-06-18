import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/providers/notification_provider.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:bloodconnect/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class HospitalProfileScreen extends ConsumerStatefulWidget {
  const HospitalProfileScreen({super.key});
  @override
  ConsumerState<HospitalProfileScreen> createState() => _HospitalProfileScreenState();
}

class _HospitalProfileScreenState extends ConsumerState<HospitalProfileScreen> {
  UserProfile? _profile;
  List<Map<String, dynamic>> _inventory = [];
  Map<String, int> _stats = {'pending': 0, 'today': 0, 'fulfilled': 0};
  List<Map<String, dynamic>> _pendingRequests = [];
  Map<String, dynamic>? _feedbackAnalytics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    final profile = await ref.read(userServiceProvider).getProfileByFirebaseUid(user.uid);
    if (!mounted || profile == null) return;

    final results = await Future.wait([
      ref.read(hospitalServiceProvider).getInventory(profile.id),
      ref.read(hospitalServiceProvider).getHospitalStats(profile.id),
      ref.read(hospitalServiceProvider).getPendingRequests(profile.id),
      ref.read(feedbackServiceProvider).getHospitalFeedback(profile.id, limit: 1),
    ]);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _inventory = results[0] as List<Map<String, dynamic>>;
      _stats = results[1] as Map<String, int>;
      _pendingRequests = results[2] as List<Map<String, dynamic>>;
      _feedbackAnalytics = results[3] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final unreadCount = ref.watch(unreadCountNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/hospital/dashboard'),
        ),
        title: const Text('Hospital Profile'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications'),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _buildHeader(profile!),
                  const SizedBox(height: 20),
                  _buildLocationCard(profile),
                  const SizedBox(height: 20),
                  _buildStatRow(),
                  if (_inventory.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: SectionHeader(title: 'Blood Inventory')),
                        TextButton.icon(
                          onPressed: () => context.push('/hospital/inventory'),
                          icon: const Icon(Icons.tune, size: 18),
                          label: const Text('Manage'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInventoryRow(),
                  ],
                  if (_pendingRequests.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Active Requests'),
                    const SizedBox(height: 12),
                    ..._pendingRequests.map(_buildRequestItem),
                  ],
                  const SizedBox(height: 20),
                  _buildFeedbackCard(profile.id),
                  const SizedBox(height: 20),
                  _buildInfoCard(profile),
                  const SizedBox(height: 20),
                  AppButton.secondary(
                    label: 'Sign Out',
                    onPressed: _signOut,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryRed, AppColors.deepRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.primary,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              (profile.hospitalName ?? profile.name).isNotEmpty
                  ? (profile.hospitalName ?? profile.name)[0].toUpperCase()
                  : 'H',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.hospitalName ?? profile.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      profile.hospitalVerified == true
                          ? Icons.verified_rounded
                          : Icons.pending_rounded,
                      size: 14,
                      color: profile.hospitalVerified == true
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      profile.hospitalVerified == true ? 'Verified' : 'Pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if ((profile.hospitalCode ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tag_rounded, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        profile.hospitalCode!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_hospital_rounded, size: 14, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      'Hospital',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  Widget _buildLocationCard(UserProfile profile) {
    final hasLat = profile.latitude != null;
    final hasLng = profile.longitude != null;
    final hasCity = profile.cityArea.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.location_on_rounded, color: AppColors.info, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasCity)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.location_city_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile.cityArea,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          if (hasLat || hasLng)
            Row(
              children: [
                const Icon(Icons.pin_drop_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '${hasLat ? profile.latitude!.toStringAsFixed(6) : '--'}, ${hasLng ? profile.longitude!.toStringAsFixed(6) : '--'}',
                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                ),
              ],
            ),
          if (hasLat && hasLng) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${profile.latitude},${profile.longitude}',
                  );
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open maps')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('View on Map'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          if (!hasCity && !hasLat && !hasLng)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No location information available',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Today',
            value: '${_stats['today']}',
            icon: Icons.today_rounded,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            title: 'Pending',
            value: '${_stats['pending']}',
            icon: Icons.pending_actions_rounded,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            title: 'Fulfilled',
            value: '${_stats['fulfilled']}',
            icon: Icons.verified_rounded,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryRow() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _inventory.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final i = _inventory[index];
          final isLow = i['is_low'] as bool? ?? false;
          final bloodType = '${i['blood_type']}';
          final units = i['units_available'] as num? ?? 0;
          final maxUnits = 20.0;
          final fillRatio = (units / maxUnits).clamp(0.0, 1.0);

          return Container(
            width: 100,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: isLow
                  ? LinearGradient(
                      colors: [
                        AppColors.error.withValues(alpha: 0.08),
                        AppColors.error.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isLow
                    ? AppColors.error.withValues(alpha: 0.3)
                    : AppColors.divider,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  bloodType,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isLow ? AppColors.error : AppColors.primaryRed,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fillRatio,
                    minHeight: 5,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLow ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$units units',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isLow ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> r) {
    final urgency = r['urgency_level'] as String? ?? 'routine';
    final urgencyColor = urgency == 'critical'
        ? AppColors.primaryRed
        : urgency == 'urgent'
            ? AppColors.warning
            : AppColors.info;
    final hasDonor = r['donor_name'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  urgencyColor,
                  urgencyColor.withValues(alpha: 0.4),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        '${r['blood_type']}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            urgency == 'critical'
                                ? Icons.emergency_rounded
                                : Icons.schedule_rounded,
                            size: 11,
                            color: urgencyColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            urgency.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: urgencyColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      'Patient: ${r['requester_name'] ?? 'Unknown'}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    if (hasDonor) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.volunteer_activism_outlined, size: 13, color: AppColors.success),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${r['donor_name']} (${r['donor_blood_type']})',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(String hospitalId) {
    Map<String, dynamic>? analytics;
    if (_feedbackAnalytics != null) {
      analytics = _feedbackAnalytics!['analytics'] as Map<String, dynamic>?;
    }
    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }
    final avgOverall = analytics != null
        ? toDouble(analytics['avg_overall'])
        : 0.0;
    final totalFeedbacks = analytics != null
        ? toInt(analytics['total_feedbacks'])
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Feedback & Ratings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => context.push(
                  '/hospital/feedback?hospitalId=$hospitalId',
                ),
                child: const Text('View All'),
              ),
            ],
          ),
          if (totalFeedbacks > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  avgOverall.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < avgOverall.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 16,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalFeedbacks review${totalFeedbacks == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.feedback_outlined, size: 16, color: AppColors.textTertiary),
                SizedBox(width: 8),
                Text(
                  'No ratings yet',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppColors.primaryRed, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Account Info',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.calendar_month_rounded,
            label: 'Member Since',
            value: '2026',
          ),
          const Divider(height: 24),
          _InfoRow(
            icon: Icons.verified_rounded,
            label: 'Verifications',
            value: '${profile.totalDonations}',
          ),
          if (profile.phone.isNotEmpty) ...[
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.phone_rounded,
              label: 'Phone',
              value: profile.phone,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}
