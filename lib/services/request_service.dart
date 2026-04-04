import 'dart:async';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital.dart';
import 'package:bloodconnect/services/audit_log_service.dart';
import 'package:bloodconnect/services/database_service.dart';
import 'package:bloodconnect/services/notification_service.dart';

class RequestService {
  final DatabaseService _db;
  final NotificationService? _notificationService;
  final AuditLogService? _audit;

  RequestService(
    this._db, {
    NotificationService? notificationService,
    AuditLogService? audit,
  })  : _notificationService = notificationService,
        _audit = audit;

/// Verified hospitals with coordinates; nearby radius first, then all by distance.
Future<List<Hospital>> getHospitals({
  double? userLatitude,
  double? userLongitude,
  int nearbyRadiusKm = 120,
}) async {
  try {
    const baseWhere = '''
        account_type = 'hospital'
          AND hospital_verified = TRUE
          AND is_active = TRUE
          AND location IS NOT NULL
    ''';

    if (userLatitude != null && userLongitude != null) {
      final userPoint =
          'ST_SetSRID(ST_MakePoint(@userLng::float8, @userLat::float8), 4326)::geography';
      final nearbyM = nearbyRadiusKm * 1000;

      var result = await _db.query('''
        SELECT 
          id,
          hospital_name,
          hospital_code,
          email,
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude,
          ROUND((ST_Distance(location, $userPoint) / 1000)::numeric, 2) as distance_km
        FROM users
        WHERE $baseWhere
          AND ST_DWithin(location, $userPoint, @nearbyM::float8)
        ORDER BY ST_Distance(location, $userPoint) ASC
      ''', params: {
        'userLat': userLatitude,
        'userLng': userLongitude,
        'nearbyM': nearbyM,
      });

      if (result.isEmpty) {
        result = await _db.query('''
          SELECT 
            id,
            hospital_name,
            hospital_code,
            email,
            ST_Y(location::geometry) as latitude,
            ST_X(location::geometry) as longitude,
            ROUND((ST_Distance(location, $userPoint) / 1000)::numeric, 2) as distance_km
          FROM users
          WHERE $baseWhere
          ORDER BY ST_Distance(location, $userPoint) ASC
        ''', params: {
          'userLat': userLatitude,
          'userLng': userLongitude,
        });
      }

      return result.map((row) => Hospital.fromJson(row)).toList();
    }

    final result = await _db.query('''
        SELECT 
          id,
          hospital_name,
          hospital_code,
          email,
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude
        FROM users
        WHERE $baseWhere
        ORDER BY hospital_name ASC
      ''');

    return result.map((row) => Hospital.fromJson(row)).toList();
  } catch (e) {
    throw Exception('Failed to fetch hospitals: $e');
  }
}

/// Create a new blood request with fresh location
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
    // Get hospital info
    final hospitalResult = await _db.query('''
      SELECT hospital_code, hospital_name
      FROM users
      WHERE id = @hospitalId AND account_type = 'hospital'
    ''', params: {'hospitalId': hospitalId});

    if (hospitalResult.isEmpty) {
      throw Exception('Hospital not found');
    }

    final hospitalCode = hospitalResult.first['hospital_code'] as String;
    final hospitalName = hospitalResult.first['hospital_name'] as String;

    //  Generate short ID
    final shortIdResult = await _db.query('''
      SELECT generate_short_request_id(@hospitalCode) as short_id
    ''', params: {'hospitalCode': hospitalCode});

    final shortId = shortIdResult.first['short_id'] as String;

    //  Determine matching location
    final matchingLat = requesterLat ?? hospitalLat;
    final matchingLng = requesterLng ?? hospitalLng;

    // Count nearby donors
    final donorCountResult = await _db.query('''
  SELECT COUNT(*) as donor_count
  FROM find_nearby_donors(
    @bloodType::varchar(3),
    ST_SetSRID(ST_MakePoint(@matchingLng::float8, @matchingLat::float8), 4326)::geography,
    120,
    200
     )
    ''', params: {
      'bloodType': bloodType,
      'matchingLng': matchingLng,
      'matchingLat': matchingLat,
    });

    final donorCount = donorCountResult.first['donor_count'] as int;

    String requesterLocationSQL;
    if (requesterLat != null && requesterLng != null) {
      requesterLocationSQL =
          "ST_SetSRID(ST_MakePoint($requesterLng, $requesterLat), 4326)::geography";
    } else {
      requesterLocationSQL = "NULL";
    }

    final requestResult = await _db.query('''
      INSERT INTO blood_requests (
        short_id,
        requester_id,
        blood_type,
        units_needed,
        urgency_level,
        hospital_id,
        hospital_name,
        hospital_location,
        requester_location,
        patient_name,
        description,
        contact_phone,
        status,
        nearby_donors_count,
        total_eligible_count,
        expires_at
      ) VALUES (
        @shortId,
        @requesterId,
        @bloodType,
        @unitsNeeded,
        @urgencyLevel,
        @hospitalId,
        @hospitalName,
        ST_SetSRID(ST_MakePoint($hospitalLng, $hospitalLat), 4326)::geography,
        $requesterLocationSQL,
        @patientName,
        @description,
        @contactPhone,
        'active',
        @donorCount,
        @donorCount,
        NOW() + INTERVAL '24 hours'
      )
      RETURNING 
        id,
        short_id,
        requester_id,
        blood_type,
        units_needed,
        urgency_level,
        hospital_name,
        ST_Y(hospital_location::geometry) as hospital_lat,
        ST_X(hospital_location::geometry) as hospital_lng,
        ST_Y(requester_location::geometry) as requester_lat,
        ST_X(requester_location::geometry) as requester_lng,
        patient_name,
        description,
        contact_phone,
        status,
        nearby_donors_count,
        total_eligible_count,
        created_at,
        expires_at
    ''', params: {
      'shortId': shortId,
      'requesterId': requesterId,
      'bloodType': bloodType,
      'unitsNeeded': unitsNeeded,
      'urgencyLevel': urgencyLevel.name,
      'hospitalId': hospitalId,
      'hospitalName': hospitalName,
      'patientName': patientName,
      'description': description,
      'contactPhone': contactPhone,
      'donorCount': donorCount,
    });

    if (requestResult.isEmpty) {
      throw Exception('Failed to insert request');
    }

    final createdRequest = BloodRequest.fromJson(requestResult.first);

    await _audit?.log(
      requestId: createdRequest.id,
      eventType: 'created',
      detail: 'Request opened; id=${createdRequest.shortId}',
      actorUserId: requesterId,
    );

    // Update user to be a recipient
    await _db.query('''
      UPDATE users
      SET 
        is_recipient = TRUE,
        active_mode = 'recipient_view',
        updated_at = NOW()
      WHERE id = @requesterId
    ''', params: {'requesterId': requesterId});

    // Fire-and-forget best-effort push notification to donors
    unawaited(_notificationService?.sendNewRequestNotifications(createdRequest));

    return createdRequest;
  } catch (e) {
    throw Exception('Failed to create blood request: $e');
  }
}

  /// Get the current active or in-progress request for a recipient.
  Future<BloodRequest?> getActiveRequest(String userId) async {
    try {
      final result = await _db.query('''
        SELECT 
          id,
          short_id,
          requester_id,
          blood_type,
          units_needed,
          urgency_level,
          hospital_name,
          status,
          nearby_donors_count,
          total_eligible_count,
          created_at,
          expires_at,
          ST_Y(hospital_location::geometry) as hospital_lat,
          ST_X(hospital_location::geometry) as hospital_lng,
          ST_Y(requester_location::geometry) as requester_lat,
          ST_X(requester_location::geometry) as requester_lng
        FROM blood_requests
        WHERE requester_id = @userId
          AND status IN ('active', 'in_progress')
        ORDER BY created_at DESC
        LIMIT 1
      ''', params: {'userId': userId.toString()});

      if (result.isEmpty) return null;
      return BloodRequest.fromJson(result.first);
    } catch (e) {
      try {
        final result = await _db.query('''
          SELECT 
            id, short_id, requester_id, blood_type, units_needed, urgency_level,
            hospital_name, status, nearby_donors_count, total_eligible_count,
            created_at, expires_at,
            ST_Y(hospital_location::geometry) as hospital_lat,
            ST_X(hospital_location::geometry) as hospital_lng
          FROM blood_requests
          WHERE requester_id = @userId
            AND status IN ('active', 'in_progress')
          ORDER BY created_at DESC
          LIMIT 1
        ''', params: {'userId': userId.toString()});
        if (result.isEmpty) return null;
        return BloodRequest.fromJson(result.first);
      } catch (_) {
        rethrow;
      }
    }
  }

Future<List<BloodRequest>> getMyRequests(String userId) async {
  try {
    final result = await _db.query('''
      SELECT *,
        ST_Y(hospital_location::geometry) as hospital_lat,
        ST_X(hospital_location::geometry) as hospital_lng,
        ST_Y(requester_location::geometry) as requester_lat,
        ST_X(requester_location::geometry) as requester_lng
      FROM blood_requests
      WHERE requester_id = @userId
      ORDER BY created_at DESC
    ''', params: {'userId': userId.toString()});

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
    final sets = <String>[];
    final params = <String, dynamic>{
      'requestId': requestId,
      'requesterId': requesterId,
    };
    if (unitsNeeded != null) {
      sets.add('units_needed = @unitsNeeded');
      params['unitsNeeded'] = unitsNeeded;
    }
    if (urgencyLevel != null) {
      sets.add('urgency_level = @urgencyLevel');
      params['urgencyLevel'] = urgencyLevel.name;
    }
    if (description != null) {
      sets.add('description = @description');
      params['description'] = description;
    }
    if (contactPhone != null) {
      sets.add('contact_phone = @contactPhone');
      params['contactPhone'] = contactPhone;
    }
    if (sets.isEmpty) return;

    final result = await _db.query('''
        UPDATE blood_requests SET
          ${sets.join(', ')},
          updated_at = NOW()
        WHERE id = @requestId::uuid
          AND requester_id = @requesterId::uuid
          AND status = 'active'
        RETURNING id
      ''', params: params);
    if (result.isEmpty) {
      throw Exception('Cannot update: request not open.');
    }
    await _audit?.log(
      requestId: requestId,
      eventType: 'updated',
      detail: 'Recipient updated request.',
      actorUserId: requesterId,
    );
  }

  Future<bool> cancelRequest(String requestId, String userId) async {
    try {
      final result = await _db.query('''
        WITH cancelled AS (
          UPDATE blood_requests
          SET 
            status = 'cancelled',
            updated_at = NOW()
          WHERE id = @requestId::uuid
            AND requester_id = @userId::uuid
            AND status IN ('active', 'in_progress')
          RETURNING id
        )
        UPDATE users
        SET 
          is_recipient = FALSE,
          active_mode = 'donor_view',
          updated_at = NOW()
        WHERE id = @userId::uuid
          AND EXISTS (SELECT 1 FROM cancelled)
        RETURNING id
      ''', params: {
        'requestId': requestId,
        'userId': userId,
      });
      final ok = result.isNotEmpty;
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