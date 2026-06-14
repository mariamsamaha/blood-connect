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
    final items = <_ShellNavItem>[
      const _ShellNavItem(
        branchIndex: 0,
        icon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      if (isDonor)
        const _ShellNavItem(
          branchIndex: 1,
          icon: _MapDiscoverIcon(),
          activeIcon: _MapDiscoverIcon(isActive: true),
          label: 'Map',
        ),
      const _ShellNavItem(
        branchIndex: 2,
        icon: Icon(Icons.auto_stories_rounded),
        label: 'Stories',
      ),
      if (isDonor)
        const _ShellNavItem(
          branchIndex: 3,
          icon: Icon(Icons.local_offer_rounded),
          label: 'Rewards',
        ),
      const _ShellNavItem(
        branchIndex: null,
        icon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];
    final currentIndex = items.indexWhere(
      (item) => item.branchIndex == nav.currentIndex,
    );

    return Scaffold(
      body: nav,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex == -1 ? items.length - 1 : currentIndex,
        onTap: (index) {
          final branchIndex = items[index].branchIndex;
          if (branchIndex != null) {
            nav.goBranch(
              branchIndex,
              initialLocation: branchIndex == nav.currentIndex,
            );
          } else {
            context.push('/profile');
          }
        },
        items: items
            .map(
              (item) => BottomNavigationBarItem(
                icon: item.icon,
                activeIcon: item.activeIcon,
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ShellNavItem {
  const _ShellNavItem({
    required this.branchIndex,
    required this.icon,
    required this.label,
    this.activeIcon,
  });

  final int? branchIndex;
  final Widget icon;
  final Widget? activeIcon;
  final String label;
}

class _MapDiscoverIcon extends StatelessWidget {
  const _MapDiscoverIcon({this.isActive = false});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 44,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(Icons.map_rounded, color: isActive ? scheme.primary : null),
          Positioned(
            right: -4,
            top: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'NEW',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
