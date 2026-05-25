import 'package:bloodconnect/models/ai_eligibility_result.dart';
import 'package:bloodconnect/services/api_client.dart';

class AiEligibilityService {
  final ApiClient _api;
  AiEligibilityService(this._api);

  Future<AiEligibilityResult> check({
    required String donorId,
    required String bloodType,
    bool? feelingWell,
    bool? recentIllness,
  }) async {
    try {
      final data = await _api.postJson(
        '/api/v1/ai/eligibility',
        body: {
          'donorId': donorId,
          'bloodType': bloodType,
          if (feelingWell != null) 'feelingWell': feelingWell,
          if (recentIllness != null) 'recentIllness': recentIllness,
        },
      );
      return AiEligibilityResult.fromJson(data);
    } catch (_) {
      // AI service down — fail open so donors are never blocked by infrastructure
      return AiEligibilityResult.serviceError();
    }
  }
}
