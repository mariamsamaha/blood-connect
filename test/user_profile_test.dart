import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/models/user_profile.dart';

void main() {
  group('UserProfile.fromJson', () {
    test('parses regular donor user with minimal fields', () {
      final json = {
        'id': 'user-1',
        'firebase_uid': 'firebase_uid_1',
        'email': 'donor@example.com',
        'name': 'Regular Donor',
        'phone': '0123456789',
        'blood_type': 'O+',
        'account_type': 'regular',
        'is_donor': true,
        'is_recipient': false,
        'donor_status': 'available',
        'active_mode': 'donor_view',
        'total_donations': 3,
        'reward_points': 50,
        
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-1');
      expect(profile.firebaseUid, 'firebase_uid_1');
      expect(profile.email, 'donor@example.com');
      expect(profile.name, 'Regular Donor');
      expect(profile.phone, '0123456789');
      expect(profile.bloodType, 'O+');
      expect(profile.accountType, AccountType.regular);
      expect(profile.isDonor, isTrue);
      expect(profile.isRecipient, isFalse);
      expect(profile.donorStatus, DonorStatus.available);
      expect(profile.activeMode, ActiveMode.donor_view);
      expect(profile.latitude, isNull);
      expect(profile.longitude, isNull);
      expect(profile.hospitalName, isNull);
      expect(profile.hospitalCode, isNull);
      expect(profile.hospitalVerified, isNull);
      expect(profile.totalDonations, 3);
      expect(profile.rewardPoints, 50);
    });

    test('parses hospital user with null optional fields', () {
      final json = {
        'id': 'hospital-1',
        'firebase_uid': 'firebase_hospital_uid',
        'email': 'admin@zewailcity.edu.eg',
        'name': 'Zewail City University Hospital',
        'phone': null,
        'blood_type': null,
        'account_type': 'hospital',
        'is_donor': false,
        'is_recipient': false,
        'donor_status': 'unavailable',
        'active_mode': 'hospital_view',
        'hospital_name': 'Zewail City University Hospital',
        'hospital_code': 'ZC',
        'hospital_verified': true,
        'total_donations': null,
        'reward_points': null,
        // location columns (latitude/longitude) omitted intentionally
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.accountType, AccountType.hospital);
      expect(profile.hospitalName, 'Zewail City University Hospital');
      expect(profile.hospitalCode, 'ZC');
      expect(profile.hospitalVerified, isTrue);
      expect(profile.phone, '');
      expect(profile.bloodType, '');
      expect(profile.totalDonations, 0);
      expect(profile.rewardPoints, 0);
    });

    test('toJson and fromJson are consistent for regular user', () {
      final original = UserProfile(
        id: 'user-2',
        firebaseUid: 'firebase_uid_2',
        email: 'test@example.com',
        name: 'Test User',
        phone: '0100000000',
        bloodType: 'A-',
        accountType: AccountType.regular,
        isDonor: true,
        isRecipient: false,
        donorStatus: DonorStatus.available,
        activeMode: ActiveMode.donor_view,
        totalDonations: 1,
        rewardPoints: 10,
      );

      final json = original.toJson();
      final roundTripped = UserProfile.fromJson(json);

      expect(roundTripped.id, original.id);
      expect(roundTripped.firebaseUid, original.firebaseUid);
      expect(roundTripped.email, original.email);
      expect(roundTripped.name, original.name);
      expect(roundTripped.phone, original.phone);
      expect(roundTripped.bloodType, original.bloodType);
      expect(roundTripped.accountType, original.accountType);
      expect(roundTripped.isDonor, original.isDonor);
      expect(roundTripped.isRecipient, original.isRecipient);
      expect(roundTripped.donorStatus, original.donorStatus);
      expect(roundTripped.activeMode, original.activeMode);
      expect(roundTripped.totalDonations, original.totalDonations);
      expect(roundTripped.rewardPoints, original.rewardPoints);
    });
  });
}

