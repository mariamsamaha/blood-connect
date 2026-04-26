import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/hospital_request_match.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Widget structure:
/// - Scaffold
///   - Header card (hospital name/code/verified)
///   - Stats row
///   - Verification section (4 digit boxes + keypad + verify card)
///   - Active requests list
class HospitalDashboardScreen extends ConsumerStatefulWidget {
  const HospitalDashboardScreen({super.key});
  @override
  ConsumerState<HospitalDashboardScreen> createState() => _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState extends ConsumerState<HospitalDashboardScreen> {
  String _code = '';
  HospitalRequestMatch? _match;
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    final profile = await ref.read(userServiceProvider).getProfileByFirebaseUid(user.uid);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _searchCode() async {
    if (_code.length != 4 || _profile == null) return;
    final list = await ref.read(hospitalServiceProvider).searchByDisplayCode(
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Donation verified')));
    if (err == null) {
      setState(() {
        _code = '';
        _match = null;
      });
    }
  }

  void _tapDigit(String d) {
    if (_code.length >= 4) return;
    setState(() => _code += d);
    if (_code.length == 4) _searchCode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _Header(profile: _profile),
                const SizedBox(height: 16),
                const Row(children: [
                  Expanded(child: StatCard(title: 'Today', value: '0', icon: Icons.today_rounded)),
                  SizedBox(width: 10),
                  Expanded(child: StatCard(title: 'Pending', value: '0', icon: Icons.pending_actions_rounded)),
                  SizedBox(width: 10),
                  Expanded(child: StatCard(title: 'Fulfilled', value: '0', icon: Icons.verified_rounded)),
                ]),
                const SizedBox(height: 20),
                const Text('Enter 4-digit request code'),
                const SizedBox(height: 10),
                _OtpBoxes(code: _code),
                const SizedBox(height: 12),
                _Keypad(onDigit: _tapDigit, onBack: () => setState(() => _code = _code.isEmpty ? '' : _code.substring(0, _code.length - 1))),
                if (_match != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_match!.request.shortId, style: Theme.of(context).textTheme.titleLarge),
                      Text('${_match!.request.bloodType} • ${_match!.request.unitsNeeded} units'),
                      Text('Donor: ${_match!.donorName ?? 'Not yet accepted'}'),
                      const SizedBox(height: 10),
                      AppButton.primary(label: 'Verify Donation', onPressed: _verify),
                    ]),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) context.go('/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});
  final UserProfile? profile;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const Icon(Icons.local_hospital_rounded, color: AppColors.primaryRed),
        const SizedBox(width: 10),
        Expanded(child: Text(profile?.hospitalName ?? 'Hospital')),
        Chip(label: Text(profile?.hospitalCode ?? '-')),
        const Icon(Icons.verified_rounded, color: AppColors.success),
      ]),
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
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(12)),
            child: Text(i < code.length ? code[i] : '', style: Theme.of(context).textTheme.headlineMedium),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBack});
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    Widget key(String t) => InkWell(
          onTap: () => onDigit(t),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
            child: Text(t),
          ),
        );
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'].map((v) {
        if (v.isEmpty) return const SizedBox.shrink();
        if (v == '⌫') return InkWell(onTap: onBack, child: Container(alignment: Alignment.center, child: const Icon(Icons.backspace_outlined)));
        return key(v);
      }).toList(),
    );
  }
}

