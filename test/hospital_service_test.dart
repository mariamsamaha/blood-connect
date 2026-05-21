import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/hospital_service.dart';

class _MockApiClient extends Fake implements ApiClient {
  List<Map<String, dynamic>> _getJsonListResult = [];
  Map<String, dynamic>? _getJsonResult;
  Map<String, dynamic> _postJsonResult = <String, dynamic>{};

  Future<Map<String, dynamic>?> Function(String, {Map<String, String>? query, bool forceRefresh})? onGetJson;
  Future<List<Map<String, dynamic>>> Function(String, {Map<String, String>? query, bool forceRefresh})? onGetJsonList;

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    if (onGetJsonList != null) return onGetJsonList!(path, query: query, forceRefresh: forceRefresh);
    return _getJsonListResult;
  }

  @override
  Future<Map<String, dynamic>?> getJson(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    if (onGetJson != null) return onGetJson!(path, query: query, forceRefresh: forceRefresh);
    return _getJsonResult;
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    return _postJsonResult;
  }
}

void main() {
  group('HospitalService.normalizeFourDigitCode', () {
    test('returns last 4 digits from a longer string', () {
      expect(HospitalService.normalizeFourDigitCode('ZC1234'), '1234');
    });

    test('pads short digit strings with leading zeros', () {
      expect(HospitalService.normalizeFourDigitCode('12'), '0012');
    });

    test('strips non-digit characters', () {
      expect(HospitalService.normalizeFourDigitCode('ZC-56-78'), '5678');
    });

    test('returns empty string when no digits', () {
      expect(HospitalService.normalizeFourDigitCode('ABCD'), '');
    });

    test('returns empty string for empty input', () {
      expect(HospitalService.normalizeFourDigitCode(''), '');
    });

    test('returns exact 4-digit string unchanged', () {
      expect(HospitalService.normalizeFourDigitCode('9876'), '9876');
    });
  });

  group('HospitalService', () {
    late _MockApiClient mockApi;
    late HospitalService service;

    setUp(() {
      mockApi = _MockApiClient();
      service = HospitalService(mockApi);
    });

    group('searchByDisplayCode', () {
      test('returns empty list when code is not 4 digits', () async {
        final result = await service.searchByDisplayCode(
          hospitalUserId: 'h1',
          fourDigitInput: '12',
        );
        expect(result, isEmpty);
      });

      test('returns parsed matches for valid code', () async {
        mockApi._getJsonListResult = [
          {
            'request': {
              'id': 'r1', 'short_id': 'CH-1234', 'requester_id': 'u1',
              'blood_type': 'O+', 'units_needed': 1, 'urgency_level': 'urgent',
              'hospital_name': 'H', 'hospital_lat': 0.0, 'hospital_lng': 0.0,
              'status': 'in_progress', 'nearby_donors_count': 0,
              'total_eligible_count': 0, 'created_at': '2026-01-01',
              'expires_at': '2026-01-02',
            },
            'donorName': 'John Doe',
            'donorPhone': '0123456789',
          },
        ];
        final result = await service.searchByDisplayCode(
          hospitalUserId: 'h1',
          fourDigitInput: '1234',
        );
        expect(result.length, 1);
        expect(result[0].donorName, 'John Doe');
        expect(result[0].donorPhone, '0123456789');
        expect(result[0].request.id, 'r1');
      });

      test('handles missing donor name/phone', () async {
        mockApi._getJsonListResult = [
          {
            'request': {
              'id': 'r1', 'short_id': 'CH-1234', 'requester_id': 'u1',
              'blood_type': 'O+', 'units_needed': 1, 'urgency_level': 'urgent',
              'hospital_name': 'H', 'hospital_lat': 0.0, 'hospital_lng': 0.0,
              'status': 'in_progress', 'nearby_donors_count': 0,
              'total_eligible_count': 0, 'created_at': '2026-01-01',
              'expires_at': '2026-01-02',
            },
          },
        ];
        final result = await service.searchByDisplayCode(
          hospitalUserId: 'h1',
          fourDigitInput: '1234',
        );
        expect(result[0].donorName, isNull);
        expect(result[0].donorPhone, isNull);
      });
    });

    group('verifyDonation', () {
      test('returns null on success', () async {
        mockApi._postJsonResult = {};
        final result = await service.verifyDonation(
          hospitalUserId: 'h1',
          requestId: 'r1',
        );
        expect(result, isNull);
      });

      test('returns error string when server returns error', () async {
        mockApi._postJsonResult = {'error': 'Invalid code'};
        final result = await service.verifyDonation(
          hospitalUserId: 'h1',
          requestId: 'r1',
        );
        expect(result, 'Invalid code');
      });
    });

    group('getRecentAuditForRequest', () {
      test('returns list on success', () async {
        mockApi._getJsonListResult = [{'event': 'verified'}];
        final result = await service.getRecentAuditForRequest('r1');
        expect(result.length, 1);
      });

      test('returns empty on error', () async {
        mockApi.onGetJsonList = (_, {query, forceRefresh = false}) => throw Exception('fail');
        final result = await service.getRecentAuditForRequest('r1');
        expect(result, isEmpty);
      });
    });

    group('getInventory', () {
      test('returns list on success', () async {
        mockApi._getJsonListResult = [{'item': 'A+', 'qty': 10}];
        final result = await service.getInventory('h1');
        expect(result.length, 1);
      });

      test('returns empty on error', () async {
        mockApi.onGetJsonList = (_, {query, forceRefresh = false}) => throw Exception('fail');
        final result = await service.getInventory('h1');
        expect(result, isEmpty);
      });
    });

    group('getHospitalStats', () {
      test('returns mapped stats', () async {
        mockApi._getJsonResult = {'pending': 3, 'today': 5, 'fulfilled': 10};
        final result = await service.getHospitalStats('h1');
        expect(result['pending'], 3);
        expect(result['today'], 5);
        expect(result['fulfilled'], 10);
      });

      test('returns defaults on null', () async {
        mockApi._getJsonResult = null;
        final result = await service.getHospitalStats('h1');
        expect(result['pending'], 0);
        expect(result['today'], 0);
        expect(result['fulfilled'], 0);
      });

      test('returns defaults on error', () async {
        mockApi.onGetJson = (_, {query, forceRefresh = false}) => throw Exception('fail');
        final result = await service.getHospitalStats('h1');
        expect(result['pending'], 0);
      });
    });

    group('getPendingRequests', () {
      test('returns list on success', () async {
        mockApi._getJsonListResult = [{'id': 'r1'}];
        final result = await service.getPendingRequests('h1');
        expect(result.length, 1);
      });

      test('returns empty on error', () async {
        mockApi.onGetJsonList = (_, {query, forceRefresh = false}) => throw Exception('fail');
        final result = await service.getPendingRequests('h1');
        expect(result, isEmpty);
      });
    });
  });
}
