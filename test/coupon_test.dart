import 'package:bloodconnect/models/coupon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Coupon.fromJson', () {
    test('parses coupon with normal integer types', () {
      final json = {
        'id': 'coupon-1',
        'title': 'Free Coffee',
        'description': 'Get a free coffee at Coffee Shop',
        'partner_name': 'Coffee Shop',
        'partner_logo_url': 'https://example.com/logo.png',
        'discount_pct': 100,
        'points_cost': 50,
        'total_available': 10,
        'total_redeemed': 2,
        'valid_until': '2026-12-31T23:59:59Z',
        'is_active': true,
      };

      final coupon = Coupon.fromJson(json);

      expect(coupon.id, 'coupon-1');
      expect(coupon.title, 'Free Coffee');
      expect(coupon.description, 'Get a free coffee at Coffee Shop');
      expect(coupon.partnerName, 'Coffee Shop');
      expect(coupon.partnerLogoUrl, 'https://example.com/logo.png');
      expect(coupon.discountPct, 100);
      expect(coupon.pointsCost, 50);
      expect(coupon.totalAvailable, 10);
      expect(coupon.totalRedeemed, 2);
      expect(coupon.remaining, 8);
      expect(coupon.isSoldOut, isFalse);
      expect(coupon.validUntil, isNotNull);
      expect(coupon.isActive, isTrue);
    });

    test('parses coupon with stringified/bigint database types defensively', () {
      final json = {
        'id': 'coupon-2',
        'title': '50% off gym membership',
        'description': 'Half price at local gym',
        'partner_name': 'Fitness Gym',
        'partner_logo_url': null,
        'discount_pct': '50',
        'points_cost': '200',
        'total_available': '100',
        'total_redeemed': '100',
        'valid_until': null,
        'is_active': false,
      };

      final coupon = Coupon.fromJson(json);

      expect(coupon.discountPct, 50);
      expect(coupon.pointsCost, 200);
      expect(coupon.totalAvailable, 100);
      expect(coupon.totalRedeemed, 100);
      expect(coupon.remaining, 0);
      expect(coupon.isSoldOut, isTrue);
      expect(coupon.validUntil, isNull);
      expect(coupon.isActive, isFalse);
    });
  });

  group('UserCoupon.fromJson', () {
    test('parses active user coupon successfully', () {
      final json = {
        'id': 'user-coupon-1',
        'coupon_id': 'coupon-1',
        'coupon_code': 'COFFEE100',
        'redeemed_at': '2026-05-24T12:00:00Z',
        'used_at': null,
        'expires_at': '2026-08-24T12:00:00Z',
        'points_spent': 50,
        'partner_name': 'Coffee Shop',
        'title': 'Free Coffee',
        'discount_pct': 100,
      };

      final userCoupon = UserCoupon.fromJson(json);

      expect(userCoupon.id, 'user-coupon-1');
      expect(userCoupon.couponId, 'coupon-1');
      expect(userCoupon.couponCode, 'COFFEE100');
      expect(userCoupon.redeemedAt, isNotNull);
      expect(userCoupon.usedAt, isNull);
      expect(userCoupon.isUsed, isFalse);
      expect(userCoupon.expiresAt, isNotNull);
      expect(userCoupon.pointsSpent, 50);
      expect(userCoupon.partnerName, 'Coffee Shop');
      expect(userCoupon.title, 'Free Coffee');
      expect(userCoupon.discountPct, 100);
    });

    test('parses used user coupon defensively with string fields', () {
      final json = {
        'id': 'user-coupon-2',
        'coupon_id': 'coupon-2',
        'coupon_code': 'GYM50',
        'redeemed_at': '2026-05-20T10:00:00Z',
        'used_at': '2026-05-21T15:00:00Z',
        'expires_at': '2026-08-20T10:00:00Z',
        'points_spent': '200',
        'partner_name': 'Fitness Gym',
        'title': '50% off gym membership',
        'discount_pct': '50',
      };

      final userCoupon = UserCoupon.fromJson(json);

      expect(userCoupon.isUsed, isTrue);
      expect(userCoupon.usedAt, isNotNull);
      expect(userCoupon.pointsSpent, 200);
      expect(userCoupon.discountPct, 50);
    });
  });
}
