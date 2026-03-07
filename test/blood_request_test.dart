import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';

void main() {
  group('BloodRequest.fromJson', () {
    test('parses active request with full location data', () {
      final json = {
        'id': 'request-1',
        'short_id': 'CH-20260216-2695',
        'requester_id': 'user-1',
        'blood_type': 'O+',
        'units_needed': 2,
        'urgency_level': 'critical',
        'hospital_name': 'Cairo General Hospital',
        'hospital_lat': 30.0444,
        'hospital_lng': 31.2357,
        'requester_lat': 30.0500,
        'requester_lng': 31.2400,
        'status': 'active',
        'nearby_donors_count': 5,
        'total_eligible_count': 5,
        'created_at': '2026-02-16T14:30:00Z',
        'expires_at': '2026-02-17T14:30:00Z',
      };

      final request = BloodRequest.fromJson(json);

      expect(request.id, 'request-1');
      expect(request.shortId, 'CH-20260216-2695');
      expect(request.bloodType, 'O+');
      expect(request.unitsNeeded, 2);
      expect(request.urgencyLevel, UrgencyLevel.critical);
      expect(request.hospitalName, 'Cairo General Hospital');
      expect(request.hospitalLat, 30.0444);
      expect(request.hospitalLng, 31.2357);
      expect(request.requesterLat, 30.0500);
      expect(request.requesterLng, 31.2400);
      expect(request.status, RequestStatus.active);
      expect(request.nearbyDonorsCount, 5);
    });

    test('parses request with null requester location (backward compatibility)', () {
      final json = {
        'id': 'request-2',
        'short_id': 'CH-20260215-1234',
        'requester_id': 'user-2',
        'blood_type': 'A+',
        'units_needed': 1,
        'urgency_level': 'urgent',
        'hospital_name': 'Dar Al Fouad Hospital',
        'hospital_lat': 30.0626,
        'hospital_lng': 31.4015,
        'requester_lat': null,  // Old request before column added
        'requester_lng': null,
        'status': 'expired',
        'nearby_donors_count': 0,
        'total_eligible_count': 0,
        'created_at': '2026-02-15T10:00:00Z',
        'expires_at': '2026-02-16T10:00:00Z',
      };

      final request = BloodRequest.fromJson(json);

      expect(request.requesterLat, isNull);
      expect(request.requesterLng, isNull);
      expect(request.status, RequestStatus.expired);
    });

    test('parses all urgency levels correctly', () {
      final routineJson = {'urgency_level': 'routine'};
      final urgentJson = {'urgency_level': 'urgent'};
      final criticalJson = {'urgency_level': 'critical'};

      expect(
        BloodRequest.fromJson({...routineJson, 'id': '1', 'short_id': 'X', 
          'requester_id': 'u', 'blood_type': 'O+', 'units_needed': 1, 
          'hospital_name': 'H', 'status': 'active', 'nearby_donors_count': 0,
          'total_eligible_count': 0, 'created_at': '2026-01-01', 
          'expires_at': '2026-01-02'}).urgencyLevel,
        UrgencyLevel.routine
      );
      
      expect(
        BloodRequest.fromJson({...urgentJson, 'id': '2', 'short_id': 'Y', 
          'requester_id': 'u', 'blood_type': 'A+', 'units_needed': 1, 
          'hospital_name': 'H', 'status': 'active', 'nearby_donors_count': 0,
          'total_eligible_count': 0, 'created_at': '2026-01-01', 
          'expires_at': '2026-01-02'}).urgencyLevel,
        UrgencyLevel.urgent
      );
      
      expect(
        BloodRequest.fromJson({...criticalJson, 'id': '3', 'short_id': 'Z', 
          'requester_id': 'u', 'blood_type': 'B+', 'units_needed': 1, 
          'hospital_name': 'H', 'status': 'active', 'nearby_donors_count': 0,
          'total_eligible_count': 0, 'created_at': '2026-01-01', 
          'expires_at': '2026-01-02'}).urgencyLevel,
        UrgencyLevel.critical
      );
    });

    test('parses all status values correctly', () {
      final statuses = ['active', 'in_progress', 'fulfilled', 'cancelled', 'expired'];
      
      for (final statusString in statuses) {
        final json = {
          'id': 'req-$statusString',
          'short_id': 'TEST-123',
          'requester_id': 'user',
          'blood_type': 'O+',
          'units_needed': 1,
          'urgency_level': 'routine',
          'hospital_name': 'Test Hospital',
          'status': statusString,
          'nearby_donors_count': 0,
          'total_eligible_count': 0,
          'created_at': '2026-01-01',
          'expires_at': '2026-01-02',
        };
        
        final request = BloodRequest.fromJson(json);
        expect(request.status.toString(), contains(statusString));
      }
    });
  });
}