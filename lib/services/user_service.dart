import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/database_service.dart';

class UserService {
  final DatabaseService _db;

  UserService(this._db);

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
        String locationSql = latitude != null && longitude != null
            ? "ST_SetSRID(ST_MakePoint(@longitude, @latitude), 4326)"
            : 'NULL';

        sql =
            '''
          INSERT INTO users (
            firebase_uid, email, name, phone,
            account_type, hospital_name, hospital_code, 
            is_donor, is_recipient, donor_status, active_mode, location
          ) VALUES (
            @uid, @email, @name, @phone,
            'hospital', @hospitalName, @hospitalCode,
            FALSE, FALSE, 'unavailable', 'hospital_view', $locationSql
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
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        };
      } else {
        final mode = activeMode == 'recipient_view'
            ? 'recipient_view'
            : 'donor_view';
        String locationSql = latitude != null && longitude != null
            ? "ST_SetSRID(ST_MakePoint(@longitude, @latitude), 4326)"
            : 'NULL';

        sql =
            '''
          INSERT INTO users (
            firebase_uid, email, name, phone, blood_type,
            account_type, is_donor, is_recipient, donor_status, active_mode, location
          ) VALUES (
            @uid, @email, @name, @phone, @bloodType,
            'regular', @canDonate, FALSE, @donorStatus, @activeMode, $locationSql
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

  Future<void> updateActiveMode(ActiveMode mode) async {
    // Update the active_mode in PostgreSQL
    throw UnimplementedError('Implement updateActiveMode');
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
