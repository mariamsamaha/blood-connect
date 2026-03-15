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

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'] as String,
      name: json['hospital_name'] as String,
      code: json['hospital_code'] as String? ?? '',
      email: json['email'] as String? ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      address: json['address'] as String?,
      distanceKm: _parseDoubleNullable(json['distance_km']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String get displayName {
    if (distanceKm != null) {
      return '$name ($code) - ${distanceKm!.toStringAsFixed(1)} km';
    }
    return '$name ($code)';
  }
}
