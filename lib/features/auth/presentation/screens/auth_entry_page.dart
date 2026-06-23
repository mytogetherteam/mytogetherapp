import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import 'login_page.dart';
import 'register_page.dart';
import '../../../main_navigation/presentation/screens/main_navigation_screen.dart';

class AuthEntryPage extends StatefulWidget {
  const AuthEntryPage({super.key});

  @override
  State<AuthEntryPage> createState() => _AuthEntryPageState();
}

class _AuthEntryPageState extends State<AuthEntryPage> {
  @override
  void initState() {
    super.initState();
    // Remove splash screen after first frame is rendered to prevent flash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        FlutterNativeSplash.remove();
      });
    });
  }

  void _dismiss() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
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
                  Positioned(
                    top: 8,
                    left: 4,
                    child: IconButton(
                      onPressed: _dismiss,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
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
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(2), // Gradient border width
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: GradientText(
                          context.tr('auth.login_account'),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const MainNavigationScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  child: Text(
                    context.tr('auth.continue_guest'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
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
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                            child: const Icon(
                              Icons.language,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GradientText(
                            context.tr('language.title'),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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
    ));
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

class _FloatingPillState extends State<FloatingPill> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _moveAnimation;
  late Animation<double> _rotationAnimation;

  // Physics state
  Offset _position = Offset.zero;
  Offset _velocity = Offset.zero;
  Offset _prevAccel = Offset.zero;
  Ticker? _physicsTicker;
  DateTime _lastTickTime = DateTime.now();
  StreamSubscription<AccelerometerEvent>? _accelSub;

  late final double _mass;

  @override
  void initState() {
    super.initState();
    _mass = 0.8 + (widget.title.length % 5) * 0.1;

    // Idle floating animation
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
      end: widget.initialRotation + 0.04,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    // Physics ticker
    _physicsTicker = createTicker((_) {
      final now = DateTime.now();
      final dt = now.difference(_lastTickTime).inMilliseconds / 1000.0;
      _lastTickTime = now;
      if (dt <= 0 || dt > 0.1) return;

      const stiffness = 80.0;
      const damping = 8.0;

      final springForce = -_position * stiffness;
      final dampForce = -_velocity * damping;
      final acceleration = (springForce + dampForce) / _mass;

      setState(() {
        _velocity += acceleration * dt;
        _position += _velocity * dt;

        // Boundary constraints to keep pills inside the card area
        const maxDx = 60.0;
        const maxDy = 60.0;
        
        if (_position.dx > maxDx) {
          _position = Offset(maxDx, _position.dy);
          _velocity = Offset(-_velocity.dx * 0.6, _velocity.dy);
        } else if (_position.dx < -maxDx) {
          _position = Offset(-maxDx, _position.dy);
          _velocity = Offset(-_velocity.dx * 0.6, _velocity.dy);
        }
        
        if (_position.dy > maxDy) {
          _position = Offset(_position.dx, maxDy);
          _velocity = Offset(_velocity.dx, -_velocity.dy * 0.6);
        } else if (_position.dy < -maxDy) {
          _position = Offset(_position.dx, -maxDy);
          _velocity = Offset(_velocity.dx, -_velocity.dy * 0.6);
        }

        if (_velocity.distance < 0.5 && _position.distance < 0.5) {
          _velocity = Offset.zero;
          _position = Offset.zero;
        }
      });
    })..start();

    // Accelerometer — detect shake from sudden delta
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 16),
    ).listen((AccelerometerEvent event) {
      final current = Offset(event.x, event.y);
      final delta = current - _prevAccel;
      _prevAccel = current;

      final shakeMagnitude = delta.distance;
      if (shakeMagnitude > 1.2) {
        final impulseScale = (shakeMagnitude * 12.0).clamp(0.0, 120.0);
        _velocity += Offset(
          delta.dx * -impulseScale / _mass,
          delta.dy * impulseScale / _mass,
        );
        final speed = _velocity.distance;
        if (speed > 200) {
          _velocity = _velocity / speed * 200;
        }
      }
    });
  }

  @override
  void dispose() {
    _physicsTicker?.dispose();
    _controller.dispose();
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _position.dx,
            _moveAnimation.value + _position.dy,
          ),
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
