class Hospital {
  final String id;
  final String name;
  final String code;
  final String email;
  final double latitude;
  final double longitude;
  final String? address;
  final double? distanceKm;

  const Hospital({
    required this.id,
    required this.name,
    required this.code,
    required this.email,
    required this.latitude,
    required this.longitude,
    this.address,
    this.distanceKm,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) => Hospital(
        id: json['id'] as String,
        name: json['hospital_name'] as String,
        code: json['hospital_code'] as String,
        email: json['email'] as String,
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
        address: json['address'] as String?,
        distanceKm: json['distance_km'] as double?,
      );

  String get displayName {
    if (distanceKm != null) {
      return '$name ($code) - ${distanceKm!.toStringAsFixed(1)} km';
    }
    return '$name ($code)';
  }
}