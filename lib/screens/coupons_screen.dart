import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/coupon.dart';
import 'package:bloodconnect/services/coupon_service.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final couponServiceProvider = Provider<CouponService>(
  (ref) => CouponService(ref.watch(apiClientProvider)),
);

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});
  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Coupon> _available = [];
  List<UserCoupon> _mine = [];
  int _points = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider).currentUser;
      int pts = 0;
      if (auth != null) {
        final p = await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
        pts = p?.rewardPoints ?? 0;
      }
      final svc = ref.read(couponServiceProvider);
      final r = await Future.wait([svc.getAvailableCoupons(), svc.getMyCoupons()]);
      if (!mounted) return;
      setState(() {
        _available = r[0] as List<Coupon>;
        _mine = r[1] as List<UserCoupon>;
        _points = pts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _redeem(Coupon c) async {
    if (_points < c.pointsCost) {
      _snack('You need ${c.pointsCost} pts. You have $_points.', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(coupon: c, points: _points),
    );
    if (ok != true) return;
    try {
      final data = await ref.read(couponServiceProvider).redeemCoupon(c.id);
      if (!mounted) return;
      if (data['error'] != null) {
        _snack(_err(data['error'] as String), error: true);
        return;
      }
      await _load();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => _CodeDialog(coupon: c, code: data['coupon_code'] as String),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('$e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  String _err(String e) => switch (e) {
        'insufficient_points' => 'Not enough points.',
        'coupon_sold_out' => 'This coupon is sold out.',
        'coupon_expired' => 'This coupon has expired.',
        _ => 'Something went wrong.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Coupons & Rewards'),
        bottom: TabBar(
          controller: _tab,
          tabs: [const Tab(text: 'Available'), Tab(text: 'Mine (${_mine.length})')],
        ),
      ),
      body: Column(
        children: [
          // Points banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primaryRed, AppColors.deepRed]),
            ),
            child: Row(children: [
              const Text('⭐', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$_points points',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const Text('Donate more to earn', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tab,
                    children: [
                      _AvailableTab(coupons: _available, points: _points, onRedeem: _redeem),
                      _MineTab(coupons: _mine),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Available tab ────────────────────────────────────────────────────────────
class _AvailableTab extends StatelessWidget {
  const _AvailableTab({required this.coupons, required this.points, required this.onRedeem});
  final List<Coupon> coupons;
  final int points;
  final void Function(Coupon) onRedeem;

  @override
  Widget build(BuildContext context) {
    if (coupons.isEmpty) return const Center(child: Text('No coupons available right now.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: coupons.length,
      itemBuilder: (_, i) => _CouponCard(coupon: coupons[i], points: points, onRedeem: onRedeem),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon, required this.points, required this.onRedeem});
  final Coupon coupon;
  final int points;
  final void Function(Coupon) onRedeem;

  @override
  Widget build(BuildContext context) {
    final canAfford = points >= coupon.pointsCost && !coupon.isSoldOut;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Discount banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A6CB5), Color(0xFF0D4A8F)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${coupon.discountPct}%',
                  style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              const Text('OFF', style: TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.w700)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coupon.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(coupon.partnerName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(coupon.description,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: [
                    _Chip('⭐ ${coupon.pointsCost} pts', AppColors.warning),
                    _Chip('🏷 ${coupon.remaining} left',
                        coupon.isSoldOut ? AppColors.textSecondary : AppColors.success),
                    if (coupon.validUntil != null)
                      _Chip('📅 Ends ${_fmt(coupon.validUntil!)}', AppColors.textSecondary),
                  ],
                ),
                if (!canAfford && points < coupon.pointsCost) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (points / coupon.pointsCost).clamp(0.0, 1.0),
                    backgroundColor: AppColors.divider,
                    color: AppColors.primaryRed,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: AppButton.primary(
                    label: coupon.isSoldOut
                        ? 'Sold Out'
                        : canAfford
                            ? 'Redeem for ${coupon.pointsCost} pts'
                            : 'Need ${coupon.pointsCost - points} more pts',
                    onPressed: canAfford ? () => onRedeem(coupon) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );
}

// ─── Mine tab ─────────────────────────────────────────────────────────────────
class _MineTab extends StatelessWidget {
  const _MineTab({required this.coupons});
  final List<UserCoupon> coupons;

  @override
  Widget build(BuildContext context) {
    if (coupons.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏷️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('No coupons yet.\nRedeem your points to get one!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: coupons.length,
      itemBuilder: (_, i) => _MineCard(coupon: coupons[i]),
    );
  }
}

class _MineCard extends StatelessWidget {
  const _MineCard({required this.coupon});
  final UserCoupon coupon;

  @override
  Widget build(BuildContext context) {
    final used = coupon.isUsed;
    final expired = coupon.isExpired;
    final color = used || expired ? AppColors.textSecondary : AppColors.success;
    final label = used ? 'Used' : expired ? 'Expired' : 'Active';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(coupon.title ?? '${coupon.discountPct ?? '?'}% off',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        if (coupon.partnerName != null) ...[
          const SizedBox(height: 4),
          Text(coupon.partnerName!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: coupon.couponCode));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!')));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(coupon.couponCode,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w800,
                      letterSpacing: 2, color: AppColors.textPrimary)),
              const Icon(Icons.copy, size: 18, color: AppColors.textSecondary),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text('Expires ${_fmt(coupon.expiresAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ─── Dialogs ──────────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.coupon, required this.points});
  final Coupon coupon;
  final int points;
  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm redemption'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(coupon.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          _Row('Cost:', '${coupon.pointsCost} pts'),
          _Row('Your balance:', '$points pts'),
          _Row('After:', '${points - coupon.pointsCost} pts'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            child: const Text('Redeem', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      );
}

class _CodeDialog extends StatelessWidget {
  const _CodeDialog({required this.coupon, required this.code});
  final Coupon coupon;
  final String code;
  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 8),
          const Text('Your coupon is ready!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(coupon.partnerName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(code,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w900,
                        letterSpacing: 2.5, color: AppColors.textPrimary)),
                const SizedBox(width: 10),
                const Icon(Icons.copy, size: 20, color: AppColors.textSecondary),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Show at the lab reception.\nValid for 90 days.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
}
