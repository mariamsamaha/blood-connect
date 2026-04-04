import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/database_service.dart';

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
          is_donor, is_recipient, donor_status, active_mode
        ) VALUES (
          @uid, @email, @name, @accountType,
          FALSE, FALSE, 'unavailable',
          @defaultMode
        ) RETURNING *, 
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude;
      ''',
        params: {
          'uid': firebaseUser.uid,
          'email': firebaseUser.email!,
          'name': firebaseUser.displayName ?? 'User',
          'accountType': accountType,
          'defaultMode': accountType == 'hospital'
              ? 'hospital_view'
              : 'donor_view',
        },
      );

      return UserProfile.fromJson(row.first);
    } on Exception catch (e) {
      throw Exception('Database error while creating user profile: $e');
    } catch (e) {
      throw Exception('Unexpected error while creating user profile: $e');
    }
  }

  Future<UserProfile> getCurrentProfile() async {
    // This would normally get the current Firebase user and fetch their profile
    throw UnimplementedError('Implement getCurrentProfile');
  }

  Future<UserProfile> createCompleteProfile(
    User firebaseUser, {
    required String name,
    required String email,
    required String phone,
    required String bloodType,
    required bool canDonate,
    required String accountType,
    String? hospitalName,
    String? hospitalCode,

    /// For regular users: 'donor_view' or 'recipient_view' (role chosen at signup).
    String activeMode = 'donor_view',
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
            is_donor, is_recipient, donor_status, active_mode, location,
            hospital_verified, city_area
          ) VALUES (
            @uid, @email, @name, @phone,
            'hospital', @hospitalName, @hospitalCode,
            FALSE, FALSE, 'unavailable', 'hospital_view', $locationSql,
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
        final mode = activeMode == 'recipient_view'
            ? 'recipient_view'
            : 'donor_view';
        String locationSql = latitude != null && longitude != null
            ? "ST_SetSRID(ST_MakePoint(@longitude, @latitude), 4326)::geography"
            : 'NULL';

        sql =
            '''
          INSERT INTO users (
            firebase_uid, email, name, phone, blood_type,
            account_type, is_donor, is_recipient, donor_status, active_mode, location,
            city_area
          ) VALUES (
            @uid, @email, @name, @phone, @bloodType,
            'regular', @canDonate, FALSE, @donorStatus, @activeMode, $locationSql,
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
          'canDonate': canDonate,
          'donorStatus': canDonate ? 'available' : 'unavailable',
          'activeMode': mode,
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

  Future<bool> updateActiveMode(String firebaseUid, ActiveMode mode) async {
    final result = await _db.query(
      '''
      UPDATE users SET active_mode = @mode, updated_at = NOW()
      WHERE firebase_uid = @uid
      RETURNING id
    ''',
      params: {'uid': firebaseUid, 'mode': mode.name},
    );
    return result.isNotEmpty;
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
    } catch (_) {
      // Column may not exist if migration not run; ignore
    }
  }
}
