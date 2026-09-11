import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/referral_model.dart';
import '../../data/referral_service.dart';
import 'edit_promote_code_dialog.dart';

class PromoteCodeCard extends StatelessWidget {
  final MyReferralCode? myCode;
  final VoidCallback onCodeUpdated;

  const PromoteCodeCard({
    super.key,
    required this.myCode,
    required this.onCodeUpdated,
  });

  void _copyToClipboard(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(PhosphorIcons.checkCircleFill, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Promote code "$code" copied!'),
          ],
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareCode(String code) {
    HapticFeedback.lightImpact();
    // ignore: deprecated_member_use
    Share.share(
      'Join me on MyTogether! Use my referral code "$code" when you register to get special rewards and coupons! Download the app: https://mytogether.app',
      subject: 'Join MyTogether with my referral code!',
    );
  }

  Future<void> _handleDeleteCode(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Promote Code?'),
        content: const Text(
          'Are you sure you want to remove your promote code? You can recreate or activate a code at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ReferralService.instance.deleteMyCode();
        onCodeUpdated();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete code: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (myCode == null || !myCode!.isActive) {
      // Empty state: Prompt user to create code
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIcons.sparkleFill,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Create Your Promote Code',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Customize your personal code, share with friends, and earn coupons whenever they order!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final newCode = await EditPromoteCodeDialog.show(context);
                  if (newCode != null) onCodeUpdated();
                },
                icon: const Icon(PhosphorIcons.plusBold, size: 18, color: Colors.white),
                label: const Text(
                  'Set Custom Code',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Active Code State
    final code = myCode!.code;
    final usedCount = myCode!.usedCount;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative elements
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              PhosphorIcons.ticketFill,
              size: 130,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(PhosphorIcons.sparkleFill,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'YOUR PROMOTE CODE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Edit button
                        IconButton(
                          icon: const Icon(PhosphorIcons.pencilSimple,
                              color: Colors.white, size: 20),
                          tooltip: 'Edit code',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            final updated = await EditPromoteCodeDialog.show(
                              context,
                              initialCode: code,
                            );
                            if (updated != null) onCodeUpdated();
                          },
                        ),
                        const SizedBox(width: 14),
                        // Delete / Remove button
                        IconButton(
                          icon: const Icon(PhosphorIcons.trash,
                              color: Colors.white70, size: 20),
                          tooltip: 'Remove code',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _handleDeleteCode(context),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Code Box with dashed or solid highlight
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(PhosphorIcons.copy,
                            color: Colors.white, size: 22),
                        onPressed: () => _copyToClipboard(context, code),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(PhosphorIcons.usersFill,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$usedCount ${usedCount == 1 ? "friend joined" : "friends joined"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _shareCode(code),
                      icon: const Icon(PhosphorIcons.shareNetworkBold,
                          size: 16, color: AppColors.primary),
                      label: const Text(
                        'Share',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
