class Coupon {
  final String id;
  final String title;
  final String description;
  final String partnerName;
  final String? partnerLogoUrl;
  final int discountPct;
  final int pointsCost;
  final int totalAvailable;
  final int totalRedeemed;
  final DateTime? validUntil;
  final bool isActive;

  const Coupon({
    required this.id, required this.title, required this.description,
    required this.partnerName, this.partnerLogoUrl,
    required this.discountPct, required this.pointsCost,
    required this.totalAvailable, required this.totalRedeemed,
    this.validUntil, required this.isActive,
  });

  int get remaining => totalAvailable - totalRedeemed;
  bool get isSoldOut => remaining <= 0;

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        partnerName: json['partner_name'] as String,
        partnerLogoUrl: json['partner_logo_url'] as String?,
        discountPct: json['discount_pct'] is int
            ? json['discount_pct'] as int
            : int.tryParse(json['discount_pct']?.toString() ?? '') ?? 10,
        pointsCost: json['points_cost'] is int
            ? json['points_cost'] as int
            : int.tryParse(json['points_cost']?.toString() ?? '') ?? 500,
        totalAvailable: json['total_available'] is int
            ? json['total_available'] as int
            : int.tryParse(json['total_available']?.toString() ?? '') ?? 0,
        totalRedeemed: json['total_redeemed'] is int
            ? json['total_redeemed'] as int
            : int.tryParse(json['total_redeemed']?.toString() ?? '') ?? 0,
        validUntil: json['valid_until'] != null
            ? DateTime.tryParse(json['valid_until'] as String)
            : null,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class UserCoupon {
  final String id;
  final String couponId;
  final String couponCode;
  final DateTime redeemedAt;
  final DateTime? usedAt;
  final DateTime expiresAt;
  final int pointsSpent;
  final String? partnerName;
  final String? title;
  final int? discountPct;

  const UserCoupon({
    required this.id, required this.couponId, required this.couponCode,
    required this.redeemedAt, this.usedAt, required this.expiresAt,
    required this.pointsSpent, this.partnerName, this.title, this.discountPct,
  });

  bool get isUsed => usedAt != null;
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory UserCoupon.fromJson(Map<String, dynamic> json) => UserCoupon(
        id: json['id'] as String,
        couponId: json['coupon_id'] as String,
        couponCode: json['coupon_code'] as String,
        redeemedAt: DateTime.tryParse(json['redeemed_at'] as String? ?? '') ?? DateTime.now(),
        usedAt: json['used_at'] != null ? DateTime.tryParse(json['used_at'] as String) : null,
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 90)),
        pointsSpent: json['points_spent'] is int
            ? json['points_spent'] as int
            : int.tryParse(json['points_spent']?.toString() ?? '') ?? 0,
        partnerName: json['partner_name'] as String?,
        title: json['title'] as String?,
        discountPct: json['discount_pct'] is int
            ? json['discount_pct'] as int
            : int.tryParse(json['discount_pct']?.toString() ?? ''),
      );
}
