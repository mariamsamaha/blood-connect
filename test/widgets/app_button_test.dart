import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/widgets/app_button.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  group('AppButton - primary', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(_wrap(AppButton.primary(
        label: 'Submit',
        onPressed: () {},
      )));
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('triggers onPressed when enabled', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(_wrap(AppButton.primary(
        label: 'Tap Me',
        onPressed: () => pressed = true,
      )));
      await tester.tap(find.text('Tap Me'));
      expect(pressed, isTrue);
    });

    testWidgets('does not trigger when onPressed is null', (tester) async {
      await tester.pumpWidget(_wrap(AppButton.primary(
        label: 'Disabled',
        onPressed: null,
      )));
      expect(find.text('Disabled'), findsOneWidget);
    });
  });

  group('AppButton - secondary', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(_wrap(AppButton.secondary(
        label: 'Cancel',
        onPressed: () {},
      )));
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('triggers onPressed when tapped', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(_wrap(AppButton.secondary(
        label: 'Cancel',
        onPressed: () => pressed = true,
      )));
      await tester.tap(find.text('Cancel'));
      expect(pressed, isTrue);
    });
  });

  group('AppButton - loading', () {
    testWidgets('shows CircularProgressIndicator when loading', (tester) async {
      await tester.pumpWidget(_wrap(AppButton.primary(
        label: 'Saving',
        onPressed: () {},
        isLoading: true,
      )));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('does not trigger onPressed when loading', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(_wrap(AppButton.primary(
        label: 'Saving',
        onPressed: () => pressed = true,
        isLoading: true,
      )));
      await tester.tap(find.byType(CircularProgressIndicator).last);
      expect(pressed, isFalse);
    });
  });
}
