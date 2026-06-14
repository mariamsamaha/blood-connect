import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final ApiClient _api;

  UserService(this._api);

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
      final row = await _api.getJson('/api/v1/users/me');
      if (row == null) return null;
      return UserProfile.fromJson(row);
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('not_found')) return null;
      if (msg.contains('internal_error')) {
        debugPrint(
          'API database error — ensure api-backend is running and Supabase '
          'credentials are set in api-backend/.env. Check http://127.0.0.1:8090/health/db',
        );
      }
      throw Exception('Database error while fetching user profile: $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching user profile: $e');
    }
  }

  Future<UserProfile> createOrFetchProfile(User firebaseUser) async {
    try {
      final row = await _api.postJson('/api/v1/users/me/bootstrap');
      return UserProfile.fromJson(row);
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
    required String role,
    required String accountType,
    String? dateOfBirth,
    String? hospitalName,
    String? hospitalCode,
    double? latitude,
    double? longitude,
    String? cityArea,
  }) async {
    try {
      final row = await _api.postJson(
        '/api/v1/users/me/complete',
        body: {
          'name': name,
          'email': email,
          'phone': phone,
          'bloodType': bloodType,
          'role': role,
          'accountType': accountType,
          if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
          if (hospitalName != null) 'hospitalName': hospitalName,
          if (hospitalCode != null) 'hospitalCode': hospitalCode,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (cityArea != null) 'cityArea': cityArea,
        },
      );
      return UserProfile.fromJson(row);
    } on Exception catch (e) {
      throw Exception('Database error while creating user profile: $e');
    } catch (e) {
      throw Exception('Unexpected error while creating user profile: $e');
    }
  }

  Future<void> updateFcmToken(String firebaseUid, String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await _api.patchJson(
        '/api/v1/users/me/fcm-token',
        body: {'token': token},
      );
      debugPrint('FCM token saved for $firebaseUid');
    } catch (e) {
      debugPrint('FCM token save FAILED for $firebaseUid: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserBadges(String userId) async {
    try {
      return await _api.getJsonList(
        '/api/v1/users/me/badges',
        query: {'userId': userId},
      );
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllBadgesWithProgress(String userId) async {
    try {
      return await _api.getJsonList(
        '/api/v1/users/me/badges/progress',
        query: {'userId': userId},
      );
    } catch (e) {
      return [];
    }
  }

  Future<void> updateProfile({
    required String firebaseUid,
    required Map<String, dynamic> updates,
  }) async {
    if (updates.isEmpty) return;
    await _api.patchJson(
      '/api/v1/users/me',
      body: {'updates': updates},
    );
  }

  Future<void> updateLocation({
    required String firebaseUid,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _api.patchJson(
        '/api/v1/users/me/location',
        body: {'latitude': latitude, 'longitude': longitude},
      );
    } catch (e) {
      debugPrint('updateLocation failed: $e');
    }
  }
}
