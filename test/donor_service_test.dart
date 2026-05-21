import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/donor_response_entry.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/donor_service.dart';
import 'package:bloodconnect/services/audit_log_service.dart';

class _MockApiClient extends Fake implements ApiClient {
  List<Map<String, dynamic>> _getJsonListResult = [];
  Map<String, dynamic>? _getJsonResult;
  void Function(String, {Object? body})? _postEmptyCallback;

  Future<Map<String, dynamic>?> Function(String, {Map<String, String>? query, bool forceRefresh})? onGetJson;
  Future<List<Map<String, dynamic>>> Function(String, {Map<String, String>? query, bool forceRefresh})? onGetJsonList;

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    if (onGetJsonList != null) return onGetJsonList!(path, query: query, forceRefresh: forceRefresh);
    return Future.value(_getJsonListResult);
  }

  @override
  Future<Map<String, dynamic>?> getJson(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    if (onGetJson != null) return onGetJson!(path, query: query, forceRefresh: forceRefresh);
    return Future.value(_getJsonResult);
  }

  @override
  Future<void> postEmpty(String path, {Object? body}) async {
    _postEmptyCallback?.call(path, body: body);
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    return {};
  }
}

class _MockAuditLogService extends Fake implements AuditLogService {
  bool logCalled = false;
  String? capturedRequestId;
  String? capturedEventType;

  @override
  Future<void> log({required String requestId, required String eventType, String? detail, String? actorUserId}) async {
    logCalled = true;
    capturedRequestId = requestId;
    capturedEventType = eventType;
  }
}

Map<String, dynamic> _req({
  String id = 'req-1',
  String shortId = 'CH-1234',
  String status = 'active',
  String bloodType = 'O+',
}) => {
  'id': id,
  'short_id': shortId,
  'requester_id': 'u1',
  'blood_type': bloodType,
  'units_needed': 1,
  'urgency_level': 'urgent',
  'hospital_name': 'H',
  'hospital_lat': 0.0,
  'hospital_lng': 0.0,
  'status': status,
  'nearby_donors_count': 3,
  'total_eligible_count': 5,
  'created_at': '2026-01-01',
  'expires_at': '2026-01-02',
};

void main() {
  group('DonorService', () {
    late _MockApiClient mockApi;
    late _MockAuditLogService mockAudit;
    late DonorService service;

    setUp(() {
      mockApi = _MockApiClient();
      mockAudit = _MockAuditLogService();
      service = DonorService(mockApi, audit: mockAudit);
    });

    group('findMatchingRequests', () {
      test('returns parsed requests with distance_km', () async {
        mockApi._getJsonListResult = [
          {..._req(), 'distance_km': '12.5'},
        ];
        final result = await service.findMatchingRequests(
          donorId: 'd1',
          donorBloodType: 'O+',
          donorLat: 30.0,
          donorLng: 31.0,
        );
        expect(result.length, 1);
        expect(result[0].distanceKm, 12.5);
      });

      test('returns 0 distance when distance_km is null', () async {
        mockApi._getJsonListResult = [
          {..._req(), 'distance_km': null},
        ];
        final result = await service.findMatchingRequests(
          donorId: 'd1', donorBloodType: 'O+', donorLat: 30.0, donorLng: 31.0,
        );
        expect(result[0].distanceKm, 0.0);
      });

      test('throws on api failure', () async {
        mockApi.onGetJsonList = (String path, {Map<String, String>? query, bool forceRefresh = false}) => throw Exception('fail');
        expect(
          () => service.findMatchingRequests(donorId: 'd1', donorBloodType: 'O+', donorLat: 30.0, donorLng: 31.0),
          throwsA(predicate((e) => e.toString().contains('Failed to find matching requests'))),
        );
      });
    });

    group('acceptRequest', () {
      test('calls postEmpty and logs audit on success', () async {
        String? capturedPath;
        mockApi._postEmptyCallback = (path, {body}) { capturedPath = path; };
        await service.acceptRequest(requestId: 'req-1', donorId: 'd1', donorLat: 30.0, donorLng: 31.0);
        expect(capturedPath, '/api/v1/donor/responses/accept');
        expect(mockAudit.logCalled, isTrue);
        expect(mockAudit.capturedRequestId, 'req-1');
        expect(mockAudit.capturedEventType, 'donor_accepted');
      });

      test('throws specific message for already_accepted error', () async {
        mockApi._postEmptyCallback = (path, {body}) => throw Exception('already_accepted');
        expect(
          () => service.acceptRequest(requestId: 'req-1', donorId: 'd1', donorLat: 30.0, donorLng: 31.0),
          throwsA(predicate((e) => e.toString().contains('Another donor already accepted'))),
        );
      });

      test('throws specific message for accept_failed error', () async {
        mockApi._postEmptyCallback = (path, {body}) => throw Exception('accept_failed');
        expect(
          () => service.acceptRequest(requestId: 'req-1', donorId: 'd1', donorLat: 30.0, donorLng: 31.0),
          throwsA(predicate((e) => e.toString().contains('Another donor already accepted'))),
        );
      });

      test('rethrows non-pattern exceptions as-is', () async {
        mockApi._postEmptyCallback = (path, {body}) => throw Exception('server_error');
        expect(
          () => service.acceptRequest(requestId: 'req-1', donorId: 'd1', donorLat: 30.0, donorLng: 31.0),
          throwsA(predicate((e) => e.toString().contains('server_error'))),
        );
      });

      test('wraps non-Exception throws', () async {
        mockApi._postEmptyCallback = (path, {body}) => throw 'string_error';
        expect(
          () => service.acceptRequest(requestId: 'req-1', donorId: 'd1', donorLat: 30.0, donorLng: 31.0),
          throwsA(predicate((e) => e.toString().contains('Failed to accept request'))),
        );
      });
    });

    group('declineRequest', () {
      test('calls postEmpty', () async {
        String? capturedPath;
        mockApi._postEmptyCallback = (path, {body}) { capturedPath = path; };
        await service.declineRequest(requestId: 'req-1', donorId: 'd1');
        expect(capturedPath, '/api/v1/donor/responses/decline');
      });

      test('throws on failure', () async {
        mockApi._postEmptyCallback = (path, {body}) => throw Exception('fail');
        expect(() => service.declineRequest(requestId: 'req-1', donorId: 'd1'), throwsA(predicate((e) => e.toString().contains('Failed to decline request'))));
      });
    });

    group('getActiveMission', () {
      test('returns request when found', () async {
        mockApi._getJsonResult = _req();
        final result = await service.getActiveMission('d1');
        expect(result, isNotNull);
        expect(result!.id, 'req-1');
      });

      test('returns null when no mission', () async {
        mockApi._getJsonResult = null;
        final result = await service.getActiveMission('d1');
        expect(result, isNull);
      });

      test('throws on failure', () async {
        mockApi.onGetJson = (_, {query, forceRefresh = false}) => throw Exception('fail');
        expect(() => service.getActiveMission('d1'), throwsA(predicate((e) => e.toString().contains('Failed to get active mission'))));
      });
    });

    group('getDonorResponseHistory', () {
      test('returns parsed entries', () async {
        mockApi._getJsonListResult = [
          {'request_id': 'r1', 'short_id': 'CH-1', 'hospital_name': 'H1', 'blood_type': 'A+', 'response_type': 'accepted', 'responded_at': '2026-01-01T00:00:00Z'},
        ];
        final result = await service.getDonorResponseHistory('d1');
        expect(result.length, 1);
        expect(result[0].responseType, 'accepted');
      });

      test('returns empty list on error', () async {
        mockApi.onGetJsonList = (_, {query, forceRefresh = false}) => throw Exception('fail');
        final result = await service.getDonorResponseHistory('d1');
        expect(result, isEmpty);
      });
    });

    group('getDonorStats', () {
      test('returns stats from server', () async {
        mockApi._getJsonResult = {'totalDonations': 5, 'rewardPoints': 100};
        final result = await service.getDonorStats('d1');
        expect(result['totalDonations'], 5);
        expect(result['rewardPoints'], 100);
      });

      test('returns zeros when server returns null', () async {
        mockApi._getJsonResult = null;
        final result = await service.getDonorStats('d1');
        expect(result['totalDonations'], 0);
        expect(result['rewardPoints'], 0);
      });

      test('returns zeros on error', () async {
        mockApi.onGetJson = (_, {query, forceRefresh = false}) => throw Exception('fail');
        final result = await service.getDonorStats('d1');
        expect(result['totalDonations'], 0);
        expect(result['rewardPoints'], 0);
      });
    });

    group('withdrawAcceptance', () {
      test('calls postEmpty and logs audit', () async {
        String? capturedPath;
        mockApi._postEmptyCallback = (path, {body}) { capturedPath = path; };
        await service.withdrawAcceptance(requestId: 'req-1', donorId: 'd1');
        expect(capturedPath, '/api/v1/donor/responses/withdraw');
        expect(mockAudit.logCalled, isTrue);
        expect(mockAudit.capturedEventType, 'donor_withdrew');
      });

      test('throws on failure', () async {
        mockApi._postEmptyCallback = (_, {body}) => throw Exception('fail');
        expect(() => service.withdrawAcceptance(requestId: 'req-1', donorId: 'd1'), throwsA(predicate((e) => e.toString().contains('Failed to withdraw acceptance'))));
      });
    });

    group('getFullDonationHistory', () {
      test('returns list on success', () async {
        mockApi.onGetJsonList = (_, {query, forceRefresh = false}) => Future.value([{'id': 'd1'}]);
        final result = await service.getFullDonationHistory('d1');
        expect(result.length, 1);
      });

      test('returns empty on error', () async {
        mockApi.onGetJsonList = (_, {query, forceRefresh = false}) => throw Exception('fail');
        final result = await service.getFullDonationHistory('d1');
        expect(result, isEmpty);
      });
    });

    group('getLeaderboard', () {
      test('returns list on success', () async {
        mockApi.onGetJsonList = (_, {query, forceRefresh = false}) => Future.value([{'rank': 1}]);
        final result = await service.getLeaderboard();
        expect(result.length, 1);
      });

      test('returns empty on error', () async {
        mockApi.onGetJsonList = (_, {query, forceRefresh = false}) => throw Exception('fail');
        final result = await service.getLeaderboard();
        expect(result, isEmpty);
      });
    });

    group('getMyRank', () {
      test('returns rank int on success', () async {
        mockApi._getJsonResult = {'rank': 3};
        final result = await service.getMyRank('d1');
        expect(result, 3);
      });

      test('returns null when no rank', () async {
        mockApi._getJsonResult = {};
        final result = await service.getMyRank('d1');
        expect(result, isNull);
      });

      test('returns null on error', () async {
        mockApi.onGetJson = (_, {query, forceRefresh = false}) => throw Exception('fail');
        final result = await service.getMyRank('d1');
        expect(result, isNull);
      });
    });
  });
}
