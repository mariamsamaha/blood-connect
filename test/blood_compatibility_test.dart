import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/utils/blood_compatibility.dart';

void main() {
  group('donorCanFulfillRequestTypes', () {
    test('O- donors can fulfill all types', () {
      final compatible = donorCanFulfillRequestTypes['O-']!;
      expect(compatible, containsAll(['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']));
    });

    test('AB+ donors can only fulfill AB+', () {
      expect(donorCanFulfillRequestTypes['AB+'], ['AB+']);
    });

    test('O+ donors can fulfill O+, A+, B+, AB+', () {
      expect(donorCanFulfillRequestTypes['O+'], containsAll(['O+', 'A+', 'B+', 'AB+']));
      expect(donorCanFulfillRequestTypes['O+'], isNot(contains('O-')));
      expect(donorCanFulfillRequestTypes['O+'], isNot(contains('A-')));
    });
  });

  group('donorBloodTypesCompatibleWith', () {
    test('O- requests can be fulfilled by O- only', () {
      final donors = donorBloodTypesCompatibleWith('O-');
      expect(donors, ['O-']);
    });

    test('AB+ requests can be fulfilled by all types', () {
      final donors = donorBloodTypesCompatibleWith('AB+');
      expect(donors, containsAll(['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+']));
    });

    test('A+ requests can be fulfilled by O-, O+, A-, A+', () {
      final donors = donorBloodTypesCompatibleWith('A+');
      expect(donors, containsAll(['O-', 'O+', 'A-', 'A+']));
      expect(donors, isNot(contains('B+')));
    });

    test('returns empty for unknown blood type', () {
      final donors = donorBloodTypesCompatibleWith('X+');
      expect(donors, isEmpty);
    });
  });
}
