import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/app_text_field.dart';
import 'package:bloodconnect/widgets/blood_type_chip.dart';

/// Widget structure:
/// - Scaffold
///   - Progress indicator
///   - Step 1 role cards + hospital link
///   - Step 2 profile details + blood chips + location card
///   - Fixed bottom CTA
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
  bool _loading = false;
  double? _lat;
  double? _lng;
  final _bloodTypes = const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
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
    final pos = await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _lat = pos?.latitude;
      _lng = pos?.longitude;
    });
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user');
      final profile = await ref.read(userServiceProvider).createCompleteProfile(
            user,
            name: _name.text.trim(),
            email: user.email ?? '',
            phone: _phone.text.trim(),
            bloodType: _hospital ? '' : _blood,
            role: _hospital ? 'hospital' : _role,
            accountType: _hospital ? 'hospital' : 'regular',
            cityArea: _city.text.trim(),
            latitude: _lat,
            longitude: _lng,
            hospitalName: _hospital ? _name.text.trim() : null,
            hospitalCode: _hospital ? 'HSP' : null,
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
          LinearProgressIndicator(
            value: (_step + 1) / 2,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 6),
          Text('Step ${_step + 1} of 2', style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          if (!isStep2) ...[
            Row(children: [
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
            ]),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _hospital = !_hospital),
              child: Text(_hospital ? 'Not a hospital?' : 'Are you a hospital?'),
            ),
          ] else ...[
            AppTextField(controller: _name, label: 'Full Name', icon: Icons.person_outline_rounded),
            const SizedBox(height: 16),
            AppTextField(controller: _phone, label: 'Phone', keyboardType: TextInputType.phone, icon: Icons.phone_outlined),
            const SizedBox(height: 16),
            if (!_hospital) ...[
              const Text('Blood Type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bloodTypes.map((e) => BloodTypeChip(type: e, selected: _blood == e, onTap: () => setState(() => _blood = e))).toList(),
              ),
              const SizedBox(height: 16),
            ],
            AppTextField(controller: _city, label: 'City Area', icon: Icons.place_outlined),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.location_pin), SizedBox(width: 8), Text('Allow location for better matching')]),
                const SizedBox(height: 10),
                Text(_lat == null ? 'Location not enabled yet' : '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: AppButton.primary(label: 'Enable', onPressed: _fetchLocation)),
                  const SizedBox(width: 8),
                  Expanded(child: AppButton.secondary(label: 'Skip', onPressed: () {})),
                ]),
              ]),
            ),
          ],
        ],
      ),
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, border: const Border(top: BorderSide(color: AppColors.divider))),
          child: AppButton.primary(
            label: isStep2 ? 'Create Account' : 'Continue',
            isLoading: _loading,
            onPressed: isStep2 ? _submit : () => setState(() => _step = 1),
          ),
        ),
      ),
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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primaryRed : AppColors.divider, width: selected ? 1.6 : 1),
          color: selected ? const Color(0xFFFFF1F3) : Theme.of(context).cardColor,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: selected ? AppColors.primaryRed : AppColors.textSecondary),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

