import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/localization/app_language.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'language_page.dart';

class AuthEntryPage extends StatefulWidget {
  const AuthEntryPage({super.key});

  @override
  State<AuthEntryPage> createState() => _AuthEntryPageState();
}

class _AuthEntryPageState extends State<AuthEntryPage> {
  @override
  void initState() {
    super.initState();
    // Remove splash screen since this is now the initial route
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Top Gradient Card
          SafeArea(
            bottom: false,
            child: Container(
              height: size.height * 0.65,
              width: double.infinity,
              margin: const EdgeInsets.only(left: 16, right: 16, top: 10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradientVertical,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Stack(
                children: [
                  // Fade line in background
                  Positioned(
                    top: -size.width * 0.3,
                    right: -size.width * 0.1,
                    child: Container(
                      width: size.width * 1.5,
                      height: size.width * 1.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 80,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 40, 24, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('auth.easy_connect'),
                            style: GoogleFonts.poppins(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: LocaleController.instance.language == AppLanguage.mm ? 1.6 : 1.2,
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo_3d.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Horizontal clustered pills
                  Positioned(
                    bottom: 150,
                    left: 20,
                    child: _buildDecorativePill(context.tr('auth.pill_food'), context.tr('auth.pill_food_sub'), Icons.delivery_dining, -0.05),
                  ),
                  Positioned(
                    bottom: 90,
                    left: 10,
                    child: _buildDecorativePill(
                      context.tr('auth.pill_community'), 
                      context.tr('auth.pill_community_sub'), 
                      Icons.people, 
                      0.08,
                      backgroundColor: Colors.pinkAccent,
                      textColor: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: 30,
                    child: _buildDecorativePill(context.tr('auth.pill_lost'), context.tr('auth.pill_lost_sub'), Icons.manage_search, -0.1),
                  ),
                  Positioned(
                    bottom: 180,
                    right: 40,
                    child: _buildDecorativePill(context.tr('auth.pill_secure'), context.tr('auth.pill_secure_sub'), Icons.security, 0.1),
                  ),
                  Positioned(
                    bottom: 120,
                    right: 10,
                    child: _buildDecorativePill(
                      context.tr('auth.pill_special'), 
                      context.tr('auth.pill_special_sub'), 
                      Icons.local_offer, 
                      -0.05,
                      backgroundColor: AppColors.secondary,
                      textColor: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 70,
                    right: 60,
                    child: _buildDecorativePill(context.tr('auth.pill_currency'), context.tr('auth.pill_currency_sub'), Icons.currency_exchange, -0.15),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 0,
                    child: _buildDecorativePill(context.tr('auth.pill_support'), context.tr('auth.pill_support_sub'), Icons.storefront, 0.05),
                  ),

                ],
              ),
            ),
          ),
          
          const Spacer(),

          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                PrimaryGradientButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
                  child: Text(
                    context.tr('auth.register_account'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      context.tr('auth.login_account'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: InkWell(
                    onTap: () {
                      _showLanguagePicker(context);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.language,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('language.title'),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDecorativePill(String title, String subtitle, IconData icon, double rotation, {Color backgroundColor = Colors.white, Color textColor = const Color(0xFF1E1E1E)}) {
    return FloatingPill(
      title: title,
      subtitle: subtitle,
      icon: icon,
      initialRotation: rotation,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }

  String _getFlag(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.en: return '🇬🇧';
      case AppLanguage.mm: return '🇲🇲';
      case AppLanguage.th: return '🇹🇭';
    }
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    context.tr('language.title'),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...AppLanguage.values.map((lang) {
                  return ListTile(
                    leading: Text(
                      _getFlag(lang),
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      lang.nativeName,
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    trailing: LocaleController.instance.language == lang
                        ? Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () async {
                      await LocaleController.instance.setLanguage(lang);
                      if (mounted) {
                        setState(() {});
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FloatingPill extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final double initialRotation;
  final Color backgroundColor;
  final Color textColor;

  const FloatingPill({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.initialRotation,
    this.backgroundColor = Colors.white,
    this.textColor = const Color(0xFF1E1E1E),
  });

  @override
  State<FloatingPill> createState() => _FloatingPillState();
}

class _FloatingPillState extends State<FloatingPill> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _moveAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    // Randomize duration slightly based on text length to make them out of sync
    final durationMs = 2000 + (widget.title.length * 50);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..repeat(reverse: true);

    _moveAnimation = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _rotationAnimation = Tween<double>(
      begin: widget.initialRotation - 0.04, 
      end: widget.initialRotation + 0.04
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _moveAnimation.value),
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: widget.textColor.withValues(alpha: 0.1),
                    child: Icon(widget.icon, color: widget.textColor, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          color: widget.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: GoogleFonts.poppins(
                          color: widget.textColor.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
