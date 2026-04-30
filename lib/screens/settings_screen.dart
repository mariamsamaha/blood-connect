import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;

  bool _notificationsEnabled = true;
  double _radiusKm = 25;
  bool _donorAvailable = true;
  bool _updatingLocation = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authServiceProvider).currentUser;
    if (auth == null) return;
    final profile = await ref
        .read(userServiceProvider)
        .getProfileByFirebaseUid(auth.uid);
    if (profile == null || !mounted) return;
    setState(() {
      _profile = profile;
      _notificationsEnabled = profile.notificationEnabled;
      _radiusKm = profile.notificationRadiusKm.toDouble();
      _donorAvailable = profile.donorStatus == DonorStatus.available;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final profile = _profile;
    if (profile == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(userServiceProvider).updateProfile(
        firebaseUid: profile.firebaseUid,
        updates: {
          'notification_enabled': _notificationsEnabled,
          'notification_radius_km': _radiusKm.round(),
          'donor_status': _donorAvailable ? 'available' : 'unavailable',
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateLocation() async {
    final profile = _profile;
    if (profile == null) return;
    setState(() => _updatingLocation = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final pos = await locationService.getCurrentPosition();
      if (pos == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get location. Enable location in settings.'),
          ),
        );
        return;
      }
      await ref.read(userServiceProvider).updateLocation(
        firebaseUid: profile.firebaseUid,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location updated to '
            '${pos.latitude.toStringAsFixed(4)}, '
            '${pos.longitude.toStringAsFixed(4)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update location: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingLocation = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authServiceProvider).signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? 'Saving...' : 'Save',
              style: const TextStyle(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SectionHeader(title: 'Notifications'),
                const SizedBox(height: 12),
                _SettingsTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive alerts for new blood requests',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (v) =>
                        setState(() => _notificationsEnabled = v),
                    activeTrackColor: AppColors.primaryRed,
                  ),
                ),
                const SizedBox(height: 12),
                if (_notificationsEnabled) ...[
                  _SettingsTile(
                    title: 'Search Radius',
                    subtitle:
                        'Notify me for requests within ${_radiusKm.round()} km',
                    trailing: null,
                  ),
                  Slider(
                    value: _radiusKm,
                    min: 5,
                    max: 120,
                    divisions: 23,
                    label: '${_radiusKm.round()} km',
                    activeColor: AppColors.primaryRed,
                    onChanged: (v) => setState(() => _radiusKm = v),
                  ),
                  const SizedBox(height: 12),
                ],

                if (profile?.role == UserRole.donor) ...[
                  const SectionHeader(title: 'Donor Status'),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    title: 'Available to Donate',
                    subtitle: _donorAvailable
                        ? 'You will appear in donor searches'
                        : 'You are hidden from donor searches',
                    trailing: Switch(
                      value: _donorAvailable,
                      onChanged: (v) =>
                          setState(() => _donorAvailable = v),
                      activeTrackColor: AppColors.primaryRed,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    title: 'Matching Location',
                    subtitle: 'Update where you are available to donate from',
                    trailing: TextButton(
                      onPressed: _updatingLocation ? null : _updateLocation,
                      child: Text(
                        _updatingLocation ? 'Updating...' : 'Update',
                        style: const TextStyle(color: AppColors.primaryRed),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const SectionHeader(title: 'Account'),
                const SizedBox(height: 12),
                _SettingsTile(
                  title: 'Email',
                  subtitle: profile?.email ?? '—',
                  trailing: null,
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  title: 'Role',
                  subtitle: profile?.role.name ?? '—',
                  trailing: null,
                ),
                const SizedBox(height: 32),

                AppButton.secondary(
                  label: 'Sign Out',
                  onPressed: _signOut,
                ),
                const SizedBox(height: 12),

                Center(
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Contact support to delete your account',
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Delete Account',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}