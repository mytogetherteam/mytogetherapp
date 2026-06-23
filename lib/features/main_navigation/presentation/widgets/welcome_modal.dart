import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';

class WelcomeModal extends StatelessWidget {
  final VoidCallback onClosed;

  const WelcomeModal({super.key, required this.onClosed});

  static bool _hasShownThisSession = false;

  /// Shows the modal once per app session when the user first reaches this screen.
  static Future<void> showIfFirstTime(
      BuildContext context, VoidCallback onClosed) async {
    if (!_hasShownThisSession) {
      _hasShownThisSession = true;
      if (!context.mounted) return;

      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return WelcomeModal(onClosed: () {
            Navigator.of(context).pop();
            onClosed();
          });
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      );
    } else {
      onClosed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Gradient and Logo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo_3d.png',
                      height: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Closed Beta 🎉',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildParagraph('🚀 Team တစ်ခုလုံး ညနေးမအိပ် ကြိုးစားခဲ့တဲ့ MyTogether App Closed Beta မှ ကြိုဆိုပါတယ်!'),
                      const SizedBox(height: 12),
                      _buildParagraph('🔥 Early Bird တွေအတွက် Official Launch မှာ Promotions အများကြီး ထားပေးထားပါတယ်။'),
                      const SizedBox(height: 12),
                      _buildParagraph('🫶 Beta ဖြစ်လို့ အမှားပါနိုင်ပါတယ် — ဝေဖန် အကြံပြုပေးပါနော်!'),
                    ],
                  ),
                ),
              ),
              
              // Bottom Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: PrimaryGradientButton(
                  onPressed: onClosed,
                  width: double.infinity,
                  child: Text(
                    'အခုပဲ စတင်မယ်',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.black87,
        height: 1.8,
      ),
      textAlign: TextAlign.justify,
    );
  }
}
