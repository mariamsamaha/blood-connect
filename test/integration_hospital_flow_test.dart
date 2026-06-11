import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/hospital_service.dart';
import 'package:bloodconnect/models/hospital_request_match.dart';

class _MockAuth extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
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

    String? matchedKey;
    for (final key in _responses.keys) {
      final km = key.split(':')[0];
      final kp = key.split(':')[1];
      if (method == km && url.contains(kp)) {
        matchedKey = key;
        break;
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

final _searchResult = [
  {
    'request': {
      'id': 'req-1',
      'short_id': 'CH-1234',
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
    },
    'donorName': 'John Donor',
    'donorPhone': '+201234567890',
  },
];

void main() {
  group('Hospital Flow (service layer via mocked ApiClient)', () {
    late _FakeHttpClient httpClient;
    late ApiClient apiClient;
    late HospitalService hospitalService;

    setUp(() {
      httpClient = _FakeHttpClient();
      apiClient = ApiClient(httpClient: httpClient, auth: _mockAuth);
      hospitalService = HospitalService(apiClient);
    });

    test('flow: sign-in -> search by code -> verify donation', () async {
      httpClient.enqueue('GET', '/api/v1/hospital/search', 200, _searchResult);

      final matches = await hospitalService.searchByDisplayCode(
        hospitalUserId: 'hosp-1',
        fourDigitInput: '1234',
      );

      expect(matches.length, 1);
      final match = matches.first;
      expect(match.request.bloodType, 'O+');
      expect(match.request.hospitalName, 'Test Hospital');
      expect(match.request.shortId, 'CH-1234');
      expect(match.donorName, 'John Donor');
      expect(match.donorPhone, '+201234567890');

      httpClient.enqueue('POST', '/api/v1/hospital/verify', 200, {'error': null});

      final error = await hospitalService.verifyDonation(
        hospitalUserId: 'hosp-1',
        requestId: 'req-1',
        staffName: 'Dr. Smith',
      );

      expect(error, isNull);
    });

    test('search returns empty array for invalid code', () async {
      httpClient.enqueue('GET', '/api/v1/hospital/search', 200, []);

      final matches = await hospitalService.searchByDisplayCode(
        hospitalUserId: 'hosp-1',
        fourDigitInput: '0000',
      );

      expect(matches, isEmpty);
    });

    test('normalizeFourDigitCode strips non-digits and pads', () {
      expect(HospitalService.normalizeFourDigitCode('abc12345'), '2345');
      expect(HospitalService.normalizeFourDigitCode('12'), '0012');
      expect(HospitalService.normalizeFourDigitCode(''), '');
      expect(HospitalService.normalizeFourDigitCode('1234'), '1234');
    });
  });
}
