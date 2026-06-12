import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/providers/theme_mode_provider.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:bloodconnect/widgets/theme_toggle_card.dart';
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
    final profile =
        await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
    if (profile == null || !mounted) return;
    setState(() {
      _profile = profile;
      _notificationsEnabled = profile.notificationEnabled;
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
            content: Text(
              'Could not get location. Enable location in settings.',
            ),
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

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account, donation history, and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).deleteJson('/api/v1/users/me');
      await ref.read(authServiceProvider).signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e')),
      );
    }
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Icon(Icons.bloodtype, color: AppColors.primaryRed, size: 28),
            const SizedBox(width: 10),
            const Text('BloodConnect'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version 1.0.0',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            SizedBox(height: 16),
            Text(
              'BloodConnect is a community-driven platform that connects blood donors with recipients and hospitals in real time.',
            ),
            SizedBox(height: 12),
            Text(
              'Our mission is to make blood donation faster, smarter, and more accessible for everyone.',
            ),
            SizedBox(height: 16),
            Text(
              'Made with ❤️ to save lives.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out?'),
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
                _SettingsGroup(
                  title: 'Notifications',
                  children: [
                    _SettingsTile(
                      title: 'Push Notifications',
                      subtitle: 'Receive alerts for new blood requests',
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: (v) =>
                            setState(() => _notificationsEnabled = v),
                      ),
                    ),
                    if (_notificationsEnabled) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                if (profile?.role == UserRole.donor)
                  _SettingsGroup(
                    title: 'Donor Status',
                    children: [
                      _SettingsTile(
                        title: 'Available to Donate',
                        subtitle: _donorAvailable
                            ? 'You will appear in donor searches'
                            : 'You are hidden from donor searches',
                        trailing: Switch(
                          value: _donorAvailable,
                          onChanged: (v) =>
                              setState(() => _donorAvailable = v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        title: 'Matching Location',
                        subtitle:
                            'Update where you are available to donate from',
                        trailing: TextButton(
                          onPressed:
                              _updatingLocation ? null : _updateLocation,
                          child: Text(
                            _updatingLocation ? 'Updating...' : 'Update',
                            style:
                                const TextStyle(color: AppColors.primaryRed),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                _SettingsGroup(
                  title: 'Account',
                  children: [
                    _SettingsTile(
                      title: 'Email',
                      subtitle: profile?.email ?? '\u2014',
                      trailing: null,
                    ),
                    const SizedBox(height: 8),
                    _SettingsTile(
                      title: 'Role',
                      subtitle: profile?.role.name ?? '\u2014',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppRadius.full,
                          ),
                        ),
                        child: Text(
                          profile?.role.name ?? '',
                          style: const TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ThemeToggleCard(
                  key: const ValueKey('theme_toggle'),
                ),
                const SizedBox(height: 16),
                _SettingsGroup(
                  title: 'About',
                  children: [
                    _SettingsTile(
                      title: 'About BloodConnect',
                      subtitle: 'Version 1.0.0',
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                      onTap: _showAbout,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                AppButton.secondary(
                  label: 'Sign Out',
                  onPressed: _signOut,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _deleteAccount,
                    child: const Text(
                      'Delete Account',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: AppShadows.card,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
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
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
