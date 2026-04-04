import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/donor_response_entry.dart';
import 'package:bloodconnect/services/audit_log_service.dart';
import 'package:bloodconnect/services/database_service.dart';
import 'package:bloodconnect/utils/blood_compatibility.dart';

class DonorService {
  final DatabaseService _db;
  final AuditLogService? _audit;

  DonorService(this._db, {AuditLogService? audit}) : _audit = audit;

  Future<List<BloodRequest>> findMatchingRequests({
    required String donorId,
    required String donorBloodType,
    required double donorLat,
    required double donorLng,
    int radiusKm = 120,
  }) async {
    try {
      final params = <String, dynamic>{
        'donorId': donorId,
        'donorLng': donorLng,
        'donorLat': donorLat,
        'radiusM': radiusKm * 1000,
        'compatibleTypesCsv':
            (donorCanFulfillRequestTypes[donorBloodType] ??
                    <String>[donorBloodType])
                .join(','),
      };

      final result = await _db.query('''
  SELECT 
    br.id,
    br.short_id,
    br.requester_id,
    br.blood_type,
    br.units_needed,
    br.urgency_level,
    br.hospital_name,
    ST_Y(br.hospital_location::geometry) AS hospital_lat,
    ST_X(br.hospital_location::geometry) AS hospital_lng,
    ST_Y(br.requester_location::geometry) AS requester_lat,
    ST_X(br.requester_location::geometry) AS requester_lng,
    br.status,
    br.nearby_donors_count,
    br.total_eligible_count,
    br.created_at,
    br.expires_at,
    ROUND((
      ST_Distance(
        br.hospital_location,
        ST_SetSRID(ST_MakePoint(@donorLng::float8, @donorLat::float8), 4326)::geography
      ) / 1000
    )::numeric, 2) AS distance_km
  FROM blood_requests br
  WHERE br.status = 'active'
    AND br.expires_at > NOW()
    AND br.blood_type = ANY(string_to_array(@compatibleTypesCsv, ',')::varchar[])
    AND ST_Distance(
          br.hospital_location,
          ST_SetSRID(ST_MakePoint(@donorLng::float8, @donorLat::float8), 4326)::geography
        ) <= @radiusM::float8
    AND NOT EXISTS (
      SELECT 1 FROM donor_responses dr
      WHERE dr.request_id = br.id 
        AND dr.donor_id = @donorId::uuid
    )
  ORDER BY 
    CASE br.urgency_level 
      WHEN 'critical' THEN 1 
      WHEN 'urgent' THEN 2 
      ELSE 3 
    END,
    br.created_at DESC
''', params: params);

      return result.map((row) {
        final r = Map<String, dynamic>.from(row);
        final raw = row['distance_km'];
        r['distance_km'] =
            raw == null ? 0.0 : double.tryParse(raw.toString()) ?? 0.0;
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
      await _db.query('''
        WITH locked AS (
          SELECT id, status
          FROM blood_requests
          WHERE id = @requestId::uuid
          FOR UPDATE
        ),
        accepted AS (
          INSERT INTO donor_responses (request_id, donor_id, response_type, distance_km)
          SELECT @requestId::uuid, @donorId::uuid, 'accepted',
            ROUND(
              (ST_Distance(
                (SELECT hospital_location FROM blood_requests WHERE id = @requestId::uuid),
                ST_SetSRID(ST_MakePoint(@donorLng::float8, @donorLat::float8), 4326)::geography
              ) / 1000)::numeric, 2
            )
          FROM locked
          WHERE status = 'active'
          RETURNING id
        )
        UPDATE blood_requests br
        SET status = 'in_progress', updated_at = NOW()
        FROM locked, accepted
        WHERE br.id = @requestId::uuid AND locked.status = 'active'
      ''', params: {
        'requestId': requestId,
        'donorId': donorId,
        'donorLng': donorLng,
        'donorLat': donorLat,
      });

      final check = await _db.query('''
        SELECT response_type FROM donor_responses
        WHERE request_id = @requestId::uuid AND donor_id = @donorId::uuid
      ''', params: {'requestId': requestId, 'donorId': donorId});

      if (check.isEmpty || check.first['response_type'] != 'accepted') {
        throw Exception(
          'Could not accept: another donor may have already accepted.',
        );
      }

      final statusCheck = await _db.query('''
        SELECT status FROM blood_requests WHERE id = @requestId::uuid
      ''', params: {'requestId': requestId});
      if (statusCheck.isEmpty || statusCheck.first['status'] != 'in_progress') {
        throw Exception('Accept failed: request was taken by another donor.');
      }

      await _audit?.log(
        requestId: requestId,
        eventType: 'donor_accepted',
        detail: 'Atomic assignment to donor $donorId.',
        actorUserId: donorId,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('23505') ||
          msg.contains('unique') ||
          msg.contains('donor_responses_one_accepted')) {
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
      await _db.query('''
        INSERT INTO donor_responses (request_id, donor_id, response_type)
        VALUES (@requestId::uuid, @donorId::uuid, 'declined')
        ON CONFLICT (request_id, donor_id) DO UPDATE
        SET response_type = 'declined', updated_at = NOW()
      ''', params: {'requestId': requestId, 'donorId': donorId});
    } catch (e) {
      throw Exception('Failed to decline request: $e');
    }
  }

  Future<BloodRequest?> getActiveMission(String donorId) async {
    try {
      final result = await _db.query('''
        SELECT 
          br.id,
          br.short_id,
          br.requester_id,
          br.blood_type,
          br.units_needed,
          br.urgency_level,
          br.hospital_name,
          ST_Y(br.hospital_location::geometry) AS hospital_lat,
          ST_X(br.hospital_location::geometry) AS hospital_lng,
          ST_Y(br.requester_location::geometry) AS requester_lat,
          ST_X(br.requester_location::geometry) AS requester_lng,
          br.status,
          br.nearby_donors_count,
          br.total_eligible_count,
          br.created_at,
          br.expires_at
        FROM blood_requests br
        INNER JOIN donor_responses dr ON dr.request_id = br.id AND dr.donor_id = @donorId::uuid
        WHERE dr.response_type = 'accepted'
          AND br.status IN ('active', 'in_progress')
        ORDER BY br.created_at DESC
        LIMIT 1
      ''', params: {'donorId': donorId});

      if (result.isEmpty) return null;
      return BloodRequest.fromJson(result.first);
    } catch (e) {
      throw Exception('Failed to get active mission: $e');
    }
  }

  Future<List<DonorResponseEntry>> getDonorResponseHistory(String donorId) async {
    try {
      final result = await _db.query('''
        SELECT br.id AS request_id, br.short_id, br.hospital_name, br.blood_type,
               dr.response_type, dr.responded_at
        FROM donor_responses dr
        JOIN blood_requests br ON br.id = dr.request_id
        WHERE dr.donor_id = @donorId::uuid
        ORDER BY dr.responded_at DESC
      ''', params: {'donorId': donorId});
      return result.map((row) => DonorResponseEntry.fromJson(row)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, int>> getDonorStats(String donorId) async {
    try {
      final result = await _db.query('''
        SELECT total_donations, reward_points
        FROM users WHERE id = @donorId::uuid
      ''', params: {'donorId': donorId});
      if (result.isEmpty) return {'totalDonations': 0, 'rewardPoints': 0};
      final r = result.first;
      return {
        'totalDonations': r['total_donations'] as int? ?? 0,
        'rewardPoints': r['reward_points'] as int? ?? 0,
      };
    } catch (e) {
      return {'totalDonations': 0, 'rewardPoints': 0};
    }
  }
}
