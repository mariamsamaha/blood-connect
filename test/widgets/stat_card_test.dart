import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/widgets/stat_card.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  group('StatCard', () {
    testWidgets('renders title and value', (tester) async {
      await tester.pumpWidget(_wrap(const StatCard(
        title: 'Today',
        value: '42',
        icon: Icons.today_rounded,
      )));
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(_wrap(const StatCard(
        title: 'Pending',
        value: '3',
        icon: Icons.pending_actions_rounded,
      )));
      expect(find.byIcon(Icons.pending_actions_rounded), findsOneWidget);
    });

    testWidgets('handles large numbers', (tester) async {
      await tester.pumpWidget(_wrap(const StatCard(
        title: 'Total',
        value: '999999',
        icon: Icons.numbers_rounded,
      )));
      expect(find.text('999999'), findsOneWidget);
    });

    testWidgets('handles empty string value', (tester) async {
      await tester.pumpWidget(_wrap(const StatCard(
        title: 'None',
        value: '',
        icon: Icons.help_rounded,
      )));
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('handles zero value', (tester) async {
      await tester.pumpWidget(_wrap(const StatCard(
        title: 'Empty',
        value: '0',
        icon: Icons.circle_rounded,
      )));
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('handles long title text without overflow', (tester) async {
      await tester.pumpWidget(_wrap(const StatCard(
        title: 'Very Long Title Text That Should Fit',
        value: '5',
        icon: Icons.star_rounded,
      )));
      expect(find.text('Very Long Title Text That Should Fit'), findsOneWidget);
    });
  });
}
