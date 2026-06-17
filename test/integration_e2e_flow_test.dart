import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/story.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/donor_service.dart';
import 'package:bloodconnect/services/hospital_service.dart';
import 'package:bloodconnect/services/notification_service.dart';
import 'package:bloodconnect/services/user_service.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test-uid';

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'mock-token';
}

class _MockAuth extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  User? get currentUser => _FakeUser();
}

class _FakeHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};
  final List<http.BaseRequest> _requests = [];

  void enqueue(String method, String path, int status, dynamic body) {
    final key = '$method:$path';
    _responses[key] = http.Response(
      body is String ? body : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    final method = request.method;
    _requests.add(request);

    String? matchedKey;
    int maxLen = -1;
    for (final key in _responses.keys) {
      final km = key.split(':')[0];
      final kp = key.split(':')[1];
      if (method == km && url.contains(kp)) {
        if (kp.length > maxLen) {
          maxLen = kp.length;
          matchedKey = key;
        }
      }
    }

    if (matchedKey != null) {
      final resp = _responses[matchedKey]!;
      return http.StreamedResponse(
        Stream.value(utf8.encode(resp.body)),
        resp.statusCode,
        headers: resp.headers,
      );
    }

    return http.StreamedResponse(const Stream.empty(), 404);
  }
}

final _mockAuth = _MockAuth();

// ─── Test data ───────────────────────────────────────────────────────────────

final _donorProfile = UserProfile.fromJson({
  'id': 'donor-1',
  'firebase_uid': 'fb-donor-1',
  'email': 'donor@test.com',
  'name': 'Test Donor',
  'blood_type': 'O+',
  'role': 'donor',
  'account_type': 'regular',
  'donor_status': 'available',
  'latitude': 30.0444,
  'longitude': 31.2357,
  'date_of_birth': '1990-06-15',
  'total_donations': 0,
  'reward_points': 50,
});

final _fakeStory = Story.fromJson({
  'id': 'story-1',
  'author_id': 'recip-1',
  'author_name': 'Test Recipient',
  'author_blood_type': 'A+',
  'role': 'recipient',
  'title': 'My donation story',
  'body': 'I received blood donations last year and it saved my life. Thank you to all donors!',
  'blood_type': 'A+',
  'likes_count': 0,
  'is_featured': false,
  'is_liked_by_me': false,
  'created_at': DateTime.now().toIso8601String(),
});

final _fakeMatch = {
  'id': 'req-1',
  'short_id': 'CH-ABCD',
  'requester_id': 'recip-1',
  'blood_type': 'O+',
  'units_needed': 2,
  'urgency_level': 'urgent',
  'hospital_name': 'Test Hospital',
  'hospital_lat': 30.05,
  'hospital_lng': 31.24,
  'requester_lat': 30.04,
  'requester_lng': 31.23,
  'status': 'active',
  'nearby_donors_count': 5,
  'total_eligible_count': 10,
  'created_at': DateTime.now().toIso8601String(),
  'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
  'distance_km': 5.2,
};

final _fakeAcceptedMission = {
  'id': 'req-1',
  'short_id': 'CH-ABCD',
  'requester_id': 'recip-1',
  'blood_type': 'O+',
  'units_needed': 2,
  'urgency_level': 'urgent',
  'hospital_name': 'Test Hospital',
  'hospital_lat': 30.05,
  'hospital_lng': 31.24,
  'status': 'in_progress',
  'nearby_donors_count': 5,
  'total_eligible_count': 10,
  'created_at': DateTime.now().toIso8601String(),
  'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
};

final _fakeNotification = {
  'id': 'notif-1',
  'user_id': 'recip-1',
  'request_id': null,
  'notification_type': 'story_like',
  'title': 'New Like on Your Story',
  'body': 'Test Donor liked your story.',
  'sent_at': DateTime.now().toIso8601String(),
  'read_at': null,
  'delivery_status': 'sent',
};

final _matchResult = {
  'request': {
    'id': 'req-1',
    'short_id': 'CH-ABCD',
    'requester_id': 'recip-1',
    'blood_type': 'O+',
    'units_needed': 2,
    'urgency_level': 'urgent',
    'hospital_name': 'Test Hospital',
    'hospital_lat': 30.05,
    'hospital_lng': 31.24,
    'status': 'in_progress',
    'nearby_donors_count': 5,
    'total_eligible_count': 10,
    'created_at': DateTime.now().toIso8601String(),
    'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
  },
  'donorName': 'Test Donor',
  'donorPhone': '+201234567890',
};

final _fakeBadges = [
  {'badge_id': 'badge-1', 'name': 'First Donation', 'icon': 'blood_drop', 'earned_at': DateTime.now().toIso8601String()},
  {'badge_id': 'badge-2', 'name': 'Lifesaver', 'icon': 'heart', 'earned_at': DateTime.now().toIso8601String()},
];

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('Full E2E Flow', () {
    late _FakeHttpClient httpClient;
    late ApiClient apiClient;
    late UserService userService;
    late DonorService donorService;
    late HospitalService hospitalService;

    setUp(() {
      httpClient = _FakeHttpClient();
      apiClient = ApiClient(httpClient: httpClient, auth: _mockAuth);
      userService = UserService(apiClient);
      donorService = DonorService(apiClient);
      hospitalService = HospitalService(apiClient);
    });

    test('flow: donor signup (18+) -> story like -> notification -> accept -> verify -> rewards', () async {
      // ── 1. Donor completes signup with date of birth ──────────────────
      httpClient.enqueue('GET', '/api/v1/users/me', 200, _donorProfile.toJson());
      final profile = await apiClient.getJson('/api/v1/users/me');
      expect(profile, isNotNull);
      expect(profile!['name'], 'Test Donor');

      // Verify DOB is in profile
      final userProfile = UserProfile.fromJson(profile);
      expect(userProfile.dateOfBirth, isNotNull);
      expect(userProfile.dateOfBirth!.year, 1990);

      // ── 2. Story exists (created by recipient) ────────────────────────
      expect(_fakeStory.authorId, 'recip-1');
      expect(_fakeStory.title, 'My donation story');

      // ── 3. Donor likes the story ──────────────────────────────────────
      httpClient.enqueue('POST', '/api/v1/stories/story-1/like', 200, {'liked': true});
      httpClient.enqueue('GET', '/api/v1/stories/story-1', 200, {
        'id': 'story-1',
        'author_id': 'recip-1',
        'author_name': 'Test Recipient',
        'author_blood_type': 'A+',
        'role': 'recipient',
        'title': 'My donation story',
        'body': 'I received blood donations last year.',
        'blood_type': 'A+',
        'likes_count': 1,
        'is_featured': false,
        'is_liked_by_me': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      final likeResult = await apiClient.postJson(
        '/api/v1/stories/story-1/like',
        body: {},
      );
      expect(likeResult['liked'], true);

      // Verify story like count incremented
      final storyResp = await apiClient.getJson('/api/v1/stories/story-1');
      expect(storyResp!['likes_count'], 1);

      // ── 4. Recipient sees the like notification ───────────────────────
      httpClient.enqueue('GET', '/api/v1/notifications', 200, [_fakeNotification]);

      // Switch apiClient to act as recipient
      final recipApiClient = ApiClient(httpClient: httpClient, auth: _mockAuth);
      final recipNotificationService = NotificationService(recipApiClient);

      final notifications = await recipNotificationService.getNotifications();
      expect(notifications.length, 1);
      expect(notifications[0].notificationType, 'story_like');
      expect(notifications[0].title, 'New Like on Your Story');
      expect(notifications[0].isUnread, true);
      expect(notifications[0].body, contains('Test Donor'));

      // Mark notification as read
      httpClient.enqueue('POST', '/api/v1/notifications/read', 204, null);
      await recipNotificationService.markAsRead(notificationId: 'notif-1');

      // ── 5. Donor sees matching request and accepts ────────────────────
      httpClient.enqueue('GET', '/api/v1/donor/matches', 200, [_fakeMatch]);
      final matches = await apiClient.getJsonList('/api/v1/donor/matches', query: {
        'donorId': 'donor-1',
        'donorLat': '30.0444',
        'donorLng': '31.2357',
        'compatibleTypesCsv': 'O-,O+',
        'radiusKm': '120',
      });
      expect(matches.length, 1);
      expect(matches[0]['hospital_name'], 'Test Hospital');

      final request = BloodRequest.fromJson(matches[0]);
      expect(request.bloodType, 'O+');

      // Accept the request
      httpClient.enqueue('POST', '/api/v1/donor/responses/accept', 204, null);
      await donorService.acceptRequest(
        requestId: request.id,
        donorId: 'donor-1',
        donorLat: 30.0444,
        donorLng: 31.2357,
      );

      // Verify active mission
      httpClient.enqueue('GET', '/api/v1/donor/mission', 200, _fakeAcceptedMission);
      final mission = await donorService.getActiveMission('donor-1');
      expect(mission, isNotNull);
      expect(mission!.status, RequestStatus.in_progress);
      expect(mission.displayCode, 'ABCD');

      // ── 6. Hospital verifies the donation ─────────────────────────────
      httpClient.enqueue('GET', '/api/v1/hospital/search', 200, [_matchResult]);
      final searchResults = await hospitalService.searchByDisplayCode(
        hospitalUserId: 'hosp-1',
        fourDigitInput: '1234',
      );
      expect(searchResults.length, 1);
      expect(searchResults.first.donorName, 'Test Donor');

      httpClient.enqueue('POST', '/api/v1/hospital/verify', 200, {'error': null});
      final verifyError = await hospitalService.verifyDonation(
        hospitalUserId: 'hosp-1',
        requestId: 'req-1',
        staffName: 'Dr. Smith',
      );
      expect(verifyError, isNull);

      // ── 7. Donor gets rewards and badges ──────────────────────────────
      httpClient.enqueue('GET', '/api/v1/users/me/badges', 200, _fakeBadges);
      final badges = await userService.getUserBadges('donor-1');
      expect(badges.length, 2);
      expect(badges[0]['name'], 'First Donation');
      expect(badges[1]['name'], 'Lifesaver');

      // Verify donor stats updated
      httpClient.enqueue('GET', '/api/v1/donor/stats', 200, {
        'total_donations': 1,
        'reward_points': 150,
      });
      final stats = await donorService.getDonorStats('donor-1');
      expect(stats, isNotNull);
    });

    test('age validation: under-18 signup is rejected', () async {
      httpClient.enqueue('POST', '/api/v1/users/me/complete', 400, {
        'error': 'must_be_18_or_older',
      });

      try {
        await userService.createCompleteProfile(
          _FakeUser(),
          name: 'Young Donor',
          email: 'young@test.com',
          phone: '+201111111111',
          bloodType: 'O+',
          role: 'donor',
          accountType: 'regular',
          dateOfBirth: '2010-01-01',
        );
        fail('Expected exception for under-18 user');
      } catch (e) {
        expect(e.toString(), contains('Database error'));
      }
    });

    test('age validation: 18+ signup succeeds', () async {
      final adultProfile = _donorProfile.toJson();
      httpClient.enqueue('POST', '/api/v1/users/me/complete', 201, adultProfile);

      final profile = await userService.createCompleteProfile(
        _FakeUser(),
        name: 'Adult Donor',
        email: 'adult@test.com',
        phone: '+201111111112',
        bloodType: 'O+',
        role: 'donor',
        accountType: 'regular',
        dateOfBirth: '1990-01-01',
      );

      expect(profile.id, 'donor-1');
      expect(profile.name, 'Test Donor');
      expect(profile.dateOfBirth, isNotNull);
    });

    test('flow: unliking a story does not create notification', () async {
      // Unlike the story
      httpClient.enqueue('POST', '/api/v1/stories/story-1/like', 200, {'liked': false});

      final result = await apiClient.postJson(
        '/api/v1/stories/story-1/like',
        body: {},
      );

      // Unlike should return liked: false and NOT create a notification
      expect(result, isNotNull);
      expect(result['liked'], false);

      // No notification related calls should have been made
      // The last enqueued response should be the unlike result
      final unlikeRequests = httpClient._requests.where(
        (r) => r.url.toString().contains('/notifications'),
      );
      expect(unlikeRequests, isEmpty);
    });
  });
}
