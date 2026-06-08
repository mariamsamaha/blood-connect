import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/widgets/blood_type_chip.dart';
import 'package:bloodconnect/widgets/urgency_badge.dart';
import 'package:bloodconnect/widgets/stat_card.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/app_text_field.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  group('BloodTypeChip', () {
    testWidgets('renders blood type text', (tester) async {
      await tester.pumpWidget(_wrap(const BloodTypeChip(type: 'O+', selected: false)));
      expect(find.text('O+'), findsOneWidget);
    });

    testWidgets('shows selected state with different styling', (tester) async {
      await tester.pumpWidget(_wrap(const BloodTypeChip(type: 'A-', selected: true)));
      expect(find.text('A-'), findsOneWidget);
    });

    testWidgets('triggers onTap when pressed', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_wrap(BloodTypeChip(
        type: 'B+',
        selected: false,
        onTap: () => tapped = true,
      )));
      await tester.tap(find.text('B+'));
      expect(tapped, isTrue);
    });
  });

  group('UrgencyBadge', () {
    testWidgets('renders heart icon', (tester) async {
      await tester.pumpWidget(_wrap(const UrgencyBadge(level: UrgencyLevel.critical)));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('renders container with heart icon for routine', (tester) async {
      await tester.pumpWidget(_wrap(const UrgencyBadge(level: UrgencyLevel.routine)));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('renders container with heart icon for urgent', (tester) async {
      await tester.pumpWidget(_wrap(const UrgencyBadge(level: UrgencyLevel.urgent)));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });

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
  });

  group('AppButton', () {
    testWidgets('renders primary button label', (tester) async {
      await tester.pumpWidget(_wrap(AppButton.primary(
        label: 'Submit',
        onPressed: () {},
      )));
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('renders secondary button label', (tester) async {
      await tester.pumpWidget(_wrap(AppButton.secondary(
        label: 'Cancel',
        onPressed: () {},
      )));
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('triggers onPressed when tapped', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(_wrap(AppButton.primary(
        label: 'Tap Me',
        onPressed: () => pressed = true,
      )));
      await tester.tap(find.text('Tap Me'));
      expect(pressed, isTrue);
    });

    testWidgets('renders disabled button', (tester) async {
      await tester.pumpWidget(_wrap(AppButton.primary(
        label: 'Disabled',
        onPressed: null,
      )));
      expect(find.text('Disabled'), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('renders label and hint', (tester) async {
      await tester.pumpWidget(_wrap(AppTextField(
        controller: TextEditingController(),
        label: 'Name',
        hint: 'Enter your name',
      )));
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Enter your name'), findsOneWidget);
    });
  });
}
