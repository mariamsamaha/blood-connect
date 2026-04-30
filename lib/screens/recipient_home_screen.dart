import 'dart:async';

import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Widget structure:
/// - Scaffold
///   - RefreshIndicator
///     - If no active request: hero card + how-it-works section
///     - If active request: status card, progress bar, donor info, countdown, cancel
///     - Request history list
///   - BottomNavigationBar (Home, Schedule, Profile)
class RecipientHomeScreen extends ConsumerStatefulWidget {
  const RecipientHomeScreen({super.key});
  @override
  ConsumerState<RecipientHomeScreen> createState() => _RecipientHomeScreenState();
}

class _RecipientHomeScreenState extends ConsumerState<RecipientHomeScreen> {
  BloodRequest? _active;
  List<BloodRequest> _history = const [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _active != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final requestService = ref.read(requestServiceProvider);
      final user = auth.currentUser;
      if (user == null) return;
      final profile = await userService.getProfileByFirebaseUid(user.uid);
      if (profile == null) return;
      final active = await requestService.getActiveRequest(profile.id);
      final all = await requestService.getMyRequests(profile.id);
      if (!mounted) return;
      setState(() {
        _active = active;
        _history = all.where((e) => active == null || e.id != active.id).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    final r = _active;
    if (r == null) return;
    final auth = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);
    final requestService = ref.read(requestServiceProvider);
    final user = auth.currentUser;
    if (user == null) return;
    final profile = await userService.getProfileByFirebaseUid(user.uid);
    if (profile == null) return;
    final ok = await requestService.cancelRequest(r.id, profile.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Request cancelled' : 'Unable to cancel request')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: _loading
              ? const [SizedBox(height: 400)]
              : [
                  if (_active == null) ...[
                    _HeroCreateCard(onCreate: () => context.push('/create-request')),
                    const SizedBox(height: 24),
                    const _HowItWorks(),
                  ] else ...[
                    _ActiveRequestCard(request: _active!, onCancel: _cancel),
                  ],
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Request History'),
                  const SizedBox(height: 12),
                  if (_history.isEmpty)
                    const _HistoryEmpty()
                  else
                    ..._history.map((r) => _HistoryItem(request: r)),
                ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) context.go('/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HeroCreateCard extends StatelessWidget {
  const _HeroCreateCard({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [AppColors.primaryRed, AppColors.deepRed]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Need Blood?', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 6),
        const Text('Create an urgent request and notify compatible donors.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        AppButton.primary(label: 'Create Request', onPressed: onCreate),
      ]),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How it works'),
        SizedBox(height: 12),
        _Step(icon: Icons.edit_note_rounded, title: '1. Post request'),
        _Step(icon: Icons.travel_explore_rounded, title: '2. Match nearby donors'),
        _Step(icon: Icons.verified_rounded, title: '3. Hospital verifies donation'),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [Icon(icon), const SizedBox(width: 8), Text(title)]),
      );
}

class _ActiveRequestCard extends StatelessWidget {
  const _ActiveRequestCard({required this.request, required this.onCancel});
  final BloodRequest request;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final seconds = request.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999999);
    final hh = (seconds ~/ 3600).toString().padLeft(2, '0');
    final mm = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    final progress = request.status == RequestStatus.active ? 0.45 : 0.85;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(request.shortId, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Chip(label: Text(request.status == RequestStatus.active ? '🔍 Finding Donors' : '✅ Donor Accepted')),
        const SizedBox(height: 8),
        Text('${request.hospitalName} • ${request.bloodType} • ${request.unitsNeeded} units'),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(999)),
        const SizedBox(height: 10),
        if (request.status == RequestStatus.in_progress)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: const ValueKey('donor-info'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFEEF7FF), borderRadius: BorderRadius.circular(12)),
              child: const Text('Donor is on the way to hospital.'),
            ),
          ),
        const SizedBox(height: 8),
        Text('Expires in $hh:$mm:$ss', style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        AppButton.secondary(label: 'Cancel Request', onPressed: onCancel),
      ]),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.request});
  final BloodRequest request;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(child: Text(request.shortId)),
        Chip(label: Text(request.status.name)),
      ]),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: const Column(children: [
        Icon(Icons.inbox_rounded, size: 40),
        SizedBox(height: 8),
        Text('No previous requests yet'),
      ]),
    );
  }
}

