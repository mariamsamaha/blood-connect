import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/widgets/section_header.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  group('SectionHeader', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'Nearby Requests')));
      expect(find.text('Nearby Requests'), findsOneWidget);
    });

    testWidgets('renders with action widget', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(
        title: 'History',
        action: Text('See All'),
      )));
      expect(find.text('History'), findsOneWidget);
      expect(find.text('See All'), findsOneWidget);
    });

    testWidgets('does not render action when null', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'Title')));
      expect(find.text('Title'), findsOneWidget);
    });
  });
}
