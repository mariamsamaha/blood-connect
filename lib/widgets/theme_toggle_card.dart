import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloodconnect/providers/theme_mode_provider.dart';

class ThemeToggleCard extends ConsumerWidget {
  const ThemeToggleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final activeIndex = _indexForMode(themeMode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12131A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _MoonIcon(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Theme',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitleForMode(themeMode),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _Toggle(
            activeIndex: activeIndex,
            onChanged: (i) {
              final mode = _modeForIndex(i);
              ref.read(themeModeProvider.notifier).setThemeMode(mode);
            },
          ),
        ],
      ),
    );
  }

  int _indexForMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 0;
      case ThemeMode.system: return 1;
      case ThemeMode.dark: return 2;
    }
  }

  ThemeMode _modeForIndex(int index) {
    switch (index) {
      case 0: return ThemeMode.light;
      case 1: return ThemeMode.system;
      case 2: return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  String _subtitleForMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Light mode on';
      case ThemeMode.system: return 'Follow system';
      case ThemeMode.dark: return 'Dark mode on';
    }
  }
}

class _MoonIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.dark_mode_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const _Toggle({
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const segmentWidth = 47.0;
    const trackWidth = segmentWidth * 3;

    return SizedBox(
      width: trackWidth,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              left: activeIndex * segmentWidth,
              top: 0,
              width: segmentWidth,
              height: 56,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                ),
                child: Center(
                  child: _activeIcon(activeIndex),
                ),
              ),
            ),
            Row(
              children: [
                _TapSegment(
                  width: segmentWidth,
                  onTap: () => onChanged(0),
                  child: Icon(
                    Icons.light_mode_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),
                _TapSegment(
                  width: segmentWidth,
                  onTap: () => onChanged(1),
                  child: Text(
                    'Auto',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _TapSegment(
                  width: segmentWidth,
                  onTap: () => onChanged(2),
                  child: Icon(
                    Icons.dark_mode_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeIcon(int index) {
    switch (index) {
      case 0: return const Icon(Icons.light_mode_rounded, color: Colors.white, size: 20);
      case 1: return const Text('Auto', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600));
      case 2: return const Icon(Icons.dark_mode_rounded, color: Colors.white, size: 20);
      default: return const SizedBox.shrink();
    }
  }
}

class _TapSegment extends StatelessWidget {
  final double width;
  final Widget child;
  final VoidCallback onTap;

  const _TapSegment({
    required this.width,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Center(child: child),
        ),
      ),
    );
  }
}
