import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/audit_log_service.dart';
import 'package:bloodconnect/services/notification_service.dart';

class RequestService {
  final ApiClient _api;
  final NotificationService? _notificationService;
  final AuditLogService? _audit;

  RequestService(
    this._api, {
    NotificationService? notificationService,
    AuditLogService? audit,
  })  : _notificationService = notificationService,
        _audit = audit;

  Future<List<Hospital>> getHospitals({
    double? userLatitude,
    double? userLongitude,
    int nearbyRadiusKm = 120,
  }) async {
    try {
      final query = <String, String>{};
      if (userLatitude != null && userLongitude != null) {
        query['lat'] = userLatitude.toString();
        query['lng'] = userLongitude.toString();
        query['radiusKm'] = nearbyRadiusKm.toString();
      }
      final result = await _api.getJsonList('/api/v1/hospitals', query: query);
      return result.map((row) => Hospital.fromJson(row)).toList();
    } catch (e) {
      throw Exception('Failed to fetch hospitals: $e');
    }
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
    try {
      final row = await _api.postJson(
        '/api/v1/requests',
        body: {
          'requesterId': requesterId,
          'bloodType': bloodType,
          'unitsNeeded': unitsNeeded,
          'urgencyLevel': urgencyLevel.name,
          'hospitalId': hospitalId,
          'hospitalLat': hospitalLat,
          'hospitalLng': hospitalLng,
          if (requesterLat != null) 'requesterLat': requesterLat,
          if (requesterLng != null) 'requesterLng': requesterLng,
          'patientName': patientName,
          'description': description,
          'contactPhone': contactPhone,
        },
      );
      final createdRequest = BloodRequest.fromJson(row);
      await _notificationService?.sendNewRequestNotifications(createdRequest);
      return createdRequest;
    } catch (e) {
      throw Exception('Failed to create blood request: $e');
    }
  }

  Future<BloodRequest?> getActiveRequest(String userId) async {
    try {
      final row = await _api.getJson(
        '/api/v1/requests/active',
        query: {'userId': userId},
      );
      if (row == null) return null;
      return BloodRequest.fromJson(row);
    } catch (e) {
      throw Exception('Failed to fetch active request: $e');
    }
  }

  Future<List<BloodRequest>> getMyRequests(String userId) async {
    try {
      final result = await _api.getJsonList(
        '/api/v1/requests/mine',
        query: {'userId': userId},
      );
      return result.map((row) => BloodRequest.fromJson(row)).toList();
    } catch (e) {
      throw Exception('Failed to fetch requests: $e');
    }
  }

  Future<void> updateActiveRequest({
    required String requestId,
    required String requesterId,
    int? unitsNeeded,
    UrgencyLevel? urgencyLevel,
    String? description,
    String? contactPhone,
  }) async {
    await _api.patchJson(
      '/api/v1/requests/$requestId',
      body: {
        'requesterId': requesterId,
        if (unitsNeeded != null) 'unitsNeeded': unitsNeeded,
        if (urgencyLevel != null) 'urgencyLevel': urgencyLevel.name,
        if (description != null) 'description': description,
        if (contactPhone != null) 'contactPhone': contactPhone,
      },
    );
    await _audit?.log(
      requestId: requestId,
      eventType: 'updated',
      detail: 'Recipient updated request.',
      actorUserId: requesterId,
    );
  }

  Future<bool> cancelRequest(String requestId, String userId) async {
    try {
      final result = await _api.postJson(
        '/api/v1/requests/$requestId/cancel',
        body: {'userId': userId},
      );
      final ok = result['ok'] == true;
      if (ok) {
        await _audit?.log(
          requestId: requestId,
          eventType: 'cancelled',
          detail: 'Recipient cancelled.',
          actorUserId: userId,
        );
      }
      return ok;
    } catch (e) {
      throw Exception('Failed to cancel request: $e');
    }
  }
}
