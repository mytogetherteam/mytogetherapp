import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/referral_model.dart';
import '../../data/referral_service.dart';
import 'edit_promote_code_dialog.dart';
import 'referral_reward_celebration_sheet.dart';

class EnterFriendCodeCard extends StatefulWidget {
  final ClaimedReferralInfo? claimedReferral;
  final bool canClaim;
  final VoidCallback onClaimSuccess;

  const EnterFriendCodeCard({
    super.key,
    required this.claimedReferral,
    required this.canClaim,
    required this.onClaimSuccess,
  });

  @override
  State<EnterFriendCodeCard> createState() => _EnterFriendCodeCardState();
}

class _EnterFriendCodeCardState extends State<EnterFriendCodeCard> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _claimCode() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (code.length < 3) {
      setState(() => _errorMessage = 'Code must be at least 3 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ReferralService.instance.claimReferral(code);
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onClaimSuccess();
      ReferralRewardCelebrationSheet.show(context, result: result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canClaim && widget.claimedReferral != null) {
      // Already claimed state
      final claimed = widget.claimedReferral!;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIcons.checkCircleFill,
                color: Colors.green,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Referral Code Applied',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Invited by ${claimed.referrerName} (${claimed.code})',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!widget.canClaim) {
      return const SizedBox.shrink();
    }

    // Input state
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIcons.ticket,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Have a Friend\'s Referral Code?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter their code below to receive welcome rewards and coupons.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
                      UpperCaseTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: 'ENTER CODE',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _claimCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Apply',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(PhosphorIcons.warningCircleFill,
                    color: Colors.red, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
