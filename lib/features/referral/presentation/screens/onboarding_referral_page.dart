import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/referral_service.dart';
import '../widgets/edit_promote_code_dialog.dart';
import '../widgets/referral_reward_celebration_sheet.dart';

class OnboardingReferralPage extends StatefulWidget {
  const OnboardingReferralPage({super.key});

  @override
  State<OnboardingReferralPage> createState() => _OnboardingReferralPageState();
}

class _OnboardingReferralPageState extends State<OnboardingReferralPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  Future<void> _submitCode() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      _navigateToHome();
      return;
    }

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
      await ReferralRewardCelebrationSheet.show(
        context,
        result: result,
        onPrimaryAction: _navigateToHome,
      );
      if (mounted) _navigateToHome();
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _navigateToHome,
            child: const Text(
              'Skip',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Big Gift Hero Icon
              Container(
                width: 90,
                height: 90,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  PhosphorIcons.giftFill,
                  color: Colors.white,
                  size: 46,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Welcome to MyTogether!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Got a referral or promote code from a friend?\nEnter it below to unlock welcome coupons and perks!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // Input Box
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _errorMessage != null
                        ? Colors.red.shade300
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(PhosphorIcons.ticket, color: Colors.grey, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
                          UpperCaseTextFormatter(),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'ENTER CODE (OPTIONAL)',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: Colors.black38,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _controller.clear();
                            _errorMessage = null;
                          });
                        },
                      ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(PhosphorIcons.warningCircleFill,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // Action Button
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Claim & Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: _isLoading ? null : _navigateToHome,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                ),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(fontSize: 14),
                ),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIcons.info, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can also enter a referral code later anytime in Profile → Referral & Promote Code.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
