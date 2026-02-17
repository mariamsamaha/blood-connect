import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital.dart';
import 'package:bloodconnect/services/database_service.dart';

class RequestService {
  final DatabaseService _db;

  RequestService(this._db);

/// Fetch all verified hospitals sorted by distance from user's location
Future<List<Hospital>> getHospitals({
  double? userLatitude,
  double? userLongitude,
}) async {
  try {
    // If user has location, sort by distance
    if (userLatitude != null && userLongitude != null) {
      final result = await _db.query('''
        SELECT 
          id,
          hospital_name,
          hospital_code,
          email,
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude,
          ROUND(
            (ST_Distance(
              location,
              ST_SetSRID(ST_MakePoint(@userLng, @userLat), 4326)
            ) / 1000)::numeric, 
            2
          ) as distance_km
        FROM users
        WHERE account_type = 'hospital'
          AND hospital_verified = TRUE
          AND is_active = TRUE
          AND location IS NOT NULL
        ORDER BY 
          ST_Distance(
            location,
            ST_SetSRID(ST_MakePoint(@userLng, @userLat), 4326)
          ) ASC
      ''', params: {
        'userLat': userLatitude,
        'userLng': userLongitude,
      });

      return result.map((row) => Hospital.fromJson(row)).toList();
    } else {
      // No user location - sort alphabetically
      final result = await _db.query('''
        SELECT 
          id,
          hospital_name,
          hospital_code,
          email,
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude
        FROM users
        WHERE account_type = 'hospital'
          AND hospital_verified = TRUE
          AND is_active = TRUE
        ORDER BY hospital_name ASC
      ''');

      return result.map((row) => Hospital.fromJson(row)).toList();
    }
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
        @bloodType,
        ST_SetSRID(ST_MakePoint(@matchingLng, @matchingLat), 4326),
        50,
        100
      )
    ''', params: {
      'bloodType': bloodType,
      'matchingLng': matchingLng,
      'matchingLat': matchingLat,
    });

    final donorCount = donorCountResult.first['donor_count'] as int;

    String requesterLocationSQL;
    if (requesterLat != null && requesterLng != null) {
      requesterLocationSQL = "ST_SetSRID(ST_MakePoint($requesterLng, $requesterLat), 4326)";
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
        ST_SetSRID(ST_MakePoint($hospitalLng, $hospitalLat), 4326),
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

    // Update user to be a recipient
    await _db.query('''
      UPDATE users
      SET 
        is_recipient = TRUE,
        active_mode = 'recipient_view',
        updated_at = NOW()
      WHERE id = @requesterId
    ''', params: {'requesterId': requesterId});

    return BloodRequest.fromJson(requestResult.first);
  } catch (e) {
    throw Exception('Failed to create blood request: $e');
  }
}

/// Get active request for a user
Future<BloodRequest?> getActiveRequest(String userId) async {
  try {
    // DEBUG: Check database connection
    print(' DEBUG: Checking active request for user: $userId');
    
    final dbCheck = await _db.query('SELECT current_database() as db');
    print('DEBUG: Connected to database: ${dbCheck.first['db']}');
    
    // DEBUG: Check if column exists
    final columnCheck = await _db.query('''
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'blood_requests' 
        AND column_name = 'requester_location'
    ''');
    print(' DEBUG: requester_location column exists: ${columnCheck.isNotEmpty}');
    
    // DEBUG: Count requests
    final countCheck = await _db.query('SELECT COUNT(*) as count FROM blood_requests');
    print(' DEBUG: Total requests in database: ${countCheck.first['count']}');
    
    // Try with requester_location first
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
    ''', params: {'userId': userId});

    print(' DEBUG: Query executed successfully, results: ${result.length}');
    
    if (result.isEmpty) return null;
    return BloodRequest.fromJson(result.first);
  } catch (e) {
    print(' DEBUG: Error in first query: $e');
    
    // If column doesn't exist, try without requester_location
    try {
      print(' DEBUG: Trying fallback query without requester_location');
      
      final result = await _db.query('''
        SELECT 
          *,
          ST_Y(hospital_location::geometry) as hospital_lat,
          ST_X(hospital_location::geometry) as hospital_lng
        FROM blood_requests
        WHERE requester_id = @userId
          AND status IN ('active', 'in_progress')
        ORDER BY created_at DESC
        LIMIT 1
      ''', params: {'userId': userId});

      print(' DEBUG: Fallback query succeeded, results: ${result.length}');
      
      if (result.isEmpty) return null;
      return BloodRequest.fromJson(result.first);
    } catch (e2) {
      print(' DEBUG: Fallback query also failed: $e2');
      throw Exception('Failed to fetch active request: $e2');
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
    ''', params: {'userId': userId});

    return result.map((row) => BloodRequest.fromJson(row)).toList();
  } catch (e) {
    throw Exception('Failed to fetch requests: $e');
  }
}

  /// Cancel a request
  Future<void> cancelRequest(String requestId, String userId) async {
    try {
      await _db.query('''
        WITH cancelled AS (
          UPDATE blood_requests
          SET 
            status = 'cancelled',
            updated_at = NOW()
          WHERE id = @requestId
            AND requester_id = @userId
            AND status IN ('active', 'in_progress')
          RETURNING id
        )
        UPDATE users
        SET 
          is_recipient = FALSE,
          active_mode = 'donor_view',
          updated_at = NOW()
        WHERE id = @userId
          AND EXISTS (SELECT 1 FROM cancelled)
      ''', params: {
        'requestId': requestId,
        'userId': userId,
      });
    } catch (e) {
      throw Exception('Failed to cancel request: $e');
    }
  }
}