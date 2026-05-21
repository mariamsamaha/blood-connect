import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/services/location_service.dart';

void main() {
  group('LocationService', () {
    test('formatCoordinates formats correctly', () {
      final service = LocationService();
      expect(service.formatCoordinates(30.0444, 31.2357), '30.0444, 31.2357');
    });

    test('formatCoordinates handles negative values', () {
      final service = LocationService();
      expect(service.formatCoordinates(-1.2345, 45.6789), '-1.2345, 45.6789');
    });

    test('formatCoordinates handles zero', () {
      final service = LocationService();
      expect(service.formatCoordinates(0.0, 0.0), '0.0000, 0.0000');
    });
  });
}
