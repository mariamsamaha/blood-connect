import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/request_service.dart';

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

    return http.StreamedResponse(const Stream.empty(), 404);
  }
}

final _mockAuth = _MockAuth();

final _createdRequest = {
  'id': 'req-42',
  'short_id': 'CH-8888',
  'requester_id': 'recip-1',
  'blood_type': 'A+',
  'units_needed': 3,
  'urgency_level': 'critical',
  'hospital_name': 'City Hospital',
  'hospital_lat': 30.05,
  'hospital_lng': 31.24,
  'status': 'active',
  'nearby_donors_count': 8,
  'total_eligible_count': 15,
  'created_at': DateTime.now().toIso8601String(),
  'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
};

void main() {
  group('Recipient Flow (service layer via mocked ApiClient)', () {
    late _FakeHttpClient httpClient;
    late ApiClient apiClient;
    late RequestService requestService;

    setUp(() {
      httpClient = _FakeHttpClient();
      apiClient = ApiClient(httpClient: httpClient, auth: _mockAuth);
      requestService = RequestService(apiClient);
    });

    test('flow: sign-in -> create request -> view active -> cancel', () async {
      httpClient.enqueue('POST', '/api/v1/requests', 201, _createdRequest);

      final created = await requestService.createRequest(
        requesterId: 'recip-1',
        bloodType: 'A+',
        unitsNeeded: 3,
        urgencyLevel: UrgencyLevel.critical,
        hospitalId: 'hosp-1',
        hospitalLat: 30.05,
        hospitalLng: 31.24,
        requesterLat: 30.04,
        requesterLng: 31.23,
        patientName: 'John Doe',
        contactPhone: '+201234567890',
      );

      expect(created.id, 'req-42');
      expect(created.bloodType, 'A+');
      expect(created.shortId, 'CH-8888');
      expect(created.status, RequestStatus.active);

      httpClient.enqueue('GET', '/api/v1/requests/active', 200, _createdRequest);

      final active = await requestService.getActiveRequest('recip-1');
      expect(active, isNotNull);
      expect(active!.status, RequestStatus.active);
      expect(active.urgencyLevel, UrgencyLevel.critical);
      expect(active.hospitalName, 'City Hospital');

      httpClient.enqueue('POST', '/api/v1/requests/req-42/cancel', 200, {'ok': true});

      final cancelled = await requestService.cancelRequest('req-42', 'recip-1');
      expect(cancelled, isTrue);
    });
  });
}
