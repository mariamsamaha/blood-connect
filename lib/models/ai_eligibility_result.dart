enum EligibilityStatus { eligible, uncertain, notEligible, error }

class AiEligibilityResult {
  final EligibilityStatus status;
  final double score; // 0.0 – 1.0
  final List<String> warnings;
  final List<String> tips;
  final String message;

  const AiEligibilityResult({
    required this.status,
    required this.score,
    required this.warnings,
    required this.tips,
    required this.message,
  });

  bool get canProceed =>
      status == EligibilityStatus.eligible ||
      status == EligibilityStatus.uncertain ||
      status == EligibilityStatus.error; // error = AI down, don't block donor

  factory AiEligibilityResult.fromJson(Map<String, dynamic> json) {
    final score = (json['score'] as num?)?.toDouble() ?? 0.5;
    final statusStr = json['status'] as String? ?? '';

    final EligibilityStatus status;
    if (statusStr == 'eligible' || score >= 0.75) {
      status = EligibilityStatus.eligible;
    } else if (statusStr == 'uncertain' || score >= 0.5) {
      status = EligibilityStatus.uncertain;
    } else {
      status = EligibilityStatus.notEligible;
    }

    return AiEligibilityResult(
      status: status,
      score: score.clamp(0.0, 1.0),
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tips: (json['tips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      message: json['message'] as String? ?? '',
    );
  }

  factory AiEligibilityResult.serviceError() => const AiEligibilityResult(
        status: EligibilityStatus.error,
        score: 0.5,
        warnings: [],
        tips: ['Drink water before donating.', 'Eat a light meal beforehand.'],
        message: 'AI check unavailable — proceeding with standard guidelines.',
      );
}
