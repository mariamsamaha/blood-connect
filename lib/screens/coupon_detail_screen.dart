import 'package:bloodconnect/models/coupon.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CouponDetailScreen extends ConsumerWidget {
  const CouponDetailScreen({super.key, required this.coupon});
  final UserCoupon coupon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final used = coupon.isUsed;
    final expired = coupon.isExpired;
    final active = !used && !expired;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, active),
          SliverToBoxAdapter(child: _buildHeroSection(context, active)),
          SliverToBoxAdapter(child: _buildCodeSection(context, active)),
          SliverToBoxAdapter(child: _buildExpirationSection(context)),
          SliverToBoxAdapter(child: _buildActionsSection(context, active)),
          SliverToBoxAdapter(child: _buildInstructionsCard(context)),
          SliverToBoxAdapter(child: _buildExpandableTerms(context)),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool active) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Coupon Details'),
      actions: [
        if (active)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                SizedBox(width: 4),
                Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeroSection(BuildContext context, bool active) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primaryRed.withValues(alpha: 0.08)
                  : AppColors.divider.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? AppColors.primaryRed.withValues(alpha: 0.15)
                    : AppColors.divider,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.local_hospital_rounded,
                size: 40,
                color: active ? AppColors.primaryRed : AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            coupon.partnerName ?? 'Partner',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            coupon.title ?? '${coupon.discountPct ?? '?'}% off',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeSection(BuildContext context, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : AppColors.divider.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: active ? AppColors.primaryRed.withValues(alpha: 0.2) : AppColors.divider,
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              'Coupon Code',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primaryRed : AppColors.textTertiary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: active
                  ? () {
                      Clipboard.setData(ClipboardData(text: coupon.couponCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard!')),
                      );
                    }
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: active ? AppColors.softRed : AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      coupon.couponCode,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: active ? AppColors.primaryRed : AppColors.textTertiary,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpirationSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Text(
            'Valid until ${_fmt(coupon.expiresAt)}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context, bool active) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: active
                    ? () {
                        Clipboard.setData(ClipboardData(text: coupon.couponCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      }
                    : null,
                icon: const Icon(Icons.copy_rounded, size: 20),
                label: const Text('Copy Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: active ? AppColors.primaryRed : AppColors.divider,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  elevation: active ? 4 : 0,
                  shadowColor: active ? AppColors.primaryRed.withValues(alpha: 0.3) : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: active
                    ? () {
                        Clipboard.setData(ClipboardData(text: coupon.couponCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied to clipboard!')),
                        );
                      }
                    : null,
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: active ? AppColors.textPrimary : AppColors.textTertiary,
                  side: BorderSide(
                    color: active ? AppColors.divider : AppColors.divider.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
                const SizedBox(width: 8),
                Text(
                  'How to redeem',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InstructionStep(number: 1, text: 'Show this coupon code to the partner at reception'),
            _InstructionStep(number: 2, text: 'Present a valid ID matching your profile name'),
            _InstructionStep(number: 3, text: 'Enjoy your ${coupon.discountPct ?? ''}% discount or free service'),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Not transferable. One-time use only. Cannot be combined with other offers.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableTerms(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'This coupon is issued by BloodConnect in partnership with ${coupon.partnerName ?? 'the partner'}. '
              'Valid only for the specified service/product. Must be used before the expiration date. '
              'Coupon cannot be exchanged for cash, refunded, or transferred. '
              'BloodConnect reserves the right to modify or cancel this offer at any time. '
              'Additional restrictions may apply at the partner\'s discretion.',
              style: const TextStyle(fontSize: 13, color: AppColors.textTertiary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
