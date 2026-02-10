// lib/services/user_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/database_service.dart';

class UserService {
  final DatabaseService _db;

  UserService(this._db);

  Future<UserProfile?> getProfileByFirebaseUid(String firebaseUid) async {
    try {
      final result = await _db.query(
        'SELECT * FROM users WHERE firebase_uid = @uid',
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
      // 1. Check if profile already exists
      final existing = await _db.query(
        'SELECT * FROM users WHERE firebase_uid = @uid',
        params: {'uid': firebaseUser.uid},
      );
      if (existing.isNotEmpty) return UserProfile.fromJson(existing.first);

      // 2. New user — check if email is a hospital domain
      final isHospital = await _db.query(
        "SELECT is_hospital_email(@email)",
        params: {'email': firebaseUser.email},
      );

      final accountType = (isHospital.first.values.first == true)
          ? 'hospital'
          : 'regular';

      // 3. Insert into PostgreSQL
      final row = await _db.query(
        '''
        INSERT INTO users (
          firebase_uid, email, name, account_type,
          is_donor, is_recipient, donor_status, active_mode
        ) VALUES (
          @uid, @email, @name, @accountType,
          FALSE, FALSE, 'unavailable',
          @defaultMode
        ) RETURNING *;
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
    required String location,
    required String bloodType,
    required bool canDonate,
    required bool needsBlood,
    required String accountType,
  }) async {
    try {
      // 1. Check if profile already exists
      final existing = await _db.query(
        'SELECT * FROM users WHERE firebase_uid = @uid',
        params: {'uid': firebaseUser.uid},
      );
      if (existing.isNotEmpty) return UserProfile.fromJson(existing.first);

      // 2. New user — check if email is a hospital domain
      final isHospital = await _db.query(
        "SELECT is_hospital_email(@email)",
        params: {'email': firebaseUser.email},
      );

      final accountType = (isHospital.first.values.first == true)
          ? 'hospital'
          : 'regular';

      // 3. Insert into PostgreSQL with complete profile
      final params = {
        'uid': firebaseUser.uid,
        'email': email,
        'name': name,
        'phone': phone,
        'location': location,
        'bloodType': bloodType,
        'accountType': accountType,
        'canDonate': canDonate,
        'needsBlood': needsBlood,
        'defaultMode': accountType == 'hospital'
            ? 'hospital_view'
            : needsBlood
            ? 'recipient_view'
            : 'donor_view',
      };

      final row = await _db.query('''
        INSERT INTO users (
          firebase_uid, email, name, phone, location, blood_type,
          account_type, is_donor, is_recipient, donor_status, active_mode
        ) VALUES (
          @uid, @email, @name, @phone, 
          CASE 
            WHEN @location IS NOT NULL AND @location != '' 
              THEN ST_MakePoint(
                COALESCE(NULLIF(@location::double, 0.0), 0.0), 
                COALESCE(NULLIF(@location::double, 0.0), 0.0))
            ELSE NULL
          END,
          @bloodType, @accountType, @canDonate, @needsBlood, 'available',
          @defaultMode
        ) RETURNING *;
        ''', params: params);

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
