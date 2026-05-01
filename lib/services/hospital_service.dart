import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital_request_match.dart';
import 'package:bloodconnect/services/database_service.dart';
import 'package:flutter/foundation.dart';

class HospitalService {
  final DatabaseService _db;

  HospitalService(this._db);

  static String normalizeFourDigitCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    final tail = digits.length > 4
        ? digits.substring(digits.length - 4)
        : digits;
    return tail.padLeft(4, '0');
  }

  Future<List<HospitalRequestMatch>> searchByDisplayCode({
    required String hospitalUserId,
    required String fourDigitInput,
  }) async {
    final code = normalizeFourDigitCode(fourDigitInput);
    if (code.length != 4) return [];

    final result = await _db.query(
      '''
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
        u.name AS donor_name,
        u.phone AS donor_phone
      FROM blood_requests br
      LEFT JOIN donor_responses dr ON dr.request_id = br.id AND dr.response_type = 'accepted'
      LEFT JOIN users u ON u.id = dr.donor_id
      WHERE br.hospital_id = @hospitalId::uuid
        AND REPLACE(SPLIT_PART(br.short_id, '-', 3), ' ', '') = @code
        AND br.status IN ('active', 'in_progress')
      ORDER BY br.created_at DESC
    ''',
      params: {'hospitalId': hospitalUserId, 'code': code},
    );

    return result.map((row) {
      final m = Map<String, dynamic>.from(row);
      final donorName = m.remove('donor_name')?.toString();
      final donorPhone = m.remove('donor_phone')?.toString();
      return HospitalRequestMatch(
        request: BloodRequest.fromJson(m),
        donorName: (donorName != null && donorName.isNotEmpty)
            ? donorName
            : null,
        donorPhone: (donorPhone != null && donorPhone.isNotEmpty)
            ? donorPhone
            : null,
      );
    }).toList();
  }

  Future<String?> verifyDonation({
    required String hospitalUserId,
    required String requestId,
    String? staffName,
  }) async {
    final result = await _db.query(
      r'''
      SELECT success, error_message
      FROM verify_request_donation(
        @requestId::uuid,
        @hospitalId::uuid,
        @staffName
      )
    ''',
      params: {
        'requestId': requestId,
        'hospitalId': hospitalUserId,
        'staffName': staffName,
      },
    );

    if (result.isEmpty) {
      return 'Run database/mvp_incremental.sql on Supabase (verify_request_donation).';
    }
    if (result.first['success'] == true) return null;
    return result.first['error_message']?.toString() ?? 'Verification failed';
  }

Future<List<Map<String, dynamic>>> getRecentAuditForRequest(
    String requestId,
  ) async {
    try {
      return await _db.query(
        '''
        SELECT event_type, detail, created_at
        FROM request_audit_log
        WHERE request_id = @requestId::uuid
        ORDER BY created_at ASC
        ''',
        params: {'requestId': requestId},
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInventory(String hospitalId) async {
    try {
      return await _db.query(
        '''
        SELECT
          blood_type,
          units_available,
          minimum_threshold,
          units_available < minimum_threshold AS is_low,
          last_updated
        FROM hospital_inventory
        WHERE hospital_id = @hospitalId::uuid
        ORDER BY blood_type
        ''',
        params: {'hospitalId': hospitalId},
      );
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, int>> getHospitalStats(String hospitalId) async {
    try {
      final result = await _db.query(
        '''
        SELECT
          COUNT(*) FILTER (WHERE status = 'in_progress') AS pending,
          COUNT(*) FILTER (WHERE status = 'fulfilled' AND DATE(fulfilled_at) = CURRENT_DATE) AS today,
          COUNT(*) FILTER (WHERE status = 'fulfilled') AS fulfilled_total
        FROM blood_requests
        WHERE hospital_id = @hospitalId::uuid
        ''',
        params: {'hospitalId': hospitalId},
      );
      if (result.isEmpty) return {'pending': 0, 'today': 0, 'fulfilled': 0};
      final row = result.first;
      return {
        'pending': (row['pending'] as int?) ?? 0,
        'today': (row['today'] as int?) ?? 0,
        'fulfilled': (row['fulfilled_total'] as int?) ?? 0,
      };
    } catch (e) {
      debugPrint('getHospitalStats failed: $e');
      return {'pending': 0, 'today': 0, 'fulfilled': 0};
    }
  }

  Future<List<Map<String, dynamic>>> getPendingRequests(String hospitalId) async {
    try {
      return await _db.query(
        '''
        SELECT
          br.id,
          br.short_id,
          br.blood_type,
          br.urgency_level,
          br.status,
          br.units_needed,
          br.created_at,
           br.expires_at,
           COALESCE(u_req.name, 'Direct Request')  AS requester_name,
           u_req.phone AS requester_phone,
          d.name      AS donor_name,
          d.blood_type AS donor_blood_type,
          d.phone     AS donor_phone,
          RIGHT(br.short_id, 4) AS display_code
        FROM blood_requests br
        LEFT JOIN users u_req ON u_req.id = br.requester_id
        LEFT JOIN donor_responses dr
          ON dr.request_id = br.id
          AND dr.response_type = 'accepted'
        LEFT JOIN users d ON d.id = dr.donor_id
        WHERE br.hospital_id = @hospitalId::uuid
          AND br.status IN ('active', 'in_progress')
        ORDER BY
          CASE br.urgency_level
            WHEN 'critical' THEN 1
            WHEN 'urgent'   THEN 2
            ELSE 3
          END,
          br.created_at DESC
        ''',
        params: {'hospitalId': hospitalId},
      );
    } catch (e) {
      debugPrint('getPendingRequests failed: $e');
      return [];
    }
  }
}

