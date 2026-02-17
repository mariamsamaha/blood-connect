enum UrgencyLevel { routine, urgent, critical }
enum RequestStatus { active, in_progress, fulfilled, cancelled, expired }

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
  
  //  Requester's fresh location at request time
  final double? requesterLat;
  final double? requesterLng;

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
    this.requesterLat,      
    this.requesterLng,      
    required this.status,
    required this.nearbyDonorsCount,
    required this.totalEligibleCount,
    required this.createdAt,
    required this.expiresAt,
  });

  factory BloodRequest.fromJson(Map<String, dynamic> json) => BloodRequest(
    id: json['id'] as String,
    shortId: json['short_id'] as String,
    displayCode: (json['short_id'] as String).split('-').last,
    requesterId: json['requester_id'] as String,
    bloodType: json['blood_type'] as String,
    unitsNeeded: json['units_needed'] as int,
    urgencyLevel: UrgencyLevel.values.byName(json['urgency_level'] as String),
    hospitalName: json['hospital_name'] as String,
    hospitalLat: json['hospital_lat'] as double,
    hospitalLng: json['hospital_lng'] as double,
    requesterLat: json['requester_lat'] as double?,    // ✅ NEW
    requesterLng: json['requester_lng'] as double?,    // ✅ NEW
    status: RequestStatus.values.byName(json['status'] as String),
    nearbyDonorsCount: json['nearby_donors_count'] as int? ?? 0,
    totalEligibleCount: json['total_eligible_count'] as int? ?? 0,
    createdAt: json['created_at'] is DateTime 
        ? json['created_at'] as DateTime 
        : DateTime.parse(json['created_at'] as String),
    expiresAt: json['expires_at'] is DateTime 
        ? json['expires_at'] as DateTime 
        : DateTime.parse(json['expires_at'] as String),
  );
}