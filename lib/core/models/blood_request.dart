enum UrgencyLevel  { routine, urgent, critical }
enum RequestStatus { open, matching, accepted, verified, cancelled }

class BloodRequest {
  final String id;              
  final String shortId;         
  final String displayCode;     

  final String requesterId;     
  final String bloodType;
  final int unitsNeeded;
  final UrgencyLevel urgencyLevel;

  final String hospitalName;
  final double hospitalLat;
  final double hospitalLng;

  final RequestStatus status;
  final int nearbyDonorsCount;  
  final int totalEligibleCount;

  final DateTime createdAt;
  final DateTime expiresAt;     

  const BloodRequest({
    required this.id,
    required this.shortId,
    required this.displayCode,
    required this.requesterId,
    required this.bloodType,
    required this.unitsNeeded,
    required this.urgencyLevel,
    required this.hospitalName,
    required this.hospitalLat,
    required this.hospitalLng,
    required this.status,
    required this.nearbyDonorsCount,
    required this.totalEligibleCount,
    required this.createdAt,
    required this.expiresAt,
  });

  factory BloodRequest.fromJson(Map<String, dynamic> json) => BloodRequest(
    id:                  json['id'],
    shortId:             json['short_id'],
    displayCode:         json['short_id'].split('-').last,  
    requesterId:         json['requester_id'],
    bloodType:           json['blood_type'],
    unitsNeeded:         json['units_needed'],
    urgencyLevel:        UrgencyLevel.values.byName(json['urgency_level']),
    hospitalName:        json['hospital_name'],
    hospitalLat:         json['hospital_lat'],
    hospitalLng:         json['hospital_lng'],
    status:              RequestStatus.values.byName(json['status']),
    nearbyDonorsCount:   json['nearby_donors_count'] ?? 0,
    totalEligibleCount:  json['total_eligible_count'] ?? 0,
    createdAt:           DateTime.parse(json['created_at']),
    expiresAt:           DateTime.parse(json['expires_at']),
  );
}