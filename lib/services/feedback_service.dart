import 'package:bloodconnect/models/donor_feedback.dart';
import 'package:bloodconnect/services/api_client.dart';

class FeedbackService {
  final ApiClient _api;

  FeedbackService(this._api);

  Future<Map<String, dynamic>> submitFeedback({
    required String donationId,
    required String donorId,
    required String feedbackType,
    required String targetId,
    int? overallRating,
    int? communicationRating,
    int? organizationRating,
    int? hospitalEfficiencyRating,
    int? staffProfessionalismRating,
    int? cleanlinessRating,
    int? waitingTimeRating,
    String? comment,
    bool isAnonymous = false,
  }) async {
    return await _api.postJson('/api/v1/feedback/submit', body: {
      'donationId': donationId,
      'donorId': donorId,
      'feedbackType': feedbackType,
      'targetId': targetId,
      'overallRating': overallRating,
      'communicationRating': communicationRating,
      'organizationRating': organizationRating,
      'hospitalEfficiencyRating': hospitalEfficiencyRating,
      'staffProfessionalismRating': staffProfessionalismRating,
      'cleanlinessRating': cleanlinessRating,
      'waitingTimeRating': waitingTimeRating,
      'comment': comment,
      'isAnonymous': isAnonymous,
    });
  }

  Future<Map<String, dynamic>> getHospitalFeedback(String hospitalId, {int limit = 50}) async {
    final result = await _api.getJson(
      '/api/v1/feedback/hospital/$hospitalId',
      query: {'limit': limit.toString()},
    );
    return result ?? {};
  }

  Future<Map<String, dynamic>> getRecipientFeedback(String recipientId, {int limit = 50}) async {
    final result = await _api.getJson(
      '/api/v1/feedback/recipient/$recipientId',
      query: {'limit': limit.toString()},
    );
    return result ?? {};
  }

  Future<List<DonorFeedback>> getMyFeedback(String donorId) async {
    try {
      final result = await _api.getJsonList(
        '/api/v1/feedback/mine',
        query: {'donorId': donorId},
      );
      return result.map((json) => DonorFeedback.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }
}
