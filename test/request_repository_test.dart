import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital.dart';
import 'package:bloodconnect/repositories/request_repository.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/request_service.dart';
import 'package:bloodconnect/services/cache_service.dart';

class _MockApiClient extends Fake implements ApiClient {
  @override
  Future<Map<String, dynamic>?> getJson(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    return {};
  }
}

class _MockRequestService extends Fake implements RequestService {
  List<Hospital> hospitals = [];
  BloodRequest? createdRequest;
  BloodRequest? activeRequest;
  List<BloodRequest> myRequests = [];
  bool cancelResult = true;

  @override
  Future<List<Hospital>> getHospitals({double? userLatitude, double? userLongitude, int nearbyRadiusKm = 120}) async {
    return hospitals;
  }

  @override
  Future<BloodRequest> createRequest({required String requesterId, required String bloodType, required int unitsNeeded, required UrgencyLevel urgencyLevel, required String hospitalId, required double hospitalLat, required double hospitalLng, double? requesterLat, double? requesterLng, String? patientName, String? description, String? contactPhone}) async {
    return createdRequest!;
  }

  @override
  Future<BloodRequest?> getActiveRequest(String userId) async {
    return activeRequest;
  }

  @override
  Future<List<BloodRequest>> getMyRequests(String userId) async {
    return myRequests;
  }

  @override
  Future<bool> cancelRequest(String requestId, String userId) async {
    return cancelResult;
  }
}

BloodRequest _req({String id = 'r1'}) => BloodRequest(
  id: id, shortId: 'CH-1234', displayCode: '1234',
  requesterId: 'u1', bloodType: 'O+', unitsNeeded: 1,
  urgencyLevel: UrgencyLevel.urgent, hospitalName: 'H',
  hospitalLat: 0.0, hospitalLng: 0.0,
  status: RequestStatus.active, nearbyDonorsCount: 0,
  totalEligibleCount: 0, createdAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2026, 1, 2),
);

void main() {
  group('RequestRepository', () {
    late _MockApiClient mockApi;
    late _MockRequestService mockRequestService;
    late CacheService cacheService;
    late RequestRepository repository;

    setUp(() {
      mockApi = _MockApiClient();
      mockRequestService = _MockRequestService();
      cacheService = CacheService(maxSize: 10);
      repository = RequestRepository(
        apiClient: mockApi,
        requestService: mockRequestService,
        cacheService: cacheService,
      );
    });

    group('getHospitals', () {
      test('returns hospitals list', () async {
        mockRequestService.hospitals = [
          Hospital(id: 'h1', name: 'Test Hospital', code: 'TH', email: 't@t.com', latitude: 30.0, longitude: 31.0),
        ];
        final result = await repository.getHospitals();
        expect(result.length, 1);
        expect(result[0].name, 'Test Hospital');
      });
    });

    group('createRequest', () {
      test('creates and returns request', () async {
        mockRequestService.createdRequest = _req();
        final result = await repository.createRequest(
          requesterId: 'u1', bloodType: 'O+', unitsNeeded: 1,
          urgencyLevel: UrgencyLevel.critical, hospitalId: 'h1',
          hospitalLat: 30.0, hospitalLng: 31.0,
        );
        expect(result.id, 'r1');
      });
    });

    group('getActiveRequest', () {
      test('returns active request', () async {
        mockRequestService.activeRequest = _req();
        final result = await repository.getActiveRequest('u1');
        expect(result, isNotNull);
      });

      test('returns null when no active request', () async {
        final result = await repository.getActiveRequest('u1');
        expect(result, isNull);
      });
    });

    group('getMyRequests', () {
      test('returns request list', () async {
        mockRequestService.myRequests = [_req(id: 'r1'), _req(id: 'r2')];
        final result = await repository.getMyRequests('u1');
        expect(result.length, 2);
      });
    });

    group('cancelRequest', () {
      test('returns true on success', () async {
        mockRequestService.cancelResult = true;
        final result = await repository.cancelRequest('r1', 'u1');
        expect(result, isTrue);
      });

      test('returns false on failure', () async {
        mockRequestService.cancelResult = false;
        final result = await repository.cancelRequest('r1', 'u1');
        expect(result, isFalse);
      });
    });
  });
}
