import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/donor_response_entry.dart';
import 'package:bloodconnect/repositories/base_repository.dart';
import 'package:bloodconnect/services/donor_service.dart';

class DonorRepository extends BaseRepository {
  final DonorService _donorService;

  DonorRepository({
    required super.apiClient,
    required DonorService donorService,
    super.cacheService,
    super.persistentCacheService,
    super.invalidationService,
  }) : _donorService = donorService;

  Future<List<BloodRequest>> getMatchingRequests({
    required String donorId,
    required String donorBloodType,
    required double donorLat,
    required double donorLng,
    int radiusKm = 120,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/donor/matches');
    }
    return cacheFirst<List<BloodRequest>>(
      cacheKey: 'repo:/api/v1/donor/matches?donorId=$donorId&bloodType=$donorBloodType',
      fetch: () => _donorService.findMatchingRequests(
        donorId: donorId,
        donorBloodType: donorBloodType,
        donorLat: donorLat,
        donorLng: donorLng,
        radiusKm: radiusKm,
      ),
    );
  }

  Future<BloodRequest?> getActiveMission(String donorId, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/donor/mission');
    }
    return cacheFirst<BloodRequest?>(
      cacheKey: 'repo:/api/v1/donor/mission?donorId=$donorId',
      fetch: () => _donorService.getActiveMission(donorId),
    );
  }

  Future<List<DonorResponseEntry>> getResponseHistory(
    String donorId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/donor/responses');
    }
    return cacheFirst<List<DonorResponseEntry>>(
      cacheKey: 'repo:/api/v1/donor/responses/history?donorId=$donorId',
      fetch: () => _donorService.getDonorResponseHistory(donorId),
    );
  }

  Future<Map<String, int>> getStats(String donorId, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/donor/stats');
    }
    return cacheFirst<Map<String, int>>(
      cacheKey: 'repo:/api/v1/donor/stats?donorId=$donorId',
      fetch: () => _donorService.getDonorStats(donorId),
    );
  }

  Future<List<Map<String, dynamic>>> getFullDonationHistory(
    String donorId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/donor/donations');
    }
    return cacheFirst<List<Map<String, dynamic>>>(
      cacheKey: 'repo:/api/v1/donor/donations?donorId=$donorId',
      fetch: () => _donorService.getFullDonationHistory(donorId),
    );
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 20, bool forceRefresh = false}) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/donor/leaderboard');
    }
    return cacheFirst<List<Map<String, dynamic>>>(
      cacheKey: 'repo:/api/v1/donor/leaderboard?limit=$limit',
      fetch: () => _donorService.getLeaderboard(limit: limit),
    );
  }

  Future<int?> getMyRank(String userId, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/donor/rank');
    }
    return cacheFirst<int?>(
      cacheKey: 'repo:/api/v1/donor/rank?userId=$userId',
      fetch: () => _donorService.getMyRank(userId),
    );
  }

  Future<void> acceptRequest({
    required String requestId,
    required String donorId,
    required double donorLat,
    required double donorLng,
  }) async {
    await invalidatePrefix('/api/v1/donor');
    await invalidatePrefix('/api/v1/requests');
    return _donorService.acceptRequest(
      requestId: requestId,
      donorId: donorId,
      donorLat: donorLat,
      donorLng: donorLng,
    );
  }

  Future<void> declineRequest({
    required String requestId,
    required String donorId,
  }) async {
    await invalidatePrefix('/api/v1/donor');
    return _donorService.declineRequest(
      requestId: requestId,
      donorId: donorId,
    );
  }

  Future<void> withdrawAcceptance({
    required String requestId,
    required String donorId,
  }) async {
    await invalidatePrefix('/api/v1/donor');
    await invalidatePrefix('/api/v1/requests');
    return _donorService.withdrawAcceptance(
      requestId: requestId,
      donorId: donorId,
    );
  }
}
