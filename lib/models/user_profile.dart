enum AccountType { regular, hospital }

enum DonorStatus { available, on_cooldown, unavailable }  

enum ActiveMode { donor_view, recipient_view, hospital_view }

class UserProfile {
  final String id;
  final String firebaseUid;
  final String email;
  final String name;
  final String phone;

  final String bloodType;
  final AccountType accountType;
  final bool isDonor;
  final bool isRecipient;
  final DonorStatus donorStatus;

  final ActiveMode activeMode;
  final double? latitude;
  final double? longitude;

  final String? hospitalName;
  final String? hospitalCode;
  final bool? hospitalVerified;

  final int totalDonations;
  final int rewardPoints;

  const UserProfile({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.name,
    required this.phone,
    required this.bloodType,
    required this.accountType,
    required this.isDonor,
    required this.isRecipient,
    required this.donorStatus,
    required this.activeMode,
    this.latitude,
    this.longitude,
    this.hospitalName,
    this.hospitalCode,
    this.hospitalVerified,
    this.totalDonations = 0,
    this.rewardPoints = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    firebaseUid: json['firebase_uid'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    phone: (json['phone'] ?? '') as String,
    bloodType: (json['blood_type'] ?? '') as String,
    accountType: AccountType.values.byName(json['account_type'] as String),
    isDonor: json['is_donor'] as bool,
    isRecipient: json['is_recipient'] as bool,
    donorStatus: DonorStatus.values.byName(json['donor_status'] as String),
    activeMode: json['active_mode'] == null
        ? ActiveMode.donor_view
        : ActiveMode.values.byName(json['active_mode'] as String),
    latitude: json['latitude'] as double?,
    longitude: json['longitude'] as double?,
    hospitalName: json['hospital_name'] as String?,
    hospitalCode: json['hospital_code'] as String?,
    hospitalVerified: json['hospital_verified'] as bool?,
    totalDonations: (json['total_donations'] ?? 0) as int,
    rewardPoints: (json['reward_points'] ?? 0) as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'firebase_uid': firebaseUid,
    'email': email,
    'name': name,
    'phone': phone,
    'blood_type': bloodType,
    'account_type': accountType.name,
    'is_donor': isDonor,
    'is_recipient': isRecipient,
    'donor_status': donorStatus.name,
    'active_mode': activeMode.name,
    'latitude': latitude,
    'longitude': longitude,
    'hospital_name': hospitalName,
    'hospital_code': hospitalCode,
    'hospital_verified': hospitalVerified,
    'total_donations': totalDonations,
    'reward_points': rewardPoints,
  };
}