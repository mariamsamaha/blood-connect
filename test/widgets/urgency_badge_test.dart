import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/widgets/urgency_badge.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  group('UrgencyBadge', () {
    testWidgets('renders heart icon', (tester) async {
      await tester.pumpWidget(_wrap(const UrgencyBadge(level: UrgencyLevel.critical)));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('renders circle container', (tester) async {
      await tester.pumpWidget(_wrap(const UrgencyBadge(level: UrgencyLevel.routine)));
      expect(find.byType(Container), findsAtLeastNWidgets(1));
    });

    testWidgets('critical has scale animation', (tester) async {
      await tester.pumpWidget(_wrap(const UrgencyBadge(level: UrgencyLevel.critical)));
      expect(find.byType(ScaleTransition), findsAtLeastNWidgets(1));
    });

    testWidgets('urgent has scale animation', (tester) async {
      await tester.pumpWidget(_wrap(const UrgencyBadge(level: UrgencyLevel.urgent)));
      expect(find.byType(ScaleTransition), findsAtLeastNWidgets(1));
    });

    testWidgets('routine has scale animation (static)', (tester) async {
      await tester.pumpWidget(_wrap(const UrgencyBadge(level: UrgencyLevel.routine)));
      expect(find.byType(ScaleTransition), findsAtLeastNWidgets(1));
    });
  });
}
