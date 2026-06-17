import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../data/onboarding_prefs.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
  }

  List<Map<String, dynamic>> _getOnboardingData() {
    return [
      {
        'title': LocaleController.instance.tr('onboarding.food_title'),
        'description': LocaleController.instance.tr('onboarding.food_desc'),
        'image': 'assets/images/onboarding_food.png',
        'offsetY': 0.0,
        'scale': 1.15,
      },
      {
        'title': LocaleController.instance.tr('onboarding.community_title'),
        'description': LocaleController.instance.tr('onboarding.community_desc'),
        'image': 'assets/images/onboarding_community.png',
        'offsetY': 3.0,
        'scale': 1.0,
      },
      {
        'title': LocaleController.instance.tr('onboarding.services_title'),
        'description': LocaleController.instance.tr('onboarding.services_desc'),
        'image': 'assets/images/onboarding_services.png',
        'offsetY': -7.0,
        'scale': 1.01,
      },
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                    LocaleController.instance.tr('language.title'),
                    style: const TextStyle(
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
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: LocaleController.instance.language == lang
                        ? Icon(Icons.check, color: Theme.of(context).primaryColor)
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

  void _completeOnboarding() async {
    await OnboardingPrefs.setHasSeenOnboarding(true);
    if (!mounted) return;
    
    if (AuthService().isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/auth_entry');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onboardingData = _getOnboardingData();

    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradientVertical,
        ),
        child: Stack(
          children: [
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
            SafeArea(
              child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                title: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/logo_3d.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                leadingWidth: 100,
                leading: TextButton.icon(
                  onPressed: () => _showLanguagePicker(context),
                  icon: const Icon(Icons.language, color: Colors.white, size: 18),
                  label: Text(
                    LocaleController.instance.language.name.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: onboardingData.length,
                  itemBuilder: (context, index) {
                    final item = onboardingData[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.translate(
                            offset: Offset(0, item['offsetY'] as double),
                            child: Transform.scale(
                              scale: item['scale'] as double? ?? 1.0,
                              child: SizedBox(
                                width: 280,
                                height: 280,
                                child: Image.asset(
                                  item['image'],
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            item['title'],
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            item['description'],
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(
                        onboardingData.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentPage == onboardingData.length - 1
                          ? ElevatedButton(
                              key: const ValueKey('start'),
                              onPressed: _completeOnboarding,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: theme.colorScheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                              ),
                              child: ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) => AppColors.primaryGradientVertical.createShader(
                                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                                ),
                                child: Text(
                                  LocaleController.instance.tr('onboarding.get_started'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              key: const ValueKey('next'),
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ],
        ),
      ),
    );
  }
}
