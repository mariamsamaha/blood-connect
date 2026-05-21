import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/widgets/urgency_badge.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  group('UrgencyBadge', () {
    testWidgets('renders CRITICAL with red color', (tester) async {
      await tester.pumpWidget(_wrap(const UrgencyBadge(level: UrgencyLevel.critical)));
      expect(find.text('CRITICAL'), findsOneWidget);
    });

    testWidgets('renders URGENT with orange color', (tester) async {
      await tester.pumpWidget(_wrap(const UrgencyBadge(level: UrgencyLevel.urgent)));
      expect(find.text('URGENT'), findsOneWidget);
    });

    testWidgets('renders ROUTINE with blue color', (tester) async {
      await tester.pumpWidget(_wrap(const UrgencyBadge(level: UrgencyLevel.routine)));
      expect(find.text('ROUTINE'), findsOneWidget);
    });
  });
}
