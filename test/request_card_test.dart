import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/widgets/request_card.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

BloodRequest _req({UrgencyLevel urgency = UrgencyLevel.urgent, double? distanceKm = 5.0, DateTime? createdAt}) => BloodRequest(
  id: 'r1', shortId: 'CH-1234', displayCode: '1234',
  requesterId: 'u1', bloodType: 'O+', unitsNeeded: 2,
  urgencyLevel: urgency, hospitalName: 'Test Hospital',
  hospitalLat: 30.0, hospitalLng: 31.0,
  status: RequestStatus.active, nearbyDonorsCount: 3,
  totalEligibleCount: 5,
  createdAt: createdAt ?? DateTime.now().subtract(const Duration(minutes: 30)),
  expiresAt: DateTime.now().add(const Duration(hours: 24)),
  distanceKm: distanceKm,
);

void main() {
  group('RequestCard', () {
    testWidgets('renders blood type and hospital name', (tester) async {
      await tester.pumpWidget(_wrap(RequestCard(
        request: _req(),
        onAccept: () {},
        onDecline: () {},
      )));
      await tester.pump();
      expect(find.text('O+'), findsOneWidget);
      expect(find.textContaining('Test Hospital'), findsOneWidget);
    });

    testWidgets('shows urgency badge', (tester) async {
      await tester.pumpWidget(_wrap(RequestCard(
        request: _req(urgency: UrgencyLevel.critical),
        onAccept: () {},
        onDecline: () {},
      )));
      await tester.pump();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('shows units count', (tester) async {
      await tester.pumpWidget(_wrap(RequestCard(
        request: _req(),
        onAccept: () {},
        onDecline: () {},
      )));
      await tester.pump();
      expect(find.text('2 units'), findsOneWidget);
    });

    testWidgets('shows Accept and Decline buttons', (tester) async {
      await tester.pumpWidget(_wrap(RequestCard(
        request: _req(),
        onAccept: () {},
        onDecline: () {},
      )));
      await tester.pump();
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('tapping Accept triggers callback', (tester) async {
      bool accepted = false;
      await tester.pumpWidget(_wrap(RequestCard(
        request: _req(),
        onAccept: () => accepted = true,
        onDecline: () {},
      )));
      await tester.pump();
      await tester.tap(find.text('Accept'));
      expect(accepted, isTrue);
    });

    testWidgets('tapping Decline triggers callback', (tester) async {
      bool declined = false;
      await tester.pumpWidget(_wrap(RequestCard(
        request: _req(),
        onAccept: () {},
        onDecline: () => declined = true,
      )));
      await tester.pump();
      await tester.tap(find.text('Decline'));
      expect(declined, isTrue);
    });

    testWidgets('shows distance in km', (tester) async {
      await tester.pumpWidget(_wrap(RequestCard(
        request: _req(distanceKm: 12.5),
        onAccept: () {},
        onDecline: () {},
      )));
      await tester.pump();
      expect(find.textContaining('12.5'), findsOneWidget);
    });

    testWidgets('hides distance when null', (tester) async {
      await tester.pumpWidget(_wrap(RequestCard(
        request: _req(distanceKm: null),
        onAccept: () {},
        onDecline: () {},
      )));
      await tester.pump();
      expect(find.textContaining('km'), findsNothing);
    });

    testWidgets('shows posted time in minutes', (tester) async {
      await tester.pumpWidget(_wrap(RequestCard(
        request: _req(createdAt: DateTime.now().subtract(const Duration(minutes: 15))),
        onAccept: () {},
        onDecline: () {},
      )));
      await tester.pump();
      expect(find.textContaining('min ago'), findsOneWidget);
    });
  });
}
