import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/donor_service.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test-uid';

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'mock-token';
}

class _MockAuth extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  User? get currentUser => _FakeUser();
}

class _FakeHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};
  final List<http.BaseRequest> _requests = [];

  void enqueue(String method, String path, int status, dynamic body) {
    final key = '$method:$path';
    _responses[key] = http.Response(
      body is String ? body : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    final method = request.method;
    _requests.add(request);

    // Match by path prefix ignoring query params
    String? matchedKey;
    int maxLen = -1;
    for (final key in _responses.keys) {
      final km = key.split(':')[0];
      final kp = key.split(':')[1];
      if (method == km && url.contains(kp)) {
        if (kp.length > maxLen) {
          maxLen = kp.length;
          matchedKey = key;
        }
      }
    }

    if (matchedKey != null) {
      final resp = _responses[matchedKey]!;
      return http.StreamedResponse(
        Stream.value(utf8.encode(resp.body)),
        resp.statusCode,
        headers: resp.headers,
      );
    }

    return http.StreamedResponse(
      const Stream.empty(),
      404,
    );
  }
}

final _mockAuth = _MockAuth();

final _fakeProfile = UserProfile.fromJson({
  'id': 'donor-1',
  'firebase_uid': 'fb-donor-1',
  'email': 'donor@test.com',
  'name': 'Test Donor',
  'blood_type': 'O+',
  'role': 'donor',
  'account_type': 'regular',
  'donor_status': 'available',
  'latitude': 30.0444,
  'longitude': 31.2357,
});

final _fakeMatch = {
  'id': 'req-1',
  'short_id': 'CH-ABCD',
  'requester_id': 'recip-1',
  'blood_type': 'O+',
  'units_needed': 2,
  'urgency_level': 'urgent',
  'hospital_name': 'Test Hospital',
  'hospital_lat': 30.05,
  'hospital_lng': 31.24,
  'requester_lat': 30.04,
  'requester_lng': 31.23,
  'status': 'active',
  'nearby_donors_count': 5,
  'total_eligible_count': 10,
  'created_at': DateTime.now().toIso8601String(),
  'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
  'distance_km': 5.2,
};

final _fakeMission = {
  'id': 'req-1',
  'short_id': 'CH-ABCD',
  'requester_id': 'recip-1',
  'blood_type': 'O+',
  'units_needed': 2,
  'urgency_level': 'urgent',
  'hospital_name': 'Test Hospital',
  'hospital_lat': 30.05,
  'hospital_lng': 31.24,
  'status': 'in_progress',
  'nearby_donors_count': 5,
  'total_eligible_count': 10,
  'created_at': DateTime.now().toIso8601String(),
  'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
};

void main() {
  group('Donor Flow (service layer via mocked ApiClient)', () {
    late _FakeHttpClient httpClient;
    late ApiClient apiClient;
    late DonorService donorService;

    setUp(() {
      httpClient = _FakeHttpClient();
      apiClient = ApiClient(
        httpClient: httpClient,
        auth: _mockAuth,
      );
      donorService = DonorService(apiClient);
    });

    test('flow: sign-in -> view matches -> accept mission -> view mission', () async {
      httpClient.enqueue('GET', '/api/v1/users/me', 200, _fakeProfile.toJson());

      final profile = await apiClient.getJson('/api/v1/users/me');
      expect(profile, isNotNull);
      expect(profile!['name'], 'Test Donor');

      httpClient.enqueue('GET', '/api/v1/donor/matches', 200, [_fakeMatch]);

      final matches = await apiClient.getJsonList('/api/v1/donor/matches', query: {
        'donorId': 'donor-1',
        'donorLat': '30.0444',
        'donorLng': '31.2357',
        'compatibleTypesCsv': 'O-,O+',
        'radiusKm': '120',
      });
      expect(matches.length, 1);
      expect(matches[0]['hospital_name'], 'Test Hospital');

      final request = BloodRequest.fromJson(matches[0]);
      expect(request.bloodType, 'O+');

      httpClient.enqueue('POST', '/api/v1/donor/responses/accept', 204, null);

      await donorService.acceptRequest(
        requestId: request.id,
        donorId: 'donor-1',
        donorLat: 30.0444,
        donorLng: 31.2357,
      );

      httpClient.enqueue('GET', '/api/v1/donor/mission', 200, _fakeMission);

      final mission = await donorService.getActiveMission('donor-1');
      expect(mission, isNotNull);
      expect(mission!.status, RequestStatus.in_progress);
      expect(mission.hospitalName, 'Test Hospital');
      expect(mission.displayCode, 'ABCD');
    });
  });
}
