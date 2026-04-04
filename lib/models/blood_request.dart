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

  /// Distance from donor to hospital (km). Set when request is loaded for a donor.
  final double? distanceKm;

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
    this.distanceKm,
  });

  factory BloodRequest.fromJson(Map<String, dynamic> json) {
    String safeString(dynamic v) => v == null ? '' : v.toString();
    String shortIdStr = safeString(json['short_id']);
    return BloodRequest(
      id: safeString(json['id']),
      shortId: shortIdStr,
      displayCode: shortIdStr.contains('-') ? shortIdStr.split('-').last : shortIdStr,
      requesterId: safeString(json['requester_id']),
      bloodType: safeString(json['blood_type']),
      unitsNeeded: (json['units_needed'] is int) ? json['units_needed'] as int : int.tryParse(json['units_needed']?.toString() ?? '1') ?? 1,
      urgencyLevel: UrgencyLevel.values.byName((json['urgency_level'] ?? 'urgent').toString()),
      hospitalName: safeString(json['hospital_name']),
      hospitalLat: (json['hospital_lat'] as num?)?.toDouble() ?? 0.0,
      hospitalLng: (json['hospital_lng'] as num?)?.toDouble() ?? 0.0,
      requesterLat: (json['requester_lat'] as num?)?.toDouble(),
      requesterLng: (json['requester_lng'] as num?)?.toDouble(),
      status: RequestStatus.values.byName((json['status'] ?? 'active').toString()),
      nearbyDonorsCount: (json['nearby_donors_count'] as int?) ?? 0,
      totalEligibleCount: (json['total_eligible_count'] as int?) ?? 0,
      createdAt: json['created_at'] is DateTime
          ? json['created_at'] as DateTime
          : DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: json['expires_at'] is DateTime
          ? json['expires_at'] as DateTime
          : DateTime.tryParse(json['expires_at']?.toString() ?? '') ?? DateTime.now().add(const Duration(hours: 24)),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  /// MVP lifecycle: Open → Matching → Donor accepted → Verified/closed (maps DB statuses).
  String get mvpPrimaryStatusLabel {
    switch (status) {
      case RequestStatus.active:
        return 'Open';
      case RequestStatus.in_progress:
        return 'Donor accepted';
      case RequestStatus.fulfilled:
        return 'Verified / closed';
      case RequestStatus.cancelled:
        return 'Cancelled';
      case RequestStatus.expired:
        return 'Expired';
    }
  }

  /// Subtitle for the Open phase (matching donors).
  String? get mvpSecondaryStatusLabel {
    switch (status) {
      case RequestStatus.active:
        return 'Matching nearby donors';
      default:
        return null;
    }
  }
}