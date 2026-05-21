import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/request_service.dart';
import 'package:bloodconnect/services/notification_service.dart';
import 'package:bloodconnect/services/audit_log_service.dart';

class _MockApiClient extends Fake implements ApiClient {
  Map<String, dynamic>? _getJsonResult;
  List<Map<String, dynamic>> _getJsonListResult = [];
  Map<String, dynamic> _postJsonResult = <String, dynamic>{};
  void Function(String, {Object? body})? _patchJsonCallback;
  void Function(String, {Object? body})? _postEmptyCallback;

  Future<Map<String, dynamic>?> Function(String, {Map<String, String>? query, bool forceRefresh})? onGetJson;
  Future<List<Map<String, dynamic>>> Function(String, {Map<String, String>? query, bool forceRefresh})? onGetJsonList;
  Future<Map<String, dynamic>> Function(String, {Object? body})? onPostJson;

  @override
  Future<Map<String, dynamic>?> getJson(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    if (onGetJson != null) return onGetJson!(path, query: query, forceRefresh: forceRefresh);
    return _getJsonResult;
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    if (onGetJsonList != null) return onGetJsonList!(path, query: query, forceRefresh: forceRefresh);
    return _getJsonListResult;
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    if (onPostJson != null) return onPostJson!(path, body: body);
    return _postJsonResult;
  }

  @override
  Future<void> patchJson(String path, {Object? body}) async {
    _patchJsonCallback?.call(path, body: body);
  }

  @override
  Future<void> postEmpty(String path, {Object? body}) async {
    _postEmptyCallback?.call(path, body: body);
  }
}

class _MockNotificationService extends Fake implements NotificationService {
  bool sendNewRequestNotificationsCalled = false;
  BloodRequest? capturedRequest;

  @override
  Future<void> sendNewRequestNotifications(BloodRequest request) async {
    sendNewRequestNotificationsCalled = true;
    capturedRequest = request;
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

void main() {
  group('RequestService', () {
    late _MockApiClient mockApi;
    late _MockNotificationService mockNotif;
    late _MockAuditLogService mockAudit;
    late RequestService service;

    setUp(() {
      mockApi = _MockApiClient();
      mockNotif = _MockNotificationService();
      mockAudit = _MockAuditLogService();
      service = RequestService(
        mockApi,
        notificationService: mockNotif,
        audit: mockAudit,
      );
    });

    group('getHospitals', () {
      test('returns parsed hospitals on success', () async {
        mockApi._getJsonListResult = [
          {'id': 'h1', 'hospital_name': 'Cairo General', 'hospital_code': 'CG', 'email': 'cg@test.com', 'latitude': 30.0, 'longitude': 31.0},
        ];
        final result = await service.getHospitals();
        expect(result.length, 1);
        expect(result[0].name, 'Cairo General');
        expect(result[0].code, 'CG');
      });

      test('passes location query when lat/lng provided', () async {
        Map<String, String>? capturedQuery;
        mockApi.onGetJsonList = (String path, {Map<String, String>? query, bool forceRefresh = false}) {
          capturedQuery = query;
          return Future.value([]);
        };
        await service.getHospitals(userLatitude: 30.0, userLongitude: 31.0, nearbyRadiusKm: 50);
        expect(capturedQuery, isNotNull);
        expect(capturedQuery!['lat'], '30.0');
        expect(capturedQuery!['lng'], '31.0');
        expect(capturedQuery!['radiusKm'], '50');
      });
    });

    group('createRequest', () {
      final requestJson = {
        'id': 'req-1',
        'short_id': 'CH-20260216-1234',
        'requester_id': 'user-1',
        'blood_type': 'O+',
        'units_needed': 2,
        'urgency_level': 'critical',
        'hospital_name': 'Cairo General',
        'hospital_lat': 30.0,
        'hospital_lng': 31.0,
        'status': 'active',
        'nearby_donors_count': 0,
        'total_eligible_count': 0,
        'created_at': '2026-02-16T14:30:00Z',
        'expires_at': '2026-02-17T14:30:00Z',
      };

      test('returns created request on success', () async {
        mockApi._postJsonResult = requestJson;
        final result = await service.createRequest(
          requesterId: 'user-1',
          bloodType: 'O+',
          unitsNeeded: 2,
          urgencyLevel: UrgencyLevel.critical,
          hospitalId: 'hosp-1',
          hospitalLat: 30.0,
          hospitalLng: 31.0,
        );
        expect(result.id, 'req-1');
        expect(result.bloodType, 'O+');
      });

      test('sends notification after creation', () async {
        mockApi._postJsonResult = requestJson;
        await service.createRequest(
          requesterId: 'user-1',
          bloodType: 'O+',
          unitsNeeded: 2,
          urgencyLevel: UrgencyLevel.critical,
          hospitalId: 'hosp-1',
          hospitalLat: 30.0,
          hospitalLng: 31.0,
        );
        expect(mockNotif.sendNewRequestNotificationsCalled, isTrue);
        expect(mockNotif.capturedRequest?.id, 'req-1');
      });

      test('succeeds without notification service', () async {
        final serviceWithoutNotif = RequestService(mockApi);
        mockApi._postJsonResult = requestJson;
        final result = await serviceWithoutNotif.createRequest(
          requesterId: 'user-1',
          bloodType: 'O+',
          unitsNeeded: 2,
          urgencyLevel: UrgencyLevel.critical,
          hospitalId: 'hosp-1',
          hospitalLat: 30.0,
          hospitalLng: 31.0,
        );
        expect(result.id, 'req-1');
      });

      test('throws on api failure', () async {
        mockApi.onPostJson = (String path, {Object? body}) => throw Exception('Network error');
        expect(
          () => service.createRequest(
            requesterId: 'user-1',
            bloodType: 'O+',
            unitsNeeded: 2,
            urgencyLevel: UrgencyLevel.critical,
            hospitalId: 'hosp-1',
            hospitalLat: 30.0,
            hospitalLng: 31.0,
          ),
          throwsA(predicate((e) => e.toString().contains('Failed to create blood request'))),
        );
      });
    });

    group('getActiveRequest', () {
      test('returns request when found', () async {
        mockApi._getJsonResult = {
          'id': 'req-1',
          'short_id': 'CH-1234',
          'requester_id': 'user-1',
          'blood_type': 'O+',
          'units_needed': 1,
          'urgency_level': 'urgent',
          'hospital_name': 'H',
          'hospital_lat': 30.0,
          'hospital_lng': 31.0,
          'status': 'active',
          'nearby_donors_count': 3,
          'total_eligible_count': 5,
          'created_at': '2026-02-16T14:30:00Z',
          'expires_at': '2026-02-17T14:30:00Z',
        };
        final result = await service.getActiveRequest('user-1');
        expect(result, isNotNull);
        expect(result!.id, 'req-1');
      });

      test('returns null when no active request', () async {
        mockApi.onGetJson = (String path, {Map<String, String>? query, bool forceRefresh = false}) => Future.value(null);
        final result = await service.getActiveRequest('user-1');
        expect(result, isNull);
      });

      test('throws on api failure', () async {
        mockApi.onGetJson = (String path, {Map<String, String>? query, bool forceRefresh = false}) => throw Exception('Server error');
        expect(() => service.getActiveRequest('user-1'), throwsA(predicate((e) => e.toString().contains('Failed to fetch active request'))));
      });
    });

    group('getMyRequests', () {
      test('returns list of requests', () async {
        mockApi._getJsonListResult = [
          {'id': 'r1', 'short_id': 'CH-1', 'requester_id': 'u1', 'blood_type': 'A+', 'units_needed': 1, 'urgency_level': 'routine', 'hospital_name': 'H', 'hospital_lat': 0.0, 'hospital_lng': 0.0, 'status': 'active', 'nearby_donors_count': 0, 'total_eligible_count': 0, 'created_at': '2026-01-01', 'expires_at': '2026-01-02'},
          {'id': 'r2', 'short_id': 'CH-2', 'requester_id': 'u1', 'blood_type': 'B+', 'units_needed': 2, 'urgency_level': 'urgent', 'hospital_name': 'H2', 'hospital_lat': 0.0, 'hospital_lng': 0.0, 'status': 'fulfilled', 'nearby_donors_count': 0, 'total_eligible_count': 0, 'created_at': '2026-01-01', 'expires_at': '2026-01-02'},
        ];
        final result = await service.getMyRequests('user-1');
        expect(result.length, 2);
        expect(result[0].bloodType, 'A+');
        expect(result[1].bloodType, 'B+');
      });

      test('throws on failure', () async {
        mockApi.onGetJsonList = (String path, {Map<String, String>? query, bool forceRefresh = false}) => throw Exception('fail');
        expect(() => service.getMyRequests('u1'), throwsA(predicate((e) => e.toString().contains('Failed to fetch requests'))));
      });
    });

    group('updateActiveRequest', () {
      test('sends patch and logs audit', () async {
        String? patchedPath;
        Object? patchedBody;
        mockApi._patchJsonCallback = (path, {body}) {
          patchedPath = path;
          patchedBody = body;
        };

        await service.updateActiveRequest(
          requestId: 'req-1',
          requesterId: 'user-1',
          unitsNeeded: 3,
          urgencyLevel: UrgencyLevel.critical,
        );

        expect(patchedPath, '/api/v1/requests/req-1');
        expect(mockAudit.logCalled, isTrue);
        expect(mockAudit.capturedRequestId, 'req-1');
        expect(mockAudit.capturedEventType, 'updated');
      });

      test('sends only provided fields', () async {
        Map<String, dynamic>? capturedBody;
        mockApi._patchJsonCallback = (path, {body}) {
          capturedBody = body as Map<String, dynamic>?;
        };

        await service.updateActiveRequest(
          requestId: 'req-1',
          requesterId: 'user-1',
          unitsNeeded: 3,
        );
        expect(capturedBody?['unitsNeeded'], 3);
        expect(capturedBody?.containsKey('urgencyLevel') ?? false, isFalse);
        expect(capturedBody?.containsKey('description') ?? false, isFalse);
      });
    });

    group('cancelRequest', () {
      test('returns true when server confirms', () async {
        mockApi._postJsonResult = {'ok': true};
        final result = await service.cancelRequest('req-1', 'user-1');
        expect(result, isTrue);
        expect(mockAudit.logCalled, isTrue);
      });

      test('returns false when server rejects', () async {
        mockApi._postJsonResult = {'ok': false};
        final result = await service.cancelRequest('req-1', 'user-1');
        expect(result, isFalse);
        expect(mockAudit.logCalled, isFalse);
      });

      test('throws on api failure', () async {
        mockApi.onPostJson = (String path, {Object? body}) => throw Exception('Server error');
        expect(() => service.cancelRequest('req-1', 'user-1'), throwsA(predicate((e) => e.toString().contains('Failed to cancel request'))));
      });
    });
  });
}
