import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/donor_response_entry.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/audit_log_service.dart';
import 'package:bloodconnect/utils/blood_compatibility.dart';

class DonorService {
  final ApiClient _api;
  final AuditLogService? _audit;

  DonorService(this._api, {AuditLogService? audit}) : _audit = audit;

  Future<List<BloodRequest>> findMatchingRequests({
    required String donorId,
    required String donorBloodType,
    required double donorLat,
    required double donorLng,
    int radiusKm = 120,
  }) async {
    try {
      final compatible =
          (donorCanFulfillRequestTypes[donorBloodType] ?? <String>[donorBloodType])
              .join(',');
      final result = await _api.getJsonList(
        '/api/v1/donor/matches',
        query: {
          'donorId': donorId,
          'donorLat': donorLat.toString(),
          'donorLng': donorLng.toString(),
          'radiusKm': radiusKm.toString(),
          'compatibleTypesCsv': compatible,
        },
      );

      return result.map((row) {
        final r = Map<String, dynamic>.from(row);
        final raw = row['distance_km'];
        r['distance_km'] = raw == null
            ? 0.0
            : double.tryParse(raw.toString()) ?? 0.0;
        return BloodRequest.fromJson(r);
      }).toList();
    } catch (e) {
      throw Exception('Failed to find matching requests: $e');
    }
  }

  Future<void> acceptRequest({
    required String requestId,
    required String donorId,
    required double donorLat,
    required double donorLng,
  }) async {
    try {
      await _api.postEmpty(
        '/api/v1/donor/responses/accept',
        body: {
          'requestId': requestId,
          'donorId': donorId,
          'donorLat': donorLat,
          'donorLng': donorLng,
        },
      );
      await _audit?.log(
        requestId: requestId,
        eventType: 'donor_accepted',
        detail: 'Atomic assignment to donor $donorId.',
        actorUserId: donorId,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('already_accepted') || msg.contains('accept_failed')) {
        throw Exception('Another donor already accepted this request.');
      }
      if (e is Exception) rethrow;
      throw Exception('Failed to accept request: $e');
    }
  }

  Future<void> declineRequest({
    required String requestId,
    required String donorId,
  }) async {
    try {
      await _api.postEmpty(
        '/api/v1/donor/responses/decline',
        body: {'requestId': requestId, 'donorId': donorId},
      );
    } catch (e) {
      throw Exception('Failed to decline request: $e');
    }
  }

  Future<BloodRequest?> getActiveMission(String donorId) async {
    try {
      final row = await _api.getJson(
        '/api/v1/donor/mission',
        query: {'donorId': donorId},
      );
      if (row == null) return null;
      return BloodRequest.fromJson(row);
    } catch (e) {
      throw Exception('Failed to get active mission: $e');
    }
  }

  Future<List<DonorResponseEntry>> getDonorResponseHistory(String donorId) async {
    try {
      final result = await _api.getJsonList(
        '/api/v1/donor/responses/history',
        query: {'donorId': donorId},
      );
      return result.map((row) => DonorResponseEntry.fromJson(row)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, int>> getDonorStats(String donorId) async {
    try {
      final row = await _api.getJson(
        '/api/v1/donor/stats',
        query: {'donorId': donorId},
      );
      if (row == null) return {'totalDonations': 0, 'rewardPoints': 0};
      int parseInt(dynamic v) {
        if (v == null) return 0;
        if (v is int) return v;
        if (v is double) return v.toInt();
        return int.tryParse(v.toString()) ?? 0;
      }
      return {
        'totalDonations': parseInt(row['totalDonations']),
        'rewardPoints': parseInt(row['rewardPoints']),
      };
    } catch (e) {
      return {'totalDonations': 0, 'rewardPoints': 0};
    }
  }

  Future<void> withdrawAcceptance({
    required String requestId,
    required String donorId,
  }) async {
    try {
      await _api.postEmpty(
        '/api/v1/donor/responses/withdraw',
        body: {'requestId': requestId, 'donorId': donorId},
      );
      await _audit?.log(
        requestId: requestId,
        eventType: 'donor_withdrew',
        detail: 'Donor withdrew acceptance.',
        actorUserId: donorId,
      );
    } catch (e) {
      throw Exception('Failed to withdraw acceptance: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFullDonationHistory(String donorId) async {
    try {
      return await _api.getJsonList(
        '/api/v1/donor/donations',
        query: {'donorId': donorId},
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 20}) async {
    try {
      return await _api.getJsonList(
        '/api/v1/donor/leaderboard',
        query: {'limit': limit.toString()},
      );
    } catch (_) {
      return [];
    }
  }

  Future<int?> getMyRank(String userId) async {
    try {
      final row = await _api.getJson(
        '/api/v1/donor/rank',
        query: {'userId': userId},
      );
      final val = row?['rank'];
      if (val == null) return null;
      if (val is int) return val;
      if (val is double) return val.toInt();
      return int.tryParse(val.toString());
    } catch (_) {
      return null;
    }
  }
}
