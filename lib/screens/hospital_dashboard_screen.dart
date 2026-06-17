import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/hospital_request_match.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/providers/notification_provider.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:bloodconnect/widgets/shimmer_loading.dart';
import 'package:bloodconnect/widgets/sync_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HospitalDashboardScreen extends ConsumerStatefulWidget {
  const HospitalDashboardScreen({super.key});
  @override
  ConsumerState<HospitalDashboardScreen> createState() =>
      _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState
    extends ConsumerState<HospitalDashboardScreen> {
  String _code = '';
  HospitalRequestMatch? _match;
  UserProfile? _profile;
  Map<String, int> _stats = {'pending': 0, 'today': 0, 'fulfilled': 0};
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _lowInventoryAlerts = [];
  bool _loading = true;
  final FocusNode _codeFocus = FocusNode();
  String _greeting = '';

  @override
  void initState() {
    super.initState();
    _setGreeting();
    _loadProfile();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }
    setState(() => _greeting = greeting);
  }

  @override
  void dispose() {
    _codeFocus.dispose();
    super.dispose();
  }

  String get _formattedDate {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    final profile =
        await ref.read(userServiceProvider).getProfileByFirebaseUid(user.uid);
    if (!mounted) return;

    if (profile != null) {
      final results = await Future.wait([
        ref.read(hospitalServiceProvider).getHospitalStats(profile.id),
        ref.read(hospitalServiceProvider).getPendingRequests(profile.id),
        ref.read(hospitalServiceProvider).getLowInventoryAlerts(profile.id),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _stats = results[0] as Map<String, int>;
        _pendingRequests = results[1] as List<Map<String, dynamic>>;
        _lowInventoryAlerts = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    }
  }

  Future<void> _searchCode() async {
    if (_code.length != 4 || _profile == null) return;
    final list =
        await ref.read(hospitalServiceProvider).searchByDisplayCode(
              hospitalUserId: _profile!.id,
              fourDigitInput: _code,
            );
    if (!mounted) return;
    setState(() => _match = list.isEmpty ? null : list.first);
  }

  Future<void> _verify() async {
    if (_match == null || _profile == null) return;
    final err = await ref.read(hospitalServiceProvider).verifyDonation(
          hospitalUserId: _profile!.id,
          requestId: _match!.request.id,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Donation verified')),
    );
    if (err == null) {
      setState(() {
        _code = '';
        _match = null;
      });
    }
  }

  void _tapDigit(String d) {
    if (_code.length >= 4) return;
    if (_match != null) {
      setState(() {
        _code = d;
        _match = null;
      });
      return;
    }
    setState(() => _code += d);
    if (_code.length == 4) _searchCode();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (_match != null) {
          _verify();
        } else if (_code.length == 4) {
          _searchCode();
        }
        return;
      }
      if (key == LogicalKeyboardKey.backspace ||
          key == LogicalKeyboardKey.delete) {
        setState(() {
          _code =
              _code.isEmpty ? '' : _code.substring(0, _code.length - 1);
          _match = null;
        });
        return;
      }
      if (key.keyLabel.length == 1 &&
          RegExp(r'[0-9]').hasMatch(key.keyLabel)) {
        _tapDigit(key.keyLabel);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadCountNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('BloodConnect'),
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
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
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
          const SizedBox(width: 4),
          const SyncStatusIndicator(),
        ],
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const ShimmerLoading(
                  child: SizedBox(height: 120, child: Card()),
                ),
                const SizedBox(height: 20),
                Row(
                  children: List.generate(3, (_) => const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: ShimmerLoading(
                        child: SizedBox(height: 100, child: Card()),
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 24),
                const ShimmerLoading(child: SectionHeader(title: 'Verify Donation')),
                const SizedBox(height: 12),
                const ShimmerLoading(
                  child: SizedBox(height: 200, child: Card()),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildStatRow(),
                if (_lowInventoryAlerts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildLowInventoryBanner(),
                ],
                const SizedBox(height: 24),
                _buildVerifySection(),
                if (_match != null) ...[
                  const SizedBox(height: 16),
                  _buildMatchCard(),
                ],
                if (_pendingRequests.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Active Requests'),
                  const SizedBox(height: 12),
                  ..._pendingRequests.map(_buildRequestItem),
                ],
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) context.go('/stories');
          if (i == 2) context.go('/hospital/profile');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_rounded),
            label: 'Stories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryRed,
            AppColors.deepRed,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting,',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _profile?.hospitalName ?? 'Hospital',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _profile?.hospitalCode ?? '-',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                _formattedDate,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if ((_profile?.cityArea ?? '').isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _profile?.cityArea ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow() {
    return Row(
      children: [
        Expanded(
          child: _buildEnhancedStatCard(
            title: 'Today',
            value: '${_stats['today']}',
            icon: Icons.today_rounded,
            gradient: AppGradients.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildEnhancedStatCard(
            title: 'Pending',
            value: '${_stats['pending']}',
            icon: Icons.pending_actions_rounded,
            gradient: AppGradients.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildEnhancedStatCard(
            title: 'Fulfilled',
            value: '${_stats['fulfilled']}',
            icon: Icons.verified_rounded,
            gradient: AppGradients.success,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedStatCard({
    required String title,
    required String value,
    required IconData icon,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.25),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowInventoryBanner() {
    final types = _lowInventoryAlerts.map((a) => '${a['blood_type']}').join(', ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.error.withValues(alpha: 0.08),
            AppColors.warning.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Low Inventory',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_lowInventoryAlerts.length} blood type${_lowInventoryAlerts.length == 1 ? '' : 's'} below threshold: $types',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/hospital/profile'),
            child: const Text('Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Verify Donation'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: AppShadows.glowRed,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter Donor Code',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ask the donor for their 4-digit code',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              KeyboardListener(
                focusNode: _codeFocus,
                autofocus: true,
                onKeyEvent: _handleKeyEvent,
                child: Column(
                  children: [
                    _OtpBoxes(code: _code),
                    const SizedBox(height: 20),
                    _Keypad(
                      onDigit: _tapDigit,
                      onBack: () => setState(
                        () => _code = _code.isEmpty
                            ? ''
                            : _code.substring(0, _code.length - 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      'Donor matched to request',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                _DetailRow(
                  label: 'Blood Type',
                  value: _match!.request.bloodType,
                  icon: Icons.water_drop_rounded,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Units Needed',
                  value: '${_match!.request.unitsNeeded}',
                  icon: Icons.inventory_2_rounded,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Donor',
                  value: _match!.donorName ?? 'Not yet accepted',
                  icon: Icons.person_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppButton.primary(
            label: 'Verify Donation',
            onPressed: _verify,
            icon: Icons.verified_rounded,
          ),
        ],
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
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Code: ${r['display_code']}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primaryRed,
                        ),
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
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (hasDonor) ...[
                      Icon(Icons.volunteer_activism_outlined, size: 13, color: AppColors.success),
                      const SizedBox(width: 4),
                      Expanded(
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
                    ] else ...[
                      Expanded(
                        child: Row(
                          children: [
                            SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Waiting for donor...',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.icon,
  });
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
        ],
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        4,
        (i) => Expanded(
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: i < code.length
                  ? LinearGradient(
                      colors: [
                        AppColors.primaryRed.withValues(alpha: 0.08),
                        AppColors.primaryRed.withValues(alpha: 0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: Border.all(
                color: i < code.length
                    ? AppColors.primaryRed
                    : AppColors.divider,
                width: i < code.length ? 1.8 : 1,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: i < code.length
                  ? [
                      BoxShadow(
                        color: AppColors.primaryRed.withValues(alpha: 0.08),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedOpacity(
              duration: AppAnimations.fast,
              opacity: 1,
              child: Text(
                i < code.length ? code[i] : '',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: i < code.length
                      ? AppColors.primaryRed
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBack,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫']
          .map((v) {
        if (v.isEmpty) return const SizedBox.shrink();
        if (v == '⌫') {
          return _KeypadButton(
            onTap: onBack,
            child: const Icon(Icons.backspace_outlined, color: AppColors.textPrimary),
          );
        }
        return _KeypadButton(
          child: Text(
            v,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: () => onDigit(v),
        );
      }).toList(),
    );
  }
}

class _KeypadButton extends StatefulWidget {
  const _KeypadButton({
    required this.child,
    required this.onTap,
  });
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(_) => setState(() => _scale = 0.93);
  void _onTapUp(_) => setState(() => _scale = 1.0);
  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 80),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.card,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
