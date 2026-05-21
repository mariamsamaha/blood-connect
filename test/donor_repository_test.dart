import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/donor_response_entry.dart';
import 'package:bloodconnect/repositories/donor_repository.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/donor_service.dart';
import 'package:bloodconnect/services/cache_service.dart';

class _MockApiClient extends Fake implements ApiClient {
  @override
  Future<List<Map<String, dynamic>>> getJsonList(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getJson(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    return null;
  }

  @override
  Future<void> postEmpty(String path, {Object? body}) async {}
}

class _MockDonorService extends Fake implements DonorService {
  List<BloodRequest> matchingRequests = [];
  BloodRequest? activeMission;
  List<DonorResponseEntry> responseHistory = [];
  Map<String, int> stats = {'totalDonations': 0, 'rewardPoints': 0};
  List<Map<String, dynamic>> donationHistory = [];
  List<Map<String, dynamic>> leaderboard = [];
  int? myRank;

  @override
  Future<List<BloodRequest>> findMatchingRequests({required String donorId, required String donorBloodType, required double donorLat, required double donorLng, int radiusKm = 120}) async {
    return matchingRequests;
  }

  @override
  Future<BloodRequest?> getActiveMission(String donorId) async {
    return activeMission;
  }

  @override
  Future<List<DonorResponseEntry>> getDonorResponseHistory(String donorId) async {
    return responseHistory;
  }

  @override
  Future<Map<String, int>> getDonorStats(String donorId) async {
    return stats;
  }

  @override
  Future<List<Map<String, dynamic>>> getFullDonationHistory(String donorId) async {
    return donationHistory;
  }

  @override
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 20}) async {
    return leaderboard;
  }

  @override
  Future<int?> getMyRank(String userId) async {
    return myRank;
  }

  @override
  Future<void> acceptRequest({required String requestId, required String donorId, required double donorLat, required double donorLng}) async {}

  @override
  Future<void> declineRequest({required String requestId, required String donorId}) async {}

  @override
  Future<void> withdrawAcceptance({required String requestId, required String donorId}) async {}
}

BloodRequest _req({String id = 'r1'}) => BloodRequest(
  id: id, shortId: 'CH-1234', displayCode: '1234',
  requesterId: 'u1', bloodType: 'O+', unitsNeeded: 1,
  urgencyLevel: UrgencyLevel.urgent, hospitalName: 'H',
  hospitalLat: 0.0, hospitalLng: 0.0,
  status: RequestStatus.active, nearbyDonorsCount: 0,
  totalEligibleCount: 0, createdAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2026, 1, 2), distanceKm: 5.0,
);

void main() {
  group('DonorRepository', () {
    late _MockApiClient mockApi;
    late _MockDonorService mockDonorService;
    late CacheService cacheService;
    late DonorRepository repository;

    setUp(() {
      mockApi = _MockApiClient();
      mockDonorService = _MockDonorService();
      cacheService = CacheService(maxSize: 10);
      repository = DonorRepository(
        apiClient: mockApi,
        donorService: mockDonorService,
        cacheService: cacheService,
      );
    });

    group('getMatchingRequests', () {
      test('returns matching requests', () async {
        mockDonorService.matchingRequests = [_req()];
        final result = await repository.getMatchingRequests(
          donorId: 'd1', donorBloodType: 'O+', donorLat: 30.0, donorLng: 31.0,
        );
        expect(result.length, 1);
      });
    });

    group('getActiveMission', () {
      test('returns mission when active', () async {
        mockDonorService.activeMission = _req(id: 'mission-1');
        final result = await repository.getActiveMission('d1');
        expect(result, isNotNull);
        expect(result!.id, 'mission-1');
      });

      test('returns null when no mission', () async {
        final result = await repository.getActiveMission('d1');
        expect(result, isNull);
      });
    });

    group('getResponseHistory', () {
      test('returns response history', () async {
        mockDonorService.responseHistory = [
          DonorResponseEntry(requestId: 'r1', displayCode: '1234', hospitalName: 'H', bloodType: 'O+', responseType: 'accepted', respondedAt: DateTime(2026, 1, 1)),
        ];
        final result = await repository.getResponseHistory('d1');
        expect(result.length, 1);
      });
    });

    group('getStats', () {
      test('returns donor stats', () async {
        mockDonorService.stats = {'totalDonations': 5, 'rewardPoints': 100};
        final result = await repository.getStats('d1');
        expect(result['totalDonations'], 5);
      });
    });

    group('getFullDonationHistory', () {
      test('returns donation history', () async {
        mockDonorService.donationHistory = [{'id': 'd1'}];
        final result = await repository.getFullDonationHistory('d1');
        expect(result.length, 1);
      });
    });

    group('getLeaderboard', () {
      test('returns leaderboard', () async {
        mockDonorService.leaderboard = [{'rank': 1}];
        final result = await repository.getLeaderboard();
        expect(result.length, 1);
      });
    });

    group('getMyRank', () {
      test('returns rank', () async {
        mockDonorService.myRank = 3;
        final result = await repository.getMyRank('u1');
        expect(result, 3);
      });
    });

    group('mutation methods', () {
      test('acceptRequest invalidates cache', () async {
        cacheService.set('/api/v1/donor/matches', 'data');
        await repository.acceptRequest(requestId: 'r1', donorId: 'd1', donorLat: 30.0, donorLng: 31.0);
      });

      test('declineRequest invalidates cache', () async {
        await repository.declineRequest(requestId: 'r1', donorId: 'd1');
      });

      test('withdrawAcceptance invalidates cache', () async {
        await repository.withdrawAcceptance(requestId: 'r1', donorId: 'd1');
      });
    });
  });
}
