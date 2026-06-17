import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';

class WelcomeModal extends StatelessWidget {
  final VoidCallback onClosed;

  const WelcomeModal({super.key, required this.onClosed});

  static const String _prefsKey = 'has_seen_welcome_modal';

  /// Checks SharedPreferences and shows the modal if it's the user's first time.
  static Future<void> showIfFirstTime(
      BuildContext context, VoidCallback onClosed) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(_prefsKey) ?? false;

    if (!hasSeen) {
      if (!context.mounted) return;
      await prefs.setBool(_prefsKey, true);

      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.white,
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIcons.handWavingFill,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'မင်္ဂလာပါခင်ဗျာ!',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'MyTogether မိသားစုကနေ\nနွေးထွေးစွာ ကြိုဆိုလိုက်ပါတယ်ဗျ။',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'အခုဆိုရင် လူကြီးမင်းဟာ ကျွန်တော်တို့ရဲ့ အပျော်ရဆုံးနဲ့ အနွေးထွေးဆုံး MyTogether Community ကြီးရဲ့ အဖွဲ့ဝင် ဖြစ်သွားပြီနော်။\n\nကျွန်တော်တို့ အတူတူ ဘာတွေ လုပ်လို့ရမလဲဆိုတော့ -',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Features List
                    _buildFeatureItem(
                      icon: PhosphorIcons.storefront,
                      title: 'ဗိုက်ဆာရင် အတူတူရှာမယ်',
                      description: 'ဘန်ကောက်ရဲ့ နာမည်ကြီး ဆိုင်ကောင်း၊ သောက်ကောင်းလေးတွေကို မြေပုံနဲ့တကွ စက္ကန့်ပိုင်းအတွင်း တန်းရှာပေးမှာ!',
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      icon: PhosphorIcons.magnifyingGlass,
                      title: 'Lost & Found',
                      description: 'အပျောက်အရှာ ကူညီမယ်။',
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      icon: PhosphorIcons.currencyCircleDollar,
                      title: 'Money Rate',
                      description: 'နေ့စဉ် ငွေလဲနှုန်းကြည့်မယ်။',
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      icon: PhosphorIcons.newspaper,
                      title: 'News',
                      description: 'နောက်ဆုံးရသတင်းနဲ့ ဗီဇာအချက်အလက်။',
                      color: const Color(0xFF6366F1),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      icon: PhosphorIcons.usersThree,
                      title: 'Support',
                      description: 'အချင်းချင်းဝိုင်းဝန်းကူညီမယ်။',
                      color: const Color(0xFFEC4899),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // Bottom Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryGradientButton(
                onPressed: onClosed,
                width: double.infinity,
                child: Text(
                  'စတင်အသုံးပြုမယ်', // "Let's start using"
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
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            size: 24,
            color: color,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
