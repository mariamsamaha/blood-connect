import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/donor_assignment.dart';
import 'package:bloodconnect/models/donor_response_entry.dart';
import 'package:bloodconnect/models/hospital.dart';
import 'package:bloodconnect/models/pending_mutation.dart';

void main() {
  group('BloodRequest computed properties', () {
    BloodRequest _make({required RequestStatus status}) => BloodRequest(
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
      status: status,
      nearbyDonorsCount: 0,
      totalEligibleCount: 0,
      createdAt: DateTime(2026, 1, 1),
      expiresAt: DateTime(2026, 1, 2),
    );

    test('mvpPrimaryStatusLabel returns Open for active', () {
      expect(_make(status: RequestStatus.active).mvpPrimaryStatusLabel, 'Open');
    });

    test('mvpPrimaryStatusLabel returns Donor accepted for in_progress', () {
      expect(_make(status: RequestStatus.in_progress).mvpPrimaryStatusLabel, 'Donor accepted');
    });

    test('mvpPrimaryStatusLabel returns Verified / closed for fulfilled', () {
      expect(_make(status: RequestStatus.fulfilled).mvpPrimaryStatusLabel, 'Verified / closed');
    });

    test('mvpPrimaryStatusLabel returns Cancelled for cancelled', () {
      expect(_make(status: RequestStatus.cancelled).mvpPrimaryStatusLabel, 'Cancelled');
    });

    test('mvpPrimaryStatusLabel returns Expired for expired', () {
      expect(_make(status: RequestStatus.expired).mvpPrimaryStatusLabel, 'Expired');
    });

    test('mvpSecondaryStatusLabel returns Matching nearby donors for active', () {
      expect(_make(status: RequestStatus.active).mvpSecondaryStatusLabel, 'Matching nearby donors');
    });

    test('mvpSecondaryStatusLabel returns null for non-active statuses', () {
      expect(_make(status: RequestStatus.fulfilled).mvpSecondaryStatusLabel, isNull);
      expect(_make(status: RequestStatus.cancelled).mvpSecondaryStatusLabel, isNull);
      expect(_make(status: RequestStatus.expired).mvpSecondaryStatusLabel, isNull);
    });
  });

  group('BloodRequest.fromJson displayCode', () {
    test('extracts display code from short_id after hyphen', () {
      final json = {
        'id': 'r1', 'short_id': 'CH-20260216-2695', 'requester_id': 'u1',
        'blood_type': 'O+', 'units_needed': 1, 'urgency_level': 'routine',
        'hospital_name': 'H', 'hospital_lat': 0.0, 'hospital_lng': 0.0,
        'status': 'active', 'nearby_donors_count': 0, 'total_eligible_count': 0,
        'created_at': '2026-01-01', 'expires_at': '2026-01-02',
      };
      final request = BloodRequest.fromJson(json);
      expect(request.displayCode, '2695');
    });

    test('falls back to full short_id when no hyphen', () {
      final json = {
        'id': 'r1', 'short_id': 'NOSEPARATOR', 'requester_id': 'u1',
        'blood_type': 'O+', 'units_needed': 1, 'urgency_level': 'routine',
        'hospital_name': 'H', 'hospital_lat': 0.0, 'hospital_lng': 0.0,
        'status': 'active', 'nearby_donors_count': 0, 'total_eligible_count': 0,
        'created_at': '2026-01-01', 'expires_at': '2026-01-02',
      };
      final request = BloodRequest.fromJson(json);
      expect(request.displayCode, 'NOSEPARATOR');
    });
  });

  group('DonorAssignment.fromJson', () {
    test('parses all response types', () {
      final json = {
        'id': 'a1', 'request_id': 'r1', 'donor_id': 'd1',
        'response_type': 'accepted', 'distance_km': 12.5,
        'responded_at': '2026-01-01T00:00:00Z',
      };
      final assignment = DonorAssignment.fromJson(json);
      expect(assignment.id, 'a1');
      expect(assignment.responseType, ResponseType.accepted);
      expect(assignment.distanceKm, 12.5);
    });
  });

  group('DonorResponseEntry.fromJson', () {
    test('parses response entry', () {
      final json = {
        'request_id': 'r1',
        'short_id': 'CH-5678',
        'hospital_name': 'H',
        'blood_type': 'A+',
        'response_type': 'declined',
        'responded_at': '2026-01-01T00:00:00Z',
      };
      final entry = DonorResponseEntry.fromJson(json);
      expect(entry.requestId, 'r1');
      expect(entry.displayCode, '5678');
      expect(entry.responseType, 'declined');
    });
  });

  group('Hospital.fromJson', () {
    test('parses with all fields', () {
      final json = {
        'id': 'h1',
        'hospital_name': 'Test Hospital',
        'hospital_code': 'TH',
        'email': 'test@h.com',
        'latitude': 30.0,
        'longitude': 31.0,
        'address': '123 Main St',
        'distance_km': 5.5,
      };
      final hospital = Hospital.fromJson(json);
      expect(hospital.name, 'Test Hospital');
      expect(hospital.code, 'TH');
      expect(hospital.displayName, contains('5.5 km'));
    });

    test('handles null optional fields', () {
      final json = {
        'id': 'h1', 'hospital_name': 'H', 'hospital_code': null,
        'email': null, 'latitude': null, 'longitude': null,
      };
      final hospital = Hospital.fromJson(json);
      expect(hospital.code, '');
      expect(hospital.email, '');
      expect(hospital.latitude, 0.0);
      expect(hospital.longitude, 0.0);
      expect(hospital.address, isNull);
      expect(hospital.distanceKm, isNull);
    });

    test('displayName without distance shows name and code', () {
      final json = {
        'id': 'h1', 'hospital_name': 'H', 'hospital_code': 'TH',
        'email': '', 'latitude': 0.0, 'longitude': 0.0,
      };
      expect(Hospital.fromJson(json).displayName, 'H (TH)');
    });
  });

  group('PendingMutation', () {
    test('generates unique id when not provided', () {
      final m1 = PendingMutation(endpoint: '/test', method: 'POST');
      final m2 = PendingMutation(endpoint: '/test', method: 'POST');
      expect(m1.id, isNot(m2.id));
    });

    test('round-trip toJson/fromJson', () {
      final original = PendingMutation(
        endpoint: '/api/test', method: 'POST',
        payload: {'key': 'value'},
        priority: 1,
        optimisticCacheKey: 'cache-key',
        optimisticData: {'data': 1},
      );
      final json = original.toJson();
      final restored = PendingMutation.fromJson(json);
      expect(restored.endpoint, original.endpoint);
      expect(restored.method, original.method);
      expect(restored.payload, original.payload);
      expect(restored.priority, original.priority);
      expect(restored.optimisticCacheKey, original.optimisticCacheKey);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'mut_1', 'endpoint': '/test', 'method': 'GET',
        'createdAt': '2026-01-01T00:00:00Z',
      };
      final m = PendingMutation.fromJson(json);
      expect(m.payload, isNull);
      expect(m.retryCount, 0);
      expect(m.status, 'pending');
      expect(m.priority, 0);
    });

    test('default status is pending', () {
      final m = PendingMutation(endpoint: '/test', method: 'POST');
      expect(m.status, 'pending');
    });
  });
}
