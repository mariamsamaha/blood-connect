import 'package:bloodconnect/models/story.dart';
import 'package:bloodconnect/services/api_client.dart';

class StoryService {
  final ApiClient _api;
  StoryService(this._api);

  Future<List<Story>> getStories({
    int page = 0,
    int limit = 20,
    String? role,
  }) async {
    final rows = await _api.getJsonList(
      '/api/v1/stories',
      query: {
        'limit': limit.toString(),
        'offset': (page * limit).toString(),
        if (role != null) 'role': role,
      },
    );
    return rows.map(Story.fromJson).toList();
  }

  Future<void> submitStory({
    required String title,
    required String body,
    required String role,
    String? bloodType,
  }) async {
    await _api.postJson(
      '/api/v1/stories',
      body: {
        'title': title,
        'body': body,
        'role': role,
        if (bloodType != null) 'blood_type': bloodType,
      },
    );
  }

  Future<bool> toggleLike(String storyId) async {
    try {
      final data = await _api.postJson(
        '/api/v1/stories/$storyId/like',
        body: {},
      );
      return (data as Map<String, dynamic>?)?['liked'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }
}
