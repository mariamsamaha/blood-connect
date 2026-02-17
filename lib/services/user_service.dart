import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/database_service.dart';

class UserService {
  final DatabaseService _db;

  UserService(this._db);

  Future<UserProfile?> getProfileByFirebaseUid(String firebaseUid) async {
    try {
      final result = await _db.query('''
        SELECT *, 
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude
        FROM users 
        WHERE firebase_uid = @uid
      ''', params: {'uid': firebaseUid});

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
      final existing = await _db.query('''
        SELECT *, 
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude
        FROM users 
        WHERE firebase_uid = @uid
      ''', params: {'uid': firebaseUser.uid});
      
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
  }) async {
    try {
      // Check if profile already exists
      final existing = await _db.query('''
        SELECT *, 
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude
        FROM users 
        WHERE firebase_uid = @uid
      ''', params: {'uid': firebaseUser.uid});
      
      if (existing.isNotEmpty) return UserProfile.fromJson(existing.first);

      final Map<String, dynamic> params;
      final String sql;

      if (accountType == 'hospital') {
        sql = '''
          INSERT INTO users (
            firebase_uid, email, name, phone,
            account_type, hospital_name, hospital_code, 
            is_donor, is_recipient, donor_status, active_mode
          ) VALUES (
            @uid, @email, @name, @phone,
            'hospital', @hospitalName, @hospitalCode,
            FALSE, FALSE, 'unavailable', 'hospital_view'
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
        };
      } else {
        sql = '''
          INSERT INTO users (
            firebase_uid, email, name, phone, blood_type,
            account_type, is_donor, is_recipient, donor_status, active_mode
          ) VALUES (
            @uid, @email, @name, @phone, @bloodType,
            'regular', @canDonate, FALSE, @donorStatus, 'donor_view'
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
          'donorStatus': canDonate ? 'available' : 'unavailable',  // ✅ FIXED
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
}