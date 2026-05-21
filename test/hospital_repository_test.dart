import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital_request_match.dart';
import 'package:bloodconnect/repositories/hospital_repository.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/hospital_service.dart';
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

class _MockHospitalService extends Fake implements HospitalService {
  List<HospitalRequestMatch> searchResults = [];
  List<Map<String, dynamic>> auditLog = [];
  List<Map<String, dynamic>> inventory = [];
  Map<String, int> stats = {'pending': 0, 'today': 0, 'fulfilled': 0};
  List<Map<String, dynamic>> pendingRequests = [];
  String? verifyError;

  @override
  Future<List<HospitalRequestMatch>> searchByDisplayCode({required String hospitalUserId, required String fourDigitInput}) async {
    return searchResults;
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentAuditForRequest(String requestId) async {
    return auditLog;
  }

  @override
  Future<List<Map<String, dynamic>>> getInventory(String hospitalId) async {
    return inventory;
  }

  @override
  Future<Map<String, int>> getHospitalStats(String hospitalId) async {
    return stats;
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingRequests(String hospitalId) async {
    return pendingRequests;
  }

  @override
  @override
  Future<String?> verifyDonation({required String hospitalUserId, required String requestId, String? staffName}) async {
    return verifyError;
  }
}

void main() {
  group('HospitalRepository', () {
    late _MockApiClient mockApi;
    late _MockHospitalService mockHospitalService;
    late CacheService cacheService;
    late HospitalRepository repository;

    setUp(() {
      mockApi = _MockApiClient();
      mockHospitalService = _MockHospitalService();
      cacheService = CacheService(maxSize: 10);
      repository = HospitalRepository(
        apiClient: mockApi,
        hospitalService: mockHospitalService,
        cacheService: cacheService,
      );
    });

    group('searchByDisplayCode', () {
      test('returns matches', () async {
        final request = BloodRequest(
          id: 'r1', shortId: 'CH-1234', displayCode: '1234',
          requesterId: 'u1', bloodType: 'O+', unitsNeeded: 1,
          urgencyLevel: UrgencyLevel.urgent, hospitalName: 'H',
          hospitalLat: 0.0, hospitalLng: 0.0,
          status: RequestStatus.in_progress, nearbyDonorsCount: 0,
          totalEligibleCount: 0, createdAt: DateTime(2026, 1, 1),
          expiresAt: DateTime(2026, 1, 2),
        );
        mockHospitalService.searchResults = [
          HospitalRequestMatch(request: request, donorName: 'John', donorPhone: '0123456789'),
        ];
        final result = await repository.searchByDisplayCode(hospitalUserId: 'h1', fourDigitInput: '1234');
        expect(result.length, 1);
        expect(result[0].donorName, 'John');
      });
    });

    group('getRecentAuditForRequest', () {
      test('returns audit log', () async {
        mockHospitalService.auditLog = [{'event': 'verified'}];
        final result = await repository.getRecentAuditForRequest('r1');
        expect(result.length, 1);
      });
    });

    group('getInventory', () {
      test('returns inventory', () async {
        mockHospitalService.inventory = [{'blood_type': 'O+', 'units_available': 10}];
        final result = await repository.getInventory('h1');
        expect(result.length, 1);
      });
    });

    group('getHospitalStats', () {
      test('returns stats', () async {
        mockHospitalService.stats = {'pending': 3, 'today': 5, 'fulfilled': 10};
        final result = await repository.getHospitalStats('h1');
        expect(result['fulfilled'], 10);
      });
    });

    group('getPendingRequests', () {
      test('returns pending requests', () async {
        mockHospitalService.pendingRequests = [{'id': 'r1'}];
        final result = await repository.getPendingRequests('h1');
        expect(result.length, 1);
      });
    });
  });
}
