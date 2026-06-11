import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);
    final user = auth.currentUser;
    if (user != null) {
      final profile = await userService.getProfileByFirebaseUid(user.uid);
      if (mounted) setState(() => _profile = profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDonor = _profile?.role == UserRole.donor;
    final nav = widget.navigationShell;

    return Scaffold(
      body: nav,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: nav.currentIndex.clamp(0, isDonor ? 2 : 1),
        onTap: (index) {
          final tabCount = isDonor ? 3 : 2;
          if (index < tabCount) {
            nav.goBranch(index, initialLocation: index == nav.currentIndex);
          } else {
            context.push('/profile');
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_rounded),
            label: 'Stories',
          ),
          if (isDonor)
            const BottomNavigationBarItem(
              icon: Icon(Icons.local_offer_rounded),
              label: 'Rewards',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
