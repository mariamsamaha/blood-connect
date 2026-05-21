import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/routing/app_router.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/auth_service.dart';
import 'package:bloodconnect/services/user_service.dart';

void main() {
  group('clearProfileCache', () {
    test('clears without error', () {
      clearProfileCache();
    });
  });

  group('homeRouteForProfile', () {
    test('returns donor home for donor role', () {
      final profile = UserProfile(
        id: 'u1', firebaseUid: 'fb1', email: 'd@d.com', name: 'Donor',
        phone: '', bloodType: 'O+', accountType: AccountType.regular,
        role: UserRole.donor, isRecipient: false, donorStatus: DonorStatus.available,
      );
      expect(homeRouteForProfile(profile), '/donor/home');
    });

    test('returns recipient home for recipient role', () {
      final profile = UserProfile(
        id: 'u1', firebaseUid: 'fb1', email: 'r@r.com', name: 'Rec',
        phone: '', bloodType: 'A+', accountType: AccountType.regular,
        role: UserRole.recipient, isRecipient: true, donorStatus: DonorStatus.unavailable,
      );
      expect(homeRouteForProfile(profile), '/recipient/home');
    });

    test('returns hospital dashboard for hospital role', () {
      final profile = UserProfile(
        id: 'h1', firebaseUid: 'fb1', email: 'h@h.com', name: 'Hosp',
        phone: '', bloodType: '', accountType: AccountType.hospital,
        role: UserRole.hospital, isRecipient: false, donorStatus: DonorStatus.unavailable,
        hospitalName: 'Test Hospital', hospitalCode: 'TH', hospitalVerified: true,
      );
      expect(homeRouteForProfile(profile), '/hospital/dashboard');
    });
  });
}
