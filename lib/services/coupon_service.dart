import 'package:bloodconnect/models/coupon.dart';
import 'package:bloodconnect/services/api_client.dart';

class CouponService {
  final ApiClient _api;
  CouponService(this._api);

  Future<List<Coupon>> getAvailableCoupons() async {
    final rows = await _api.getJsonList('/api/v1/coupons');
    return rows.map(Coupon.fromJson).toList();
  }

  Future<List<UserCoupon>> getMyCoupons() async {
    final rows = await _api.getJsonList('/api/v1/coupons/mine');
    return rows.map(UserCoupon.fromJson).toList();
  }

  Future<Map<String, dynamic>> redeemCoupon(String couponId) async {
    final data = await _api.postJson(
      '/api/v1/coupons/redeem',
      body: {'couponId': couponId},
    );
    return data;
  }
}
