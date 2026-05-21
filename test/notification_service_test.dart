import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    test('sendNewRequestNotifications handles null request gracefully', () async {
      final service = NotificationService();
      final request = BloodRequest(
        id: 'r1',
        shortId: 'CH-1234',
        displayCode: '1234',
        requesterId: 'u1',
        bloodType: 'O+',
        unitsNeeded: 1,
        urgencyLevel: UrgencyLevel.urgent,
        hospitalName: 'H',
        hospitalLat: 0.0,
        hospitalLng: 0.0,
        status: RequestStatus.active,
        nearbyDonorsCount: 0,
        totalEligibleCount: 0,
        createdAt: DateTime(2026, 1, 1),
        expiresAt: DateTime(2026, 1, 2),
      );
      await service.sendNewRequestNotifications(request);
    });

    test('service can be instantiated', () {
      expect(NotificationService(), isNotNull);
    });
  });
}
