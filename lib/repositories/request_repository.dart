import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital.dart';
import 'package:bloodconnect/repositories/base_repository.dart';
import 'package:bloodconnect/services/request_service.dart';

class RequestRepository extends BaseRepository {
  final RequestService _requestService;

  RequestRepository({
    required super.apiClient,
    required RequestService requestService,
    super.cacheService,
    super.persistentCacheService,
    super.invalidationService,
  }) : _requestService = requestService;

  Future<List<Hospital>> getHospitals({
    double? userLatitude,
    double? userLongitude,
    int nearbyRadiusKm = 120,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/hospitals');
    }
    return cacheFirst<List<Hospital>>(
      cacheKey: 'repo:/api/v1/hospitals?lat=$userLatitude&lng=$userLongitude',
      fetch: () => _requestService.getHospitals(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        nearbyRadiusKm: nearbyRadiusKm,
      ),
    );
  }

  Future<BloodRequest> createRequest({
    required String requesterId,
    required String bloodType,
    required int unitsNeeded,
    required UrgencyLevel urgencyLevel,
    required String hospitalId,
    required double hospitalLat,
    required double hospitalLng,
    double? requesterLat,
    double? requesterLng,
    String? patientName,
    String? description,
    String? contactPhone,
  }) async {
    await invalidatePrefix('/api/v1/requests');
    return _requestService.createRequest(
      requesterId: requesterId,
      bloodType: bloodType,
      unitsNeeded: unitsNeeded,
      urgencyLevel: urgencyLevel,
      hospitalId: hospitalId,
      hospitalLat: hospitalLat,
      hospitalLng: hospitalLng,
      requesterLat: requesterLat,
      requesterLng: requesterLng,
      patientName: patientName,
      description: description,
      contactPhone: contactPhone,
    );
  }

  Future<BloodRequest?> getActiveRequest(String userId, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/requests/active');
    }
    return cacheFirst<BloodRequest?>(
      cacheKey: 'repo:/api/v1/requests/active?userId=$userId',
      fetch: () => _requestService.getActiveRequest(userId),
    );
  }

  Future<List<BloodRequest>> getMyRequests(String userId, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/requests/mine');
    }
    return cacheFirst<List<BloodRequest>>(
      cacheKey: 'repo:/api/v1/requests/mine?userId=$userId',
      fetch: () => _requestService.getMyRequests(userId),
    );
  }

  Future<bool> cancelRequest(String requestId, String userId) async {
    await invalidatePrefix('/api/v1/requests');
    await invalidatePrefix('/api/v1/donor');
    return _requestService.cancelRequest(requestId, userId);
  }
}
