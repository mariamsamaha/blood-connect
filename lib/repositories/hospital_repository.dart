import 'package:bloodconnect/models/hospital_request_match.dart';
import 'package:bloodconnect/repositories/base_repository.dart';
import 'package:bloodconnect/services/hospital_service.dart';

class HospitalRepository extends BaseRepository {
  final HospitalService _hospitalService;

  HospitalRepository({
    required super.apiClient,
    required HospitalService hospitalService,
    super.cacheService,
    super.persistentCacheService,
    super.invalidationService,
  }) : _hospitalService = hospitalService;

  Future<List<HospitalRequestMatch>> searchByDisplayCode({
    required String hospitalUserId,
    required String fourDigitInput,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/hospital/search');
    }
    return cacheFirst<List<HospitalRequestMatch>>(
      cacheKey: 'repo:/api/v1/hospital/search?hospitalUserId=$hospitalUserId&code=$fourDigitInput',
      fetch: () => _hospitalService.searchByDisplayCode(
        hospitalUserId: hospitalUserId,
        fourDigitInput: fourDigitInput,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getRecentAuditForRequest(
    String requestId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/hospital/requests');
    }
    return cacheFirst<List<Map<String, dynamic>>>(
      cacheKey: 'repo:/api/v1/hospital/requests/$requestId/audit',
      fetch: () => _hospitalService.getRecentAuditForRequest(requestId),
    );
  }

  Future<List<Map<String, dynamic>>> getInventory(
    String hospitalId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/hospital/inventory');
    }
    return cacheFirst<List<Map<String, dynamic>>>(
      cacheKey: 'repo:/api/v1/hospital/inventory?hospitalId=$hospitalId',
      fetch: () => _hospitalService.getInventory(hospitalId),
    );
  }

  Future<Map<String, int>> getHospitalStats(
    String hospitalId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/hospital/stats');
    }
    return cacheFirst<Map<String, int>>(
      cacheKey: 'repo:/api/v1/hospital/stats?hospitalId=$hospitalId',
      fetch: () => _hospitalService.getHospitalStats(hospitalId),
    );
  }

  Future<List<Map<String, dynamic>>> getPendingRequests(
    String hospitalId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/hospital/pending');
    }
    return cacheFirst<List<Map<String, dynamic>>>(
      cacheKey: 'repo:/api/v1/hospital/pending?hospitalId=$hospitalId',
      fetch: () => _hospitalService.getPendingRequests(hospitalId),
    );
  }
}
