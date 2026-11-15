import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../features/home/data/repositories/restaurant_repository.dart';
import '../localization/app_language.dart';
import '../localization/app_translations.dart';
import '../localization/locale_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// Holds the optional remote Splash banner fetched at boot.
class BrandedSplash {
  BrandedSplash._();

  static String? imageUrl;
  static Uint8List? imageBytes;

  static bool get hasSplash =>
      (imageBytes != null && imageBytes!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  /// Fetches `position=Splash`. Keeps the URL even if byte download fails so
  /// the gate can still render via [CachedNetworkImage].
  static Future<void> prefetch() async {
    try {
      final banners = await RestaurantRepository.instance.getBanners(
        position: 'Splash',
      );
      final url = banners.isNotEmpty ? banners.first.imageUrl : null;
      if (url == null || url.isEmpty) {
        imageUrl = null;
        imageBytes = null;
        return;
      }

      imageUrl = url;

      try {
        final response = await Dio().get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 4),
            sendTimeout: const Duration(seconds: 4),
          ),
        );
        final data = response.data;
        if (response.statusCode == 200 && data != null && data.isNotEmpty) {
          imageBytes = Uint8List.fromList(data);
        }
      } catch (e) {
        imageBytes = null;
      }
    } catch (e) {
      imageUrl = null;
      imageBytes = null;
    }
  }
}

/// Full-screen animated default splash over [child] with logo animation
/// and localized "Easy Connect Super App" title.
/// If a remote splash banner was fetched at boot, it displays afterwards.
class BrandedSplashGate extends StatefulWidget {
  final Widget child;
  final Duration minDisplay;

  const BrandedSplashGate({
    super.key,
    required this.child,
    this.minDisplay = const Duration(milliseconds: 2200),
  });

  @override
  State<BrandedSplashGate> createState() => _BrandedSplashGateState();
}

class _BrandedSplashGateState extends State<BrandedSplashGate>
    with TickerProviderStateMixin {
  late final bool _hasRemoteSplash;

  bool _showDefaultSplash = true;
  bool _defaultSplashVisible = true;

  bool _showRemoteSplash = false;
  bool _remoteSplashVisible = false;

  // Controllers for default animated splash
  late final AnimationController _mainAnimController;
  late final AnimationController _pulseController;

  // Staggered animations
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoFadeAnimation;
  late final Animation<double> _logoRotationAnimation;

  // Title appear animations
  late final Animation<Offset> _titleSlideAnimation;
  late final Animation<double> _titleFadeAnimation;
  late final Animation<double> _titleScaleAnimation;

  // Remote banner ad controller
  late final AnimationController _remoteController;

  @override
  void initState() {
    super.initState();
    _hasRemoteSplash = BrandedSplash.hasSplash;

    // 1. Main entrance animation timeline
    _mainAnimController = AnimationController(
      vsync: this,
      duration: widget.minDisplay,
    );

    // 2. Continuous breathing / floating loop
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    // ── Logo: spring scale + subtle rotation + fade in ──
    _logoScaleAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.00, 0.48, curve: Curves.elasticOut),
      ),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.00, 0.25, curve: Curves.easeIn),
      ),
    );

    _logoRotationAnimation = Tween<double>(begin: -0.10, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.00, 0.42, curve: Curves.easeOutBack),
      ),
    );

    // ── Title: Appear animations (Slide up + Spring scale + Fade + Shimmer sweep) ──
    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.30, 0.68, curve: Curves.easeOutBack),
      ),
    );

    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.28, 0.55, curve: Curves.easeIn),
      ),
    );

    _titleScaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.30, 0.68, curve: Curves.easeOutBack),
      ),
    );

    // Remote banner ad controller (10s countdown)
    _remoteController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    // Start default animation on first frame and remove native splash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _mainAnimController.forward().then((_) {
        _onDefaultSplashFinished();
      });
    });
  }

  void _onDefaultSplashFinished() {
    if (!mounted || !_showDefaultSplash) return;
    _dismissDefaultSplash();
  }

  void _dismissDefaultSplash() {
    if (!mounted || !_defaultSplashVisible) return;
    setState(() {
      _defaultSplashVisible = false;
    });

    // After fade-out finishes (350ms):
    Future.delayed(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      setState(() {
        _showDefaultSplash = false;
      });

      if (_hasRemoteSplash) {
        setState(() {
          _showRemoteSplash = true;
          _remoteSplashVisible = true;
        });
        _remoteController.forward().then((_) {
          _dismissRemoteSplash();
        });
      }
    });
  }

  void _dismissRemoteSplash() {
    if (mounted && _remoteSplashVisible) {
      setState(() => _remoteSplashVisible = false);
      Future.delayed(const Duration(milliseconds: 360), () {
        if (mounted) {
          setState(() => _showRemoteSplash = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _mainAnimController.dispose();
    _pulseController.dispose();
    _remoteController.dispose();
    super.dispose();
  }


  String _getLocalizedTitle(BuildContext context, AppLanguage lang) {
    try {
      final translated = context.tr('splash.easy_connect_title');
      if (translated.isNotEmpty && translated != 'splash.easy_connect_title') {
        return translated;
      }
    } catch (_) {}
    switch (lang) {
      case AppLanguage.mm:
        return 'လွယ်ကူချိတ်ဆက် Super App';
      case AppLanguage.th:
        return 'เชื่อมต่อง่าย Super App';
      case AppLanguage.en:
        return 'Easy Connect Super App';
    }
  }

  Widget _buildDefaultAnimatedSplash() {
    final currentLang = LocaleController.instance.language;
    final isMm = currentLang == AppLanguage.mm;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Cool Style Animated White Background ──
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final t = _pulseController.value * 2 * math.pi;

            // Noticeable, graceful floating movement (35-45 pixels)
            final orb1X = math.cos(t) * 40.0;
            final orb1Y = math.sin(t) * 32.0;
            final orb2X = -math.sin(t) * 42.0;
            final orb2Y = -math.cos(t) * 36.0;
            final orb3X = math.sin(t * 1.5) * 30.0;
            final orb3Y = math.cos(t * 1.5) * 25.0;

            final rippleScaleInner = 0.90 + (math.sin(t) * 0.15);
            final rippleScaleMiddle = 1.00 + (math.cos(t) * 0.20);
            final rippleScaleOuter = 1.15 + (math.sin(t + 1.0) * 0.25);

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Base clean white canvas with subtle gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFFAFBFC),
                        Color(0xFFF1F5F9),
                      ],
                    ),
                  ),
                ),

                // 2. Animated floating rose aura (Top-Right) - clearly visible
                Positioned(
                  top: -60 + orb1Y,
                  right: -50 + orb1X,
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFED3973).withValues(alpha: 0.22),
                          const Color(0xFFED3973).withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. Animated floating warm amber/orange aura (Bottom-Left) - clearly visible
                Positioned(
                  bottom: -70 + orb2Y,
                  left: -60 + orb2X,
                  child: Container(
                    width: 370,
                    height: 370,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFF96232).withValues(alpha: 0.20),
                          const Color(0xFFF96232).withValues(alpha: 0.07),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),

                // 4. Subtle floating golden highlight (Center-Right)
                Positioned(
                  top: 220 + orb3Y,
                  right: -40 + orb3X,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFAE33).withValues(alpha: 0.16),
                          const Color(0xFFFFAE33).withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.60, 1.0],
                      ),
                    ),
                  ),
                ),

                // 5. Breathing center ripple rings behind the logo (Outer ring)
                Center(
                  child: Transform.scale(
                    scale: rippleScaleOuter,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFED3973).withValues(alpha: 0.10),
                            const Color(0xFFF96232).withValues(alpha: 0.03),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.50, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // 6. Breathing center ripple rings (Middle ring)
                Center(
                  child: Transform.scale(
                    scale: rippleScaleMiddle,
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFF96232).withValues(alpha: 0.16),
                            const Color(0xFFED3973).withValues(alpha: 0.06),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.60, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // 7. Breathing center ripple rings (Inner warm glow)
                Center(
                  child: Transform.scale(
                    scale: rippleScaleInner,
                    child: Container(
                      width: 135,
                      height: 135,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFED3973).withValues(alpha: 0.24),
                            const Color(0xFFF96232).withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // ── Main Content (Logo + Animated Localized Bold Gradient Text) ──
        SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo with animation (Scale + Elastic Bounce + Floating)
                ScaleTransition(
                  scale: _logoScaleAnimation,
                  child: RotationTransition(
                    turns: _logoRotationAnimation,
                    child: FadeTransition(
                      opacity: _logoFadeAnimation,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final floatY =
                              math.sin(_pulseController.value * 2 * math.pi) * 2.5;
                          return Transform.translate(
                            offset: Offset(0, floatY),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFED3973).withValues(alpha: 0.14),
                                blurRadius: 20,
                                spreadRadius: 1,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/images/logo_3d.png',
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Localized Text: Bold + Primary Gradient Color + Wave Animation
                SlideTransition(
                  position: _titleSlideAnimation,
                  child: ScaleTransition(
                    scale: _titleScaleAnimation,
                    child: FadeTransition(
                      opacity: _titleFadeAnimation,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final t = _pulseController.value * 2 * math.pi;
                          // Undulating wave floating motion
                          final waveY = math.sin(t + 1.2) * 2.5;
                          // Shifting wave progress for primary gradient shimmer wave
                          final waveProgress = _pulseController.value;

                          return Transform.translate(
                            offset: Offset(0, waveY),
                            child: ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  begin: Alignment(
                                    -1.4 + (waveProgress * 2.8),
                                    -0.2,
                                  ),
                                  end: Alignment(
                                    0.6 + (waveProgress * 2.8),
                                    0.2,
                                  ),
                                  colors: const [
                                    Color(0xFFED3973), // Primary Pink
                                    Color(0xFFF96232), // Secondary Orange
                                    Color(0xFFFFA258), // Wave highlight sheen
                                    Color(0xFFED3973), // Seamless loop back
                                  ],
                                  stops: const [0.0, 0.40, 0.70, 1.0],
                                  tileMode: TileMode.mirror,
                                ).createShader(bounds);
                              },
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _getLocalizedTitle(context, currentLang),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: AppFonts.poppins(
                            fontSize: isMm ? 15.0 : 14.0,
                            fontWeight: FontWeight.bold, // BOLD
                            color: Colors.white, // Inked by primary gradient ShaderMask
                            letterSpacing: isMm ? 0.2 : 0.4,
                            height: isMm ? 1.5 : 1.3,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteSplashImage() {
    final bytes = BrandedSplash.imageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    }

    final url = BrandedSplash.imageUrl!;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Duration.zero,
      placeholder: (_, _) => const ColoredBox(color: Colors.transparent),
      errorWidget: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _dismissRemoteSplash();
        });
        return const ColoredBox(color: Colors.transparent);
      },
    );
  }

  Widget _buildRemoteSplash() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.transparent,
          child: _buildRemoteSplashImage(),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // AD Label (Left)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'AD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),

              // Skip Button & Timer (Right)
              GestureDetector(
                onTap: _dismissRemoteSplash,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: AnimatedBuilder(
                          animation: _remoteController,
                          builder: (context, child) {
                            final seconds =
                                (10 - (_remoteController.value * 10)).ceil();
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: 1.0 - _remoteController.value,
                                  strokeWidth: 2.5,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                  backgroundColor: Colors.white24,
                                ),
                                Text(
                                  '$seconds',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The underlying app screen (Onboarding or Home) pre-warms beneath
        widget.child,

        // 1. Default Animated Splash Screen
        if (_showDefaultSplash)
          IgnorePointer(
            ignoring: !_defaultSplashVisible,
            child: AnimatedOpacity(
              opacity: _defaultSplashVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              child: _buildDefaultAnimatedSplash(),
            ),
          ),

        // 2. Remote Splash Banner AD (if available)
        if (_showRemoteSplash)
          IgnorePointer(
            ignoring: !_remoteSplashVisible,
            child: AnimatedOpacity(
              opacity: _remoteSplashVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              child: _buildRemoteSplash(),
            ),
          ),
      ],
    );
  }
}
