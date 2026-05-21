import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/user_service.dart';

class _FakeUser extends Fake implements User {}

class _MockApiClient extends Fake implements ApiClient {
  Map<String, dynamic>? _getJsonResult;
  Map<String, dynamic> _postJsonResult = <String, dynamic>{};
  List<Map<String, dynamic>> _getJsonListResult = [];
  bool? _patchCalled;
  String? _lastPath;

  Future<Map<String, dynamic>?> Function(String, {Map<String, String>? query, bool forceRefresh})? onGetJson;
  Future<Map<String, dynamic>> Function(String, {Object? body})? onPostJson;

  @override
  Future<Map<String, dynamic>?> getJson(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    if (onGetJson != null) return onGetJson!(path, query: query, forceRefresh: forceRefresh);
    if (path.contains('not_found')) throw Exception('not_found');
    if (path.contains('internal_error')) throw Exception('internal_error');
    if (path.contains('unexpected')) throw Exception('unexpected');
    return _getJsonResult;
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    if (onPostJson != null) return onPostJson!(path, body: body);
    return _postJsonResult;
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    if (path.contains('fail')) throw Exception('fail');
    return _getJsonListResult;
  }

  @override
  Future<void> patchJson(String path, {Object? body}) async {
    _patchCalled = true;
    _lastPath = path;
    if (path.contains('fail')) throw Exception('fail');
  }
}

void main() {
  group('UserService', () {
    late _MockApiClient mockApi;
    late UserService service;

    setUp(() {
      mockApi = _MockApiClient();
      service = UserService(mockApi);
    });

    group('getProfileByFirebaseUid', () {
      test('returns profile on success', () async {
        mockApi._getJsonResult = {
          'id': 'u1', 'firebase_uid': 'fb1', 'email': 't@t.com',
          'name': 'Test', 'phone': '0100', 'blood_type': 'O+',
          'account_type': 'regular', 'role': 'donor', 'is_recipient': false,
          'donor_status': 'available', 'total_donations': 0, 'reward_points': 0,
        };
        final result = await service.getProfileByFirebaseUid('fb1');
        expect(result, isNotNull);
        expect(result!.name, 'Test');
      });

      test('returns null when API returns null', () async {
        mockApi._getJsonResult = null;
        final result = await service.getProfileByFirebaseUid('fb1');
        expect(result, isNull);
      });

      test('returns null on not_found error', () async {
        mockApi.onGetJson = (_, {query, forceRefresh = false}) => throw Exception('not_found');
        final result = await service.getProfileByFirebaseUid('fb1');
        expect(result, isNull);
      });

      test('rethrows on internal_error', () async {
        mockApi.onGetJson = (_, {query, forceRefresh = false}) => throw Exception('internal_error');
        expect(
          () => service.getProfileByFirebaseUid('fb1'),
          throwsA(predicate((e) => e.toString().contains('Database error'))),
        );
      });

      test('rethrows on unexpected error', () async {
        mockApi.onGetJson = (_, {query, forceRefresh = false}) => throw Exception('unexpected');
        expect(
          () => service.getProfileByFirebaseUid('fb1'),
          throwsA(predicate((e) => e.toString().contains('Database error'))),
        );
      });
    });

    group('createOrFetchProfile', () {
      test('returns profile on success', () async {
        mockApi._postJsonResult = {
          'id': 'u1', 'firebase_uid': 'fb1', 'email': 't@t.com',
          'name': 'Test', 'phone': '0100', 'blood_type': 'O+',
          'account_type': 'regular', 'role': 'donor', 'is_recipient': false,
          'donor_status': 'available', 'total_donations': 0, 'reward_points': 0,
        };
        final result = await service.createOrFetchProfile(_FakeUser());
        expect(result.id, 'u1');
      });

      test('rethrows on database error', () async {
        mockApi.onPostJson = (_, {body}) => throw Exception('db_error');
        expect(
          () => service.createOrFetchProfile(_FakeUser()),
          throwsA(predicate((e) => e.toString().contains('Database error'))),
        );
      });
    });

    group('createCompleteProfile', () {
      test('returns profile on success', () async {
        mockApi._postJsonResult = {
          'id': 'u1', 'firebase_uid': 'fb1', 'email': 't@t.com',
          'name': 'Complete', 'phone': '0100', 'blood_type': 'A+',
          'account_type': 'regular', 'role': 'donor', 'is_recipient': false,
          'donor_status': 'available', 'total_donations': 0, 'reward_points': 0,
        };
        final result = await service.createCompleteProfile(
          _FakeUser(),
          name: 'Complete', email: 't@t.com', phone: '0100',
          bloodType: 'A+', role: 'donor', accountType: 'regular',
        );
        expect(result.name, 'Complete');
      });

      test('includes optional hospital fields when provided', () async {
        Map<String, dynamic>? sentBody;
        mockApi.onPostJson = (String path, {Object? body}) {
          sentBody = body as Map<String, dynamic>?;
          return Future.value({
            'id': 'u1', 'firebase_uid': 'fb1', 'email': 'h@h.com',
            'name': 'Hosp', 'phone': '', 'blood_type': '',
            'account_type': 'hospital', 'role': 'hospital', 'is_recipient': false,
            'donor_status': 'unavailable', 'total_donations': 0, 'reward_points': 0,
          });
        };
        await service.createCompleteProfile(
          _FakeUser(),
          name: 'Hosp', email: 'h@h.com', phone: '',
          bloodType: '', role: 'hospital', accountType: 'hospital',
          hospitalName: 'Test Hospital', hospitalCode: 'TH',
          latitude: 30.0, longitude: 31.0, cityArea: 'Cairo',
        );
        expect(sentBody!['hospitalName'], 'Test Hospital');
        expect(sentBody!['hospitalCode'], 'TH');
        expect(sentBody!['latitude'], 30.0);
        expect(sentBody!['cityArea'], 'Cairo');
      });
    });

    group('updateFcmToken', () {
      test('calls patch when token is non-empty', () async {
        await service.updateFcmToken('fb1', 'token123');
        expect(mockApi._patchCalled, isTrue);
      });

      test('does nothing when token is null', () async {
        await service.updateFcmToken('fb1', null);
        expect(mockApi._patchCalled, isNull);
      });

      test('does nothing when token is empty', () async {
        await service.updateFcmToken('fb1', '');
        expect(mockApi._patchCalled, isNull);
      });
    });

    group('getUserBadges', () {
      test('returns list on success', () async {
        mockApi._getJsonListResult = [{'badge_id': 'b1'}];
        final result = await service.getUserBadges('u1');
        expect(result.length, 1);
      });

      test('returns empty on error', () async {
        mockApi._getJsonListResult = [];
        final result = await service.getUserBadges('fail');
        expect(result, isEmpty);
      });
    });

    group('getAllBadgesWithProgress', () {
      test('returns list on success', () async {
        mockApi._getJsonListResult = [{'badge_id': 'b1', 'progress': 0.5}];
        final result = await service.getAllBadgesWithProgress('u1');
        expect(result.length, 1);
      });

      test('returns empty on error', () async {
        final result = await service.getAllBadgesWithProgress('fail');
        expect(result, isEmpty);
      });
    });

    group('updateProfile', () {
      test('calls patch with updates', () async {
        await service.updateProfile(firebaseUid: 'fb1', updates: {'name': 'New'});
        expect(mockApi._patchCalled, isTrue);
      });

      test('does nothing when updates are empty', () async {
        await service.updateProfile(firebaseUid: 'fb1', updates: {});
        expect(mockApi._patchCalled, isNull);
      });
    });

    group('updateLocation', () {
      test('calls patch on success', () async {
        await service.updateLocation(firebaseUid: 'fb1', latitude: 30.0, longitude: 31.0);
        expect(mockApi._patchCalled, isTrue);
      });

      test('does not throw on failure', () async {
        final failingService = UserService(_MockApiClient());
        await failingService.updateLocation(firebaseUid: 'fb1', latitude: 30.0, longitude: 31.0);
      });
    });
  });
}
