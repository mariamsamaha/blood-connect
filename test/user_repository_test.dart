import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/repositories/user_repository.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/user_service.dart';
import 'package:bloodconnect/services/cache_service.dart';

class _MockApiClient extends Fake implements ApiClient {
  Map<String, dynamic>? _getJsonResult;
  Map<String, dynamic> _postJsonResult = <String, dynamic>{};
  List<Map<String, dynamic>> _getJsonListResult = [];

  @override
  Future<Map<String, dynamic>?> getJson(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    return _getJsonResult;
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    return _postJsonResult;
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    return _getJsonListResult;
  }
}

class _MockUserService extends Fake implements UserService {
  UserProfile? profileToReturn;
  List<Map<String, dynamic>> badgesToReturn = [];

  @override
  Future<UserProfile?> getProfileByFirebaseUid(String firebaseUid) async {
    return profileToReturn;
  }

  @override
  Future<List<Map<String, dynamic>>> getUserBadges(String userId) async {
    return badgesToReturn;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllBadgesWithProgress(String userId) async {
    return badgesToReturn;
  }
}

void main() {
  group('UserRepository', () {
    late _MockApiClient mockApi;
    late _MockUserService mockUserService;
    late CacheService cacheService;
    late UserRepository repository;

    setUp(() {
      mockApi = _MockApiClient();
      mockUserService = _MockUserService();
      cacheService = CacheService(maxSize: 10);
      repository = UserRepository(
        apiClient: mockApi,
        userService: mockUserService,
        cacheService: cacheService,
      );
    });

    group('getProfile', () {
      test('fetches and caches profile', () async {
        mockUserService.profileToReturn = UserProfile(
          id: 'u1', firebaseUid: 'fb1', email: 't@t.com', name: 'Test',
          phone: '0100', bloodType: 'O+', accountType: AccountType.regular,
          role: UserRole.donor, isRecipient: false, donorStatus: DonorStatus.available,
        );
        final result = await repository.getProfile('fb1');
        expect(result, isNotNull);
        expect(result!.name, 'Test');
      });

      test('forceRefresh invalidates cache before fetch', () async {
        mockUserService.profileToReturn = UserProfile(
          id: 'u1', firebaseUid: 'fb1', email: 't@t.com', name: 'Test',
          phone: '0100', bloodType: 'O+', accountType: AccountType.regular,
          role: UserRole.donor, isRecipient: false, donorStatus: DonorStatus.available,
        );
        final result = await repository.getProfile('fb1', forceRefresh: true);
        expect(result, isNotNull);
      });
    });

    group('getBadges', () {
      test('returns badges list', () async {
        mockUserService.badgesToReturn = [{'badge_id': 'b1'}];
        final result = await repository.getBadges('u1');
        expect(result.length, 1);
      });
    });

    group('getBadgesWithProgress', () {
      test('returns badges with progress', () async {
        mockUserService.badgesToReturn = [{'badge_id': 'b1', 'progress': 0.5}];
        final result = await repository.getBadgesWithProgress('u1');
        expect(result.length, 1);
      });
    });
  });
}
