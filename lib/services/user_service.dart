import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/database_service.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final DatabaseService _db;

  UserService(this._db);

  /// Firebase custom claims for hospital admin (MVP).
  static Future<bool> hasHospitalAdminClaim(User firebaseUser) async {
    try {
      final token = await firebaseUser.getIdTokenResult(true);
      final c = token.claims;
      if (c == null) return false;
      if (c['hospital_admin'] == true) return true;
      return c['role'] == 'hospital';
    } catch (_) {
      return false;
    }
  }

  Future<UserProfile?> getProfileByFirebaseUid(String firebaseUid) async {
    try {
      final result = await _db.query(
        '''
        SELECT *, 
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude
        FROM users 
        WHERE firebase_uid = @uid
      ''',
        params: {'uid': firebaseUid},
      );

      if (result.isEmpty) return null;
      return UserProfile.fromJson(result.first);
    } on Exception catch (e) {
      throw Exception('Database error while fetching user profile: $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching user profile: $e');
    }
  }

  Future<UserProfile> createOrFetchProfile(User firebaseUser) async {
    try {
      final existing = await _db.query(
        '''
        SELECT *, 
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude
        FROM users 
        WHERE firebase_uid = @uid
      ''',
        params: {'uid': firebaseUser.uid},
      );

      if (existing.isNotEmpty) return UserProfile.fromJson(existing.first);

      // New user — check if email is a hospital domain
      final isHospital = await _db.query(
        "SELECT is_hospital_email(@email)",
        params: {'email': firebaseUser.email},
      );

      final accountType = (isHospital.first.values.first == true)
          ? 'hospital'
          : 'regular';

      // Insert into PostgreSQL
      final row = await _db.query(
        '''
        INSERT INTO users (
          firebase_uid, email, name, account_type,
          is_recipient, donor_status, role
        ) VALUES (
          @uid, @email, @name, @accountType,
          FALSE, 'available',
          @role
        ) RETURNING *, 
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude;
      ''',
        params: {
          'uid': firebaseUser.uid,
          'email': firebaseUser.email!,
          'name': firebaseUser.displayName ?? 'User',
          'accountType': accountType,
          'role': accountType == 'hospital' ? 'hospital' : 'donor',
        },
      );

      return UserProfile.fromJson(row.first);
    } on Exception catch (e) {
      throw Exception('Database error while creating user profile: $e');
    } catch (e) {
      throw Exception('Unexpected error while creating user profile: $e');
    }
  }

  Future<UserProfile> createCompleteProfile(
    User firebaseUser, {
    required String name,
    required String email,
    required String phone,
    required String bloodType,
    required String role, // 'donor' or 'recipient'
    required String accountType, // 'regular' or 'hospital'
    String? hospitalName,
    String? hospitalCode,
    double? latitude,
    double? longitude,
    String? cityArea,
  }) async {
    try {
      // Check if profile already exists by firebase_uid
      final existing = await _db.query(
        '''
        SELECT *, 
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude
        FROM users 
        WHERE firebase_uid = @uid
      ''',
        params: {'uid': firebaseUser.uid},
      );

      if (existing.isNotEmpty) return UserProfile.fromJson(existing.first);

      // Check if email already exists (from previous incomplete signup)
      final existingByEmail = await _db.query(
        '''
        SELECT *, 
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude
        FROM users 
        WHERE email = @email
      ''',
        params: {'email': email},
      );

      if (existingByEmail.isNotEmpty) {
        // Update existing record with new firebase_uid
        final updated = await _db.query(
          '''
          UPDATE users 
          SET firebase_uid = @uid, 
              name = @name, 
              phone = @phone,
              updated_at = NOW()
          WHERE email = @email
          RETURNING *, 
            ST_Y(location::geometry) as latitude,
            ST_X(location::geometry) as longitude;
        ''',
          params: {
            'uid': firebaseUser.uid,
            'email': email,
            'name': name,
            'phone': phone,
          },
        );
        return UserProfile.fromJson(updated.first);
      }

      final Map<String, dynamic> params;
      final String sql;

      if (accountType == 'hospital') {
        final locationSql = latitude != null && longitude != null
            ? 'ST_SetSRID(ST_MakePoint(@longitude, @latitude), 4326)::geography'
            : 'ST_SetSRID(ST_MakePoint(31.2357, 30.0444), 4326)::geography';

        sql =
            '''
          INSERT INTO users (
            firebase_uid, email, name, phone,
            account_type, hospital_name, hospital_code, 
            is_recipient, donor_status, role, location,
            hospital_verified, city_area
          ) VALUES (
            @uid, @email, @name, @phone,
            'hospital', @hospitalName, @hospitalCode,
            FALSE, 'unavailable', 'hospital', $locationSql,
            TRUE, @cityArea
          ) RETURNING *, 
            ST_Y(location::geometry) as latitude,
            ST_X(location::geometry) as longitude;
        ''';
        params = {
          'uid': firebaseUser.uid,
          'email': email,
          'name': name,
          'phone': phone,
          'hospitalName': hospitalName,
          'hospitalCode': hospitalCode,
          'cityArea': cityArea ?? '',
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        };
      } else {
        final donorStatus = role == 'donor' ? 'available' : 'unavailable';

        String locationSql = latitude != null && longitude != null
            ? "ST_SetSRID(ST_MakePoint(@longitude, @latitude), 4326)::geography"
            : 'NULL';

        sql =
            '''
          INSERT INTO users (
            firebase_uid, email, name, phone, blood_type,
            account_type, is_recipient, donor_status, role, location,
            city_area
          ) VALUES (
            @uid, @email, @name, @phone, @bloodType,
            'regular', FALSE, @donorStatus, @role, $locationSql,
            @cityArea
          ) RETURNING *, 
            ST_Y(location::geometry) as latitude,
            ST_X(location::geometry) as longitude;
        ''';
        params = {
          'uid': firebaseUser.uid,
          'email': email,
          'name': name,
          'phone': phone,
          'bloodType': bloodType,
          'role': role,
          'donorStatus': donorStatus,
          'cityArea': cityArea ?? '',
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        };
      }

      final row = await _db.query(sql, params: params);
      return UserProfile.fromJson(row.first);
    } on Exception catch (e) {
      throw Exception('Database error while creating user profile: $e');
    } catch (e) {
      throw Exception('Unexpected error while creating user profile: $e');
    }
  }

/// Save FCM token for push notifications (e.g. donor request alerts).
  Future<void> updateFcmToken(String firebaseUid, String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await _db.query(
        '''
        UPDATE users SET fcm_token = @token, updated_at = NOW()
        WHERE firebase_uid = @uid
        ''',
        params: {'uid': firebaseUid, 'token': token},
      );
      debugPrint('FCM token saved for $firebaseUid');
    } catch (e) {
      debugPrint('FCM token save FAILED for $firebaseUid: $e');
      debugPrint('Make sure mvp_incremental.sql has been run on Supabase (adds fcm_token column).');
    }
  }

  /// Get badges earned by user
  Future<List<Map<String, dynamic>>> getUserBadges(String userId) async {
    try {
      return await _db.query(
        '''
        SELECT b.id, b.badge_name AS name, b.description, 
               b.icon_url AS icon, b.requirement_value AS points_required, 
               ub.earned_at
        FROM user_badges ub
        JOIN badges b ON b.id = ub.badge_id
        WHERE ub.user_id = @userId::uuid
        ORDER BY ub.earned_at DESC
        ''',
        params: {'userId': userId},
      );
    } catch (e) {
      return [];
    }
  }

  /// Get all badges with progress for user
  Future<List<Map<String, dynamic>>> getAllBadgesWithProgress(String userId) async {
    try {
      return await _db.query(
        '''
        SELECT
          b.id,
          b.badge_name AS name,
          b.description,
          b.icon_url AS icon,
          b.requirement_value,
          b.requirement_type,
          ub.earned_at IS NOT NULL AS is_earned,
          CASE b.requirement_type
            WHEN 'donation_count' THEN u.total_donations
            WHEN 'points' THEN COALESCE(u.reward_points, 0)
            ELSE 0
          END AS current_value
        FROM badges b
        CROSS JOIN users u
        LEFT JOIN user_badges ub
          ON ub.badge_id = b.id AND ub.user_id = u.id
        WHERE u.id = @userId::uuid
        ORDER BY is_earned DESC, b.requirement_value ASC
        ''',
        params: {'userId': userId},
      );
    } catch (e) {
      return [];
    }
  }
}
