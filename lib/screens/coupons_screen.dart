import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/coupon.dart';
import 'package:bloodconnect/screens/coupon_detail_screen.dart';
import 'package:bloodconnect/services/coupon_service.dart';
import 'package:bloodconnect/theme/app_theme.dart';
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

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  List<Coupon> _available = [];
  List<UserCoupon> _mine = [];
  int _points = 0;
  int _donations = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider).currentUser;
      int pts = 0;
      int dons = 0;
      if (auth != null) {
        final p = await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
        pts = p?.rewardPoints ?? 0;
        dons = p?.totalDonations ?? 0;
      }
      final svc = ref.read(couponServiceProvider);
      final r = await Future.wait([svc.getAvailableCoupons(), svc.getMyCoupons()]);
      if (!mounted) return;
      setState(() {
        _available = r[0] as List<Coupon>;
        _mine = r[1] as List<UserCoupon>;
        _points = pts;
        _donations = dons;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int get _activeCount => _mine.where((c) => !c.isUsed && !c.isExpired).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildHeader(),
                if (_mine.isNotEmpty) _buildFeaturedReward(),
                _buildMyCouponsSection(),
                _buildLockedRewardsSection(),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      title: Row(
        children: [
          Text(
            'My Coupons',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          if (_activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_activeCount Active',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
        ],
      ),
      actions: [
        if (_available.isNotEmpty)
          TextButton.icon(
            onPressed: _showBrowseRewards,
            icon: const Icon(Icons.card_giftcard_rounded, size: 18),
            label: const Text('Browse'),
          ),
      ],
    );
  }

  Widget _buildFeaturedReward() {
    final tier = _getTier();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: tier == 'Gold'
                  ? [const Color(0xFFFFF8E1), const Color(0xFFFFF3C4)]
                  : tier == 'Silver'
                      ? [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)]
                      : [const Color(0xFFFFF8E1), const Color(0xFFFFF3C4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: tier == 'Gold'
                    ? AppColors.gold.withValues(alpha: 0.2)
                    : AppColors.textTertiary.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tier == 'Gold'
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : AppColors.primaryRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    tier == 'Gold' ? '🥇' : tier == 'Silver' ? '🥈' : '🥉',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$tier Donor Rewards',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _donations >= 10
                    ? 'Earned by reaching $tier Badge'
                    : '$_donations donations toward $tier',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_donations < 10) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_donations / 10).clamp(0.0, 1.0),
                    backgroundColor: AppColors.divider,
                    color: tier == 'Gold' ? AppColors.gold : AppColors.primaryRed,
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyCouponsSection() {
    if (_mine.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            children: [
              const Icon(Icons.redeem_rounded, size: 56, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              const Text(
                'No coupons yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Redeem your points in the Browse tab to get started!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'Available Coupons',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ...List.generate(_mine.length, (i) => _buildCouponCard(_mine[i])),
        ],
      ),
    );
  }

  Widget _buildCouponCard(UserCoupon coupon) {
    final used = coupon.isUsed;
    final expired = coupon.isExpired;
    final active = !used && !expired;
    final borderColor = active ? AppColors.success.withValues(alpha: 0.3) : AppColors.divider;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CouponDetailScreen(coupon: coupon),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: borderColor),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.softGreen
                      : AppColors.divider.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Icon(
                    active ? Icons.discount_rounded : Icons.check_circle_outline_rounded,
                    color: active ? AppColors.success : AppColors.textTertiary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            coupon.title ?? '${coupon.discountPct ?? '?'}% off',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.textSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            used ? 'Used' : expired ? 'Expired' : 'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active ? AppColors.success : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (coupon.partnerName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        coupon.partnerName!,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: coupon.couponCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              coupon.couponCode,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy_rounded, size: 14, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Expires ${_fmt(coupon.expiresAt)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedRewardsSection() {
    final lockedRewards = [
      _LockedReward(
        icon: '🥇',
        title: 'Gold Donor Reward',
        requirement: 'Reach 10 donations',
        unlocked: _donations >= 10,
        progress: (_donations / 10).clamp(0.0, 1.0),
      ),
      _LockedReward(
        icon: '🏆',
        title: 'Platinum Donor Reward',
        requirement: 'Reach 25 donations',
        unlocked: _donations >= 25,
        progress: (_donations / 25).clamp(0.0, 1.0),
      ),
      _LockedReward(
        icon: '💎',
        title: 'Legendary Reward',
        requirement: 'Unlock after 50 donations',
        unlocked: _donations >= 50,
        progress: (_donations / 50).clamp(0.0, 1.0),
      ),
    ];

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  'Locked Rewards',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.lock_rounded, size: 16, color: AppColors.textTertiary),
              ],
            ),
          ),
          ...lockedRewards.map((r) => _buildLockedCard(r)),
        ],
      ),
    );
  }

  Widget _buildLockedCard(_LockedReward reward) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Text(reward.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reward.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: reward.unlocked ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Icon(
                        reward.unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                        size: 16,
                        color: reward.unlocked ? AppColors.success : AppColors.textTertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reward.unlocked ? 'Unlocked!' : reward.requirement,
                    style: TextStyle(
                      fontSize: 12,
                      color: reward.unlocked ? AppColors.success : AppColors.textTertiary,
                    ),
                  ),
                  if (!reward.unlocked) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: reward.progress,
                        backgroundColor: AppColors.divider,
                        color: AppColors.gold,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBrowseRewards() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _BrowseRewardsSheet(
        coupons: _available,
        points: _points,
        onRedeem: (c) {
          Navigator.pop(ctx);
          _redeem(c);
        },
      ),
    );
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
      _snack('Coupon redeemed! Code: ${data['coupon_code']}', error: false);
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

  String _getTier() {
    if (_donations >= 10) return 'Gold';
    if (_donations >= 5) return 'Silver';
    return 'Bronze';
  }

  String _fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';
}

class _LockedReward {
  final String icon;
  final String title;
  final String requirement;
  final bool unlocked;
  final double progress;
  const _LockedReward({
    required this.icon,
    required this.title,
    required this.requirement,
    required this.unlocked,
    required this.progress,
  });
}

// ─── Browse Rewards Bottom Sheet ─────────────────────────────────────────────

class _BrowseRewardsSheet extends StatelessWidget {
  const _BrowseRewardsSheet({
    required this.coupons,
    required this.points,
    required this.onRedeem,
  });
  final List<Coupon> coupons;
  final int points;
  final void Function(Coupon) onRedeem;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Browse Rewards',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          '$points pts',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: coupons.isEmpty
                  ? const Center(child: Text('No rewards available right now.'))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: coupons.length,
                      itemBuilder: (_, i) => _BrowseCard(
                        coupon: coupons[i],
                        points: points,
                        onRedeem: onRedeem,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _BrowseCard extends StatelessWidget {
  const _BrowseCard({
    required this.coupon,
    required this.points,
    required this.onRedeem,
  });
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A6CB5), Color(0xFF0D4A8F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Text(
                  '${coupon.discountPct}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    coupon.partnerName,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MiniChip(icon: '⭐', text: '${coupon.pointsCost} pts', color: AppColors.warning),
                      const SizedBox(width: 6),
                      _MiniChip(
                        icon: '🏷',
                        text: '${coupon.remaining} left',
                        color: coupon.isSoldOut ? AppColors.textSecondary : AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: canAfford ? () => onRedeem(coupon) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford ? AppColors.primaryRed : AppColors.divider,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  coupon.isSoldOut ? 'Sold' : canAfford ? 'Redeem' : 'Need ${coupon.pointsCost - points}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.text, required this.color});
  final String icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$icon $text',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      );
}

// ─── Dialogs ─────────────────────────────────────────────────────────────────

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
