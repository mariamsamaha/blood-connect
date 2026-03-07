import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/services/database_service.dart';

/// Blood type compatibility: which request types a donor can fulfill.
/// E.g. donor O- can fulfill any request; donor A+ can fulfill A+ and AB+.
const _donorCanFulfill = <String, List<String>>{
  'O-': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
  'O+': ['O+', 'A+', 'B+', 'AB+'],
  'A-': ['A-', 'A+', 'AB-', 'AB+'],
  'A+': ['A+', 'AB+'],
  'B-': ['B-', 'B+', 'AB-', 'AB+'],
  'B+': ['B+', 'AB+'],
  'AB-': ['AB-', 'AB+'],
  'AB+': ['AB+'],
};

class DonorService {
  final DatabaseService _db;

  DonorService(this._db);

  /// Returns list of request blood types that this donor's blood type can fulfill.
  List<String> getCompatibleRequestBloodTypes(String donorBloodType) {
    return _donorCanFulfill[donorBloodType] ?? [];
  }

  /// Find active requests matching donor's blood type and within radius (km).
  /// Excludes requests this donor has already declined.
  Future<List<BloodRequest>> findMatchingRequests({
    required String donorId,
    required String donorBloodType,
    required double donorLat,
    required double donorLng,
    int radiusKm = 50,
  }) async {
    final compatible = getCompatibleRequestBloodTypes(donorBloodType);
    if (compatible.isEmpty) return [];

    try {
      // Build IN clause for compatible types
      final placeholders = compatible.asMap().entries.map((e) => '@t${e.key}').join(', ');
      final params = <String, dynamic>{
        'donorId': donorId,
        'donorLng': donorLng,
        'donorLat': donorLat,
        'radiusM': radiusKm * 1000,
      };
      for (var i = 0; i < compatible.length; i++) {
        params['t$i'] = compatible[i];
      }

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
          ROUND(
            (ST_Distance(
              br.hospital_location,
              ST_SetSRID(ST_MakePoint(@donorLng, @donorLat), 4326)
            ) / 1000)::numeric, 2
          ) AS distance_km
        FROM blood_requests br
        WHERE br.status = 'active'
          AND br.blood_type IN ($placeholders)
          AND br.expires_at > NOW()
          AND ST_DWithin(
            br.hospital_location,
            ST_SetSRID(ST_MakePoint(@donorLng, @donorLat), 4326),
            @radiusM
          )
          AND NOT EXISTS (
            SELECT 1 FROM donor_responses dr
            WHERE dr.request_id = br.id AND dr.donor_id = @donorId
          )
        ORDER BY CASE br.urgency_level WHEN 'critical' THEN 1 WHEN 'urgent' THEN 2 ELSE 3 END, distance_km ASC
      ''', params: params);

      return result.map((row) {
        final r = Map<String, dynamic>.from(row);
        r['distance_km'] = (row['distance_km'] as num?)?.toDouble() ?? 0.0;
        return BloodRequest.fromJson(r);
      }).toList();
    } catch (e) {
      throw Exception('Failed to find matching requests: $e');
    }
  }

  /// Accept a request: atomic update so only one donor can accept.
  /// Locks the request row, checks status is still active, inserts response, updates request.
  Future<void> acceptRequest({
    required String requestId,
    required String donorId,
    required double donorLat,
    required double donorLng,
  }) async {
    try {
      // Use a single transaction: lock request, check active, insert response, update request.
      await _db.query('''
        WITH locked AS (
          SELECT id, status
          FROM blood_requests
          WHERE id = @requestId
          FOR UPDATE
        ),
        accepted AS (
          INSERT INTO donor_responses (request_id, donor_id, response_type, distance_km)
          SELECT @requestId, @donorId, 'accepted',
            ROUND(
              (ST_Distance(
                (SELECT hospital_location FROM blood_requests WHERE id = @requestId),
                ST_SetSRID(ST_MakePoint(@donorLng, @donorLat), 4326)
              ) / 1000)::numeric, 2
            )
          FROM locked
          WHERE status = 'active'
          RETURNING id
        )
        UPDATE blood_requests br
        SET status = 'in_progress', updated_at = NOW()
        FROM locked, accepted
        WHERE br.id = @requestId AND locked.status = 'active'
      ''', params: {
        'requestId': requestId,
        'donorId': donorId,
        'donorLng': donorLng,
        'donorLat': donorLat,
      });

      // Verify that we actually updated (another donor might have won)
      final check = await _db.query('''
        SELECT response_type FROM donor_responses
        WHERE request_id = @requestId AND donor_id = @donorId
      ''', params: {'requestId': requestId, 'donorId': donorId});

      if (check.isEmpty || check.first['response_type'] != 'accepted') {
        throw Exception('Could not accept: request may already be taken or invalid');
      }

      final statusCheck = await _db.query('''
        SELECT status FROM blood_requests WHERE id = @requestId
      ''', params: {'requestId': requestId});
      if (statusCheck.isEmpty || statusCheck.first['status'] != 'in_progress') {
        throw Exception('Accept failed: request was taken by another donor');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to accept request: $e');
    }
  }

  /// Decline a request (record so we don't show it again to this donor).
  Future<void> declineRequest({
    required String requestId,
    required String donorId,
  }) async {
    try {
      await _db.query('''
        INSERT INTO donor_responses (request_id, donor_id, response_type)
        VALUES (@requestId, @donorId, 'declined')
        ON CONFLICT (request_id, donor_id) DO UPDATE
        SET response_type = 'declined', updated_at = NOW()
      ''', params: {'requestId': requestId, 'donorId': donorId});
    } catch (e) {
      throw Exception('Failed to decline request: $e');
    }
  }

  /// Get the active mission (request this donor has accepted and is in progress).
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
        INNER JOIN donor_responses dr ON dr.request_id = br.id AND dr.donor_id = @donorId
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

  /// Donor stats for display (total donations, reward points from profile - use UserService for full profile).
  Future<Map<String, int>> getDonorStats(String donorId) async {
    try {
      final result = await _db.query('''
        SELECT total_donations, reward_points
        FROM users WHERE id = @donorId
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
