import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/repositories/base_repository.dart';
import 'package:bloodconnect/services/user_service.dart';

class UserRepository extends BaseRepository {
  final UserService _userService;

  UserRepository({
    required super.apiClient,
    required UserService userService,
    super.cacheService,
    super.persistentCacheService,
    super.invalidationService,
  }) : _userService = userService;

  Future<UserProfile?> getProfile(String firebaseUid, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/users');
    }
    return cacheFirst<UserProfile?>(
      cacheKey: 'repo:/api/v1/users/me',
      fetch: () => _userService.getProfileByFirebaseUid(firebaseUid),
    );
  }

  Future<List<Map<String, dynamic>>> getBadges(String userId, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/users/me/badges');
    }
    return cacheFirst<List<Map<String, dynamic>>>(
      cacheKey: 'repo:/api/v1/users/me/badges?userId=$userId',
      fetch: () => _userService.getUserBadges(userId),
    );
  }

  Future<List<Map<String, dynamic>>> getBadgesWithProgress(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await invalidatePrefix('/api/v1/users/me/badges/progress');
    }
    return cacheFirst<List<Map<String, dynamic>>>(
      cacheKey: 'repo:/api/v1/users/me/badges/progress?userId=$userId',
      fetch: () => _userService.getAllBadgesWithProgress(userId),
    );
  }

  Future<UserProfile> createOrFetchProfile(User firebaseUser) {
    return _userService.createOrFetchProfile(firebaseUser);
  }

  Future<UserProfile> createCompleteProfile(
    User firebaseUser, {
    required String name,
    required String email,
    required String phone,
    required String bloodType,
    required String role,
    required String accountType,
    String? hospitalName,
    String? hospitalCode,
    double? latitude,
    double? longitude,
    String? cityArea,
  }) {
    return _userService.createCompleteProfile(
      firebaseUser,
      name: name,
      email: email,
      phone: phone,
      bloodType: bloodType,
      role: role,
      accountType: accountType,
      hospitalName: hospitalName,
      hospitalCode: hospitalCode,
      latitude: latitude,
      longitude: longitude,
      cityArea: cityArea,
    );
  }
}
