/// One record of a donor's response to a blood request (for profile history).
class DonorResponseEntry {
  final String requestId;
  final String displayCode;
  final String hospitalName;
  final String bloodType;
  final String responseType; // 'accepted', 'declined', etc.
  final DateTime respondedAt;

  const DonorResponseEntry({
    required this.requestId,
    required this.displayCode,
    required this.hospitalName,
    required this.bloodType,
    required this.responseType,
    required this.respondedAt,
  });

  factory DonorResponseEntry.fromJson(Map<String, dynamic> json) {
    return DonorResponseEntry(
      requestId: json['request_id'] as String,
      displayCode: (json['short_id'] as String).toString().split('-').last,
      hospitalName: json['hospital_name'] as String,
      bloodType: json['blood_type'] as String,
      responseType: json['response_type'] as String,
      respondedAt: json['responded_at'] is DateTime
          ? json['responded_at'] as DateTime
          : DateTime.parse(json['responded_at'] as String),
    );
  }
}
