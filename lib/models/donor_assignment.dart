enum ResponseType { accepted, declined, enRoute, arrived }

class DonorAssignment {
  final String id;             
  final String requestId;       
  final String donorId;         
  final ResponseType responseType;
  final double distanceKm;
  final DateTime respondedAt;

  const DonorAssignment({
    required this.id,
    required this.requestId,
    required this.donorId,
    required this.responseType,
    required this.distanceKm,
    required this.respondedAt,
  });

  factory DonorAssignment.fromJson(Map<String, dynamic> json) => DonorAssignment(
    id:           json['id'],
    requestId:    json['request_id'],
    donorId:      json['donor_id'],
    responseType: ResponseType.values.byName(json['response_type']),
    distanceKm:   json['distance_km'],
    respondedAt:  DateTime.parse(json['responded_at']),
  );
}