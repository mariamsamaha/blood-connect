import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/widgets/badge_card.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  group('BadgeCard', () {
    testWidgets('renders emoji icon and name', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeCard(
        icon: '\u{1F3C6}',
        name: 'First Donation',
        earned: false,
      )));
      expect(find.text('First Donation'), findsOneWidget);
    });

    testWidgets('earned badge shows name', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeCard(
        icon: '\u{1F3C6}',
        name: 'Earned',
        earned: true,
      )));
      expect(find.text('Earned'), findsOneWidget);
    });

    testWidgets('unearned badge has reduced opacity', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeCard(
        icon: '\u{1F3C6}',
        name: 'Locked',
        earned: false,
      )));
      expect(find.text('Locked'), findsOneWidget);
    });

    testWidgets('unearned badge shows progress bar', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeCard(
        icon: '\u{1F3C6}',
        name: 'Progress Badge',
        earned: false,
        progress: 0.5,
      )));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('earned badge does not show progress bar', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeCard(
        icon: '\u{1F3C6}',
        name: 'Done',
        earned: true,
      )));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows progress label when provided', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeCard(
        icon: '\u{1F3C6}',
        name: 'Badge',
        earned: false,
        progress: 0.3,
        progressLabel: '3/10',
      )));
      expect(find.text('3/10'), findsOneWidget);
    });

    testWidgets('handles URL icon gracefully', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeCard(
        icon: 'https://example.com/icon.png',
        name: 'URL Badge',
        earned: true,
      )));
      expect(find.text('URL Badge'), findsOneWidget);
    });
  });
}
