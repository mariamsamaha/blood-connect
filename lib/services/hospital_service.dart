import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital_request_match.dart';
import 'package:bloodconnect/services/database_service.dart';

class HospitalService {
  final DatabaseService _db;

  HospitalService(this._db);

  static String normalizeFourDigitCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    final tail =
        digits.length > 4 ? digits.substring(digits.length - 4) : digits;
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
        AND split_part(br.short_id, '-', 3) = @code
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
        donorName:
            (donorName != null && donorName.isNotEmpty) ? donorName : null,
        donorPhone:
            (donorPhone != null && donorPhone.isNotEmpty) ? donorPhone : null,
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
}
