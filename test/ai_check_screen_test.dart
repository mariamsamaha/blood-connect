import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/screens/ai_check_screen.dart';

Widget _wrap(Widget w) => MaterialApp(home: w);

void main() {
  group('AiCheckScreen', () {
    testWidgets('renders coming soon message', (tester) async {
      await tester.pumpWidget(_wrap(const AiCheckScreen()));
      expect(find.text('AI Health Check'), findsOneWidget);
      expect(find.textContaining('coming'), findsWidgets);
    });
  });
}
