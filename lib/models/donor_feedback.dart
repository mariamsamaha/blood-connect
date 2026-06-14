class DonorFeedback {
  final String id;
  final String donationId;
  final String donorId;
  final String feedbackType;
  final String targetId;
  final int? overallRating;
  final int? communicationRating;
  final int? organizationRating;
  final int? hospitalEfficiencyRating;
  final int? staffProfessionalismRating;
  final int? cleanlinessRating;
  final int? waitingTimeRating;
  final String? comment;
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime? donatedAt;
  final String? targetName;

  const DonorFeedback({
    required this.id,
    required this.donationId,
    required this.donorId,
    required this.feedbackType,
    required this.targetId,
    this.overallRating,
    this.communicationRating,
    this.organizationRating,
    this.hospitalEfficiencyRating,
    this.staffProfessionalismRating,
    this.cleanlinessRating,
    this.waitingTimeRating,
    this.comment,
    this.isAnonymous = false,
    required this.createdAt,
    this.donatedAt,
    this.targetName,
  });

  factory DonorFeedback.fromJson(Map<String, dynamic> json) {
    return DonorFeedback(
      id: json['id'] as String? ?? '',
      donationId: json['donation_id'] as String? ?? '',
      donorId: json['donor_id'] as String? ?? '',
      feedbackType: json['feedback_type'] as String? ?? '',
      targetId: json['target_id'] as String? ?? '',
      overallRating: json['overall_rating'] != null
          ? (json['overall_rating'] is int
              ? json['overall_rating'] as int
              : int.tryParse(json['overall_rating'].toString()))
          : null,
      communicationRating: json['communication_rating'] != null
          ? (json['communication_rating'] is int
              ? json['communication_rating'] as int
              : int.tryParse(json['communication_rating'].toString()))
          : null,
      organizationRating: json['organization_rating'] != null
          ? (json['organization_rating'] is int
              ? json['organization_rating'] as int
              : int.tryParse(json['organization_rating'].toString()))
          : null,
      hospitalEfficiencyRating: json['hospital_efficiency_rating'] != null
          ? (json['hospital_efficiency_rating'] is int
              ? json['hospital_efficiency_rating'] as int
              : int.tryParse(json['hospital_efficiency_rating'].toString()))
          : null,
      staffProfessionalismRating: json['staff_professionalism_rating'] != null
          ? (json['staff_professionalism_rating'] is int
              ? json['staff_professionalism_rating'] as int
              : int.tryParse(json['staff_professionalism_rating'].toString()))
          : null,
      cleanlinessRating: json['cleanliness_rating'] != null
          ? (json['cleanliness_rating'] is int
              ? json['cleanliness_rating'] as int
              : int.tryParse(json['cleanliness_rating'].toString()))
          : null,
      waitingTimeRating: json['waiting_time_rating'] != null
          ? (json['waiting_time_rating'] is int
              ? json['waiting_time_rating'] as int
              : int.tryParse(json['waiting_time_rating'].toString()))
          : null,
      comment: json['comment'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      createdAt: json['created_at'] is DateTime
          ? json['created_at'] as DateTime
          : DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      donatedAt: json['donated_at'] is DateTime
          ? json['donated_at'] as DateTime
          : DateTime.tryParse(json['donated_at']?.toString() ?? ''),
      targetName: json['target_name'] as String?,
    );
  }
}

class HospitalFeedbackAnalytics {
  final int totalFeedbacks;
  final double avgOverall;
  final double avgEfficiency;
  final double avgProfessionalism;
  final double avgCleanliness;
  final double avgWaitingTime;
  final int rating1Count;
  final int rating2Count;
  final int rating3Count;
  final int rating4Count;
  final int rating5Count;

  const HospitalFeedbackAnalytics({
    this.totalFeedbacks = 0,
    this.avgOverall = 0,
    this.avgEfficiency = 0,
    this.avgProfessionalism = 0,
    this.avgCleanliness = 0,
    this.avgWaitingTime = 0,
    this.rating1Count = 0,
    this.rating2Count = 0,
    this.rating3Count = 0,
    this.rating4Count = 0,
    this.rating5Count = 0,
  });

  factory HospitalFeedbackAnalytics.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }
    return HospitalFeedbackAnalytics(
      totalFeedbacks: toInt(json['total_feedbacks']),
      avgOverall: toDouble(json['avg_overall']),
      avgEfficiency: toDouble(json['avg_efficiency']),
      avgProfessionalism: toDouble(json['avg_professionalism']),
      avgCleanliness: toDouble(json['avg_cleanliness']),
      avgWaitingTime: toDouble(json['avg_waiting_time']),
      rating1Count: toInt(json['rating_1_count']),
      rating2Count: toInt(json['rating_2_count']),
      rating3Count: toInt(json['rating_3_count']),
      rating4Count: toInt(json['rating_4_count']),
      rating5Count: toInt(json['rating_5_count']),
    );
  }
}

class RecipientFeedbackAnalytics {
  final int totalFeedbacks;
  final double avgOverall;
  final double avgCommunication;
  final double avgOrganization;

  const RecipientFeedbackAnalytics({
    this.totalFeedbacks = 0,
    this.avgOverall = 0,
    this.avgCommunication = 0,
    this.avgOrganization = 0,
  });

  factory RecipientFeedbackAnalytics.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }
    return RecipientFeedbackAnalytics(
      totalFeedbacks: toInt(json['total_feedbacks']),
      avgOverall: toDouble(json['avg_overall']),
      avgCommunication: toDouble(json['avg_communication']),
      avgOrganization: toDouble(json['avg_organization']),
    );
  }
}
