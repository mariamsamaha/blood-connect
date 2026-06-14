enum AccountType { regular, hospital }

enum DonorStatus { available, on_cooldown, unavailable }

enum UserRole { donor, recipient, hospital }

class UserProfile {
  final String id;
  final String firebaseUid;
  final String email;
  final String name;
  final String phone;

  final String bloodType;
  final AccountType accountType;

  /// Permanent role - set at signup, never changes
  final UserRole role;

  /// Operational state - TRUE when user has a live blood request
  final bool isRecipient;
  final DonorStatus donorStatus;

  final double? latitude;
  final double? longitude;

  final String? hospitalName;
  final String? hospitalCode;
  final bool? hospitalVerified;

  final int totalDonations;
  final int rewardPoints;

  /// City / area (MVP profile; optional text).
  final String cityArea;

  /// Donor notification radius from DB (km).
  final int notificationRadiusKm;

  /// Push notifications enabled.
  final bool notificationEnabled;

  /// Date of birth for age verification (must be 18+).
  final DateTime? dateOfBirth;

  const UserProfile({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.name,
    required this.phone,
    required this.bloodType,
    required this.accountType,
    required this.role,
    required this.isRecipient,
    required this.donorStatus,
    this.notificationEnabled = true,
    this.dateOfBirth,
    this.latitude,
    this.longitude,
    this.hospitalName,
    this.hospitalCode,
    this.hospitalVerified,
    this.totalDonations = 0,
    this.rewardPoints = 0,
    this.cityArea = '',
    this.notificationRadiusKm = 50,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final n = _parseInt(json['notification_radius_km']);

    // Parse role - new field, fallback to account_type
    UserRole parsedRole;
    if (json['role'] != null) {
      parsedRole = UserRole.values.byName(json['role'] as String);
    } else {
      // Fallback: derive role from account_type
      if (json['account_type'] == 'hospital') {
        parsedRole = UserRole.hospital;
      } else if (json['is_recipient'] == true) {
        parsedRole = UserRole.recipient;
      } else {
        parsedRole = UserRole.donor;
      }
    }

    return UserProfile(
      id: json['id'] as String,
      firebaseUid: json['firebase_uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: (json['phone'] ?? '') as String,
      bloodType: (json['blood_type'] ?? '') as String,
      accountType: AccountType.values.byName(
        json['account_type'] as String? ?? 'regular',
      ),
      role: parsedRole,
      isRecipient: json['is_recipient'] as bool? ?? false,
      donorStatus: DonorStatus.values.byName(
        json['donor_status'] as String? ?? 'available',
      ),
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      hospitalName: json['hospital_name'] as String?,
      hospitalCode: json['hospital_code'] as String?,
      hospitalVerified: json['hospital_verified'] as bool?,
      totalDonations: _parseInt(json['total_donations']),
      rewardPoints: _parseInt(json['reward_points']),
      cityArea: (json['city_area'] ?? '') as String,
      notificationRadiusKm: n <= 0 ? 50 : n.clamp(10, 400),
      notificationEnabled: json['notification_enabled'] as bool? ?? true,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'] as String)
          : null,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firebase_uid': firebaseUid,
    'email': email,
    'name': name,
    'phone': phone,
    'blood_type': bloodType,
    'account_type': accountType.name,
    'role': role.name,
    'is_recipient': isRecipient,
    'donor_status': donorStatus.name,
    'latitude': latitude,
    'longitude': longitude,
    'hospital_name': hospitalName,
    'hospital_code': hospitalCode,
    'hospital_verified': hospitalVerified,
    'total_donations': totalDonations,
    'reward_points': rewardPoints,
    'city_area': cityArea,
    'notification_radius_km': notificationRadiusKm,
    'notification_enabled': notificationEnabled,
    if (dateOfBirth != null) 'date_of_birth': dateOfBirth!.toIso8601String().split('T')[0],
  };

  String get homeRoute {
    switch (role) {
      case UserRole.hospital:
        return '/hospital/dashboard';
      case UserRole.recipient:
        return '/recipient/home';
      case UserRole.donor:
        return '/donor/home';
    }
  }
}
