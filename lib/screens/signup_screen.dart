import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/app_text_field.dart';
import 'package:bloodconnect/widgets/blood_type_chip.dart';
import 'package:bloodconnect/widgets/location_map_picker.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  int _step = 0;
  bool _hospital = false;
  String _role = 'donor';
  String _blood = 'A+';
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  DateTime? _dateOfBirth;
  bool _loading = false;
  bool _locating = false;
  double? _lat;
  double? _lng;
  final _bloodTypes = const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    final u = ref.read(authServiceProvider).currentUser;
    if (u != null) _name.text = u.displayName ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await ref.read(locationServiceProvider).getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = pos?.latitude;
        _lng = pos?.longitude;
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  static String _generateHospitalCode(String name) {
    final clean = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final prefix = clean.length >= 3
        ? clean.substring(0, 3)
        : clean.padRight(3, 'X');
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final shortSuffix = suffix.substring(suffix.length - 5);
    return '$prefix$shortSuffix';
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('No authenticated user');
      if (!_hospital && _dateOfBirth == null) {
        throw Exception('Please enter your date of birth');
      }
      final profile = await ref
          .read(userServiceProvider)
          .createCompleteProfile(
            user,
            name: _name.text.trim(),
            email: user.email ?? '',
            phone: _phone.text.trim(),
            bloodType: _hospital ? '' : _blood,
            role: _hospital ? 'hospital' : _role,
            accountType: _hospital ? 'hospital' : 'regular',
            dateOfBirth: _dateOfBirth?.toIso8601String().split('T')[0],
            cityArea: _city.text.trim(),
            latitude: _lat,
            longitude: _lng,
            hospitalName: _hospital ? _name.text.trim() : null,
            hospitalCode: _hospital
                ? _generateHospitalCode(_name.text.trim())
                : null,
          );
      if (!mounted) return;
      context.go(profile.homeRoute);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStep2 = _step == 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.full),
              color: AppColors.divider,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: AppAnimations.medium,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: _step >= 0 ? AppGradients.primary : null,
                      color: _step >= 0 ? null : Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: AnimatedContainer(
                    duration: AppAnimations.medium,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: _step >= 1 ? AppGradients.primary : null,
                      color: _step >= 1 ? null : Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Step ${_step + 1} of 2',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppAnimations.medium,
                builder: (context, value, child) {
                  return Text(
                    '${(value * 50).round()}%',
                    style: TextStyle(
                      color: AppColors.primaryRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: AppAnimations.medium,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: !isStep2 ? _buildRoleSelection() : _buildDetailsForm(),
          ),
        ],
      ),
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: const Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              if (isStep2)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AppButton.secondary(
                    label: 'Back',
                    onPressed: () => setState(() => _step = 0),
                    size: ButtonSize.md,
                  ),
                ),
              Expanded(
                child: AppButton.primary(
                  label: isStep2 ? 'Create Account' : 'Continue',
                  isLoading: _loading,
                  onPressed: isStep2
                      ? _submit
                      : () => setState(() => _step = 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What brings you here?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _RoleCard(
                icon: Icons.bloodtype_rounded,
                title: 'I Want to Donate',
                subtitle: 'Help save lives by donating blood',
                selected: _role == 'donor',
                onTap: () => setState(() => _role = 'donor'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RoleCard(
                icon: Icons.favorite_rounded,
                title: 'I Need Blood',
                subtitle: 'Request blood for yourself or loved one',
                selected: _role == 'recipient',
                onTap: () => setState(() => _role = 'recipient'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _hospital = !_hospital),
            child: Text(
              _hospital ? 'Not a hospital?' : 'Are you a hospital?',
              style: const TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fill in your details',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        AppTextField(
          controller: _name,
          label: 'Full Name',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _phone,
          label: 'Phone',
          keyboardType: TextInputType.phone,
          icon: Icons.phone_outlined,
        ),
        const SizedBox(height: 16),
        if (!_hospital) ...[
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: now.subtract(
                  const Duration(days: 6570),
                ), // ~18 years
                firstDate: now.subtract(
                  const Duration(days: 36525),
                ), // ~100 years
                lastDate: now.subtract(
                  const Duration(days: 6570),
                ), // 18 years ago
                helpText: 'Select your date of birth',
              );
              if (picked != null) {
                setState(() => _dateOfBirth = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cake_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _dateOfBirth != null
                        ? '${_dateOfBirth!.month}/${_dateOfBirth!.day}/${_dateOfBirth!.year}'
                        : 'Date of Birth',
                    style: TextStyle(
                      color: _dateOfBirth != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (!_hospital) ...[
          Text(
            'Blood Type',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bloodTypes
                .map(
                  (e) => BloodTypeChip(
                    type: e,
                    selected: _blood == e,
                    onTap: () => setState(() => _blood = e),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        AppTextField(
          controller: _city,
          label: 'City Area',
          icon: Icons.place_outlined,
        ),
        const SizedBox(height: 16),
        LocationMapPicker(
          title: 'Your Location',
          subtitle: 'Tap the map to adjust your matching area',
          latitude: _lat,
          longitude: _lng,
          isLocating: _locating,
          actionLabel: 'Use my current location',
          onUseCurrentLocation: _fetchLocation,
          onLocationChanged: (location) {
            setState(() {
              _lat = location.latitude;
              _lng = location.longitude;
            });
          },
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: AppAnimations.medium,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.primaryRed : AppColors.divider,
            width: selected ? 1.6 : 1,
          ),
          color: selected ? AppColors.softRed : Theme.of(context).cardColor,
          boxShadow: selected ? AppShadows.primary : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryRed.withValues(alpha: 0.15)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                color: selected
                    ? AppColors.primaryRed
                    : AppColors.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: selected ? AppColors.primaryRed : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
