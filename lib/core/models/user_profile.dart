
enum AccountType { regular, hospital }
enum DonorStatus  { available, onCooldown, unavailable }
enum ActiveMode   { donorView, recipientView, hospitalView }

class UserProfile {
  final String id;              
  final String firebaseUid;     
  final String email;
  final String name;
  final String phone;

  final String bloodType;       
  final AccountType accountType;
  final bool isDonor;           // can this user donate? 
  final bool isRecipient;       // does this user have an active request?
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
    id:               json['id'],
    firebaseUid:      json['firebase_uid'],
    email:            json['email'],
    name:             json['name'],
    phone:            json['phone'],
    bloodType:        json['blood_type'],
    accountType:      AccountType.values.byName(json['account_type']),
    isDonor:          json['is_donor'],
    isRecipient:      json['is_recipient'],
    donorStatus:      DonorStatus.values.byName(json['donor_status']),
    activeMode:       ActiveMode.values.byName(json['active_mode']),
    latitude:         json['latitude'],
    longitude:        json['longitude'],
    hospitalName:     json['hospital_name'],
    hospitalCode:     json['hospital_code'],
    hospitalVerified: json['hospital_verified'],
    totalDonations:   json['total_donations'] ?? 0,
    rewardPoints:     json['reward_points'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id':                id,
    'firebase_uid':      firebaseUid,
    'email':             email,
    'name':              name,
    'phone':             phone,
    'blood_type':        bloodType,
    'account_type':      accountType.name,
    'is_donor':          isDonor,
    'is_recipient':      isRecipient,
    'donor_status':      donorStatus.name,
    'active_mode':       activeMode.name,
    'latitude':          latitude,
    'longitude':         longitude,
    'hospital_name':     hospitalName,
    'hospital_code':     hospitalCode,
    'hospital_verified': hospitalVerified,
    'total_donations':   totalDonations,
    'reward_points':     rewardPoints,
  };
}