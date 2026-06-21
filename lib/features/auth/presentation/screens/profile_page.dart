import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/features/auth/data/repositories/auth_repository.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/login_page.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/account_settings_page.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/help_support_page.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/language_page.dart';
import 'package:mytogetherapp/features/settings/presentation/screens/app_permissions_page.dart';
import 'package:mytogetherapp/features/wishlist/presentation/screens/wishlist_page.dart';
import 'package:mytogetherapp/features/home/presentation/screens/location_search_page.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_icon.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/presentation/widgets/notification_bell.dart';
import 'package:mytogetherapp/features/home/data/repositories/restaurant_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _appVersion = '';
  String? _bgImageUrl;

  late ScrollController _scrollController;
  double _headerOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _initAppVersion();
    _fetchBackgroundTheme();
  }

  void _onScroll() {
    final double offset = _scrollController.offset;
    final double newOpacity = (offset / 80).clamp(0.0, 1.0);
    if (newOpacity != _headerOpacity) {
      setState(() {
        _headerOpacity = newOpacity;
      });
    }
  }

  Future<void> _initAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  Future<void> _fetchBackgroundTheme() async {
    try {
      final bgThemeData = await RestaurantRepository.instance.getBackgroundTheme();
      if (mounted && bgThemeData != null) {
        setState(() {
          _bgImageUrl = bgThemeData['url'];
        });
      }
    } catch (_) {}
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiClient.baseUrl}/$path';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                // Header with Background
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    ClipRect(
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          image: (_bgImageUrl != null && _bgImageUrl!.isNotEmpty)
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(_bgImageUrl!),
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                )
                              : const DecorationImage(
                                  image: AssetImage('assets/images/top-bannner.jpg'),
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -50,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: user?.avatarUrl != null
                              ? CachedNetworkImageProvider(_getImageUrl(user!.avatarUrl))
                              : null,
                          child: user?.avatarUrl == null
                              ? Icon(PhosphorIcons.userBold,
                                  size: 40, color: Colors.grey[400])
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                
                // User Info
                Text(
              user?.fullName ?? user?.username ?? context.tr('common.user_name'),
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              user?.email ?? 'email@example.com',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),

            // Profile Options
            _buildOptionTile(
              icon: PhosphorIcons.gearSix,
              title: context.tr('profile.account_settings'),
              subtitle: context.tr('profile.account_settings_sub'),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
                );
                if (mounted) setState(() {});
              },
            ),
            _buildOptionTile(
              icon: PhosphorIcons.heart,
              title: context.tr('profile.saved_items'),
              subtitle: context.tr('profile.saved_items_sub'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WishlistPage()),
              ),
            ),
            _buildOptionTile(
              icon: PhosphorIcons.mapPin,
              title: context.tr('profile.my_addresses'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocationSearchPage()),
              ),
            ),
            _buildOptionTile(
              icon: PhosphorIcons.bellRinging,
              title: context.tr('profile.app_permissions'),
              subtitle: context.tr('profile.app_permissions_sub'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppPermissionsPage()),
              ),
            ),
            _buildOptionTile(
              icon: PhosphorIcons.translate,
              title: context.tr('profile.language'),
              subtitle: LocaleController.instance.language.nativeName,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LanguagePage()),
                );
                if (mounted) setState(() {});
              },
            ),
            _buildOptionTile(
              icon: PhosphorIcons.question,
              title: context.tr('profile.help_center'),
              subtitle: context.tr('profile.help_center_sub'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportPage()),
              ),
            ),
            _buildOptionTile(
              icon: PhosphorIcons.shieldCheck,
              title: context.tr('profile.privacy_policy'),
              onTap: () => _launchUrl('https://www.mytogether.org/privacy-policy/user'),
            ),
            
            const SizedBox(height: 20),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: GestureDetector(
                onTap: () => _handleLogout(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Center(
                    child: Text(
                      context.tr('profile.logout'),
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_appVersion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Text(
                  '${context.tr('profile.app_version')} $_appVersion',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              )
            else
              const SizedBox(height: 40),
          ],
        ),
      ),
      // Fixed Nav Header
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _headerOpacity),
            boxShadow: _headerOpacity > 0.8
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/app_icon_small.png',
                        height: 28,
                      ),
                      const SizedBox(width: 12),
                      Transform.translate(
                        offset: const Offset(0, 4),
                        child: Text(
                          context.tr('nav.profile'),
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: LocaleController.instance.language.code == 'mm' ? 18 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const NotificationBell(),
                ],
              ),
              // Center small profile picture
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _headerOpacity > 0.8 ? 1.0 : 0.0,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: user?.avatarUrl != null
                      ? CachedNetworkImageProvider(_getImageUrl(user!.avatarUrl))
                      : null,
                  child: user?.avatarUrl == null
                      ? Icon(PhosphorIcons.userBold,
                          size: 18, color: Colors.grey[400])
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          onTap: onTap,
          leading: GradientIcon(icon: icon),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                )
              : null,
          trailing: Icon(PhosphorIcons.caretRight, size: 18, color: Colors.grey),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    AppDialog.show(
      context: context,
      title: context.tr('profile.logout'),
      content: context.tr('profile.logout_confirm'),
      buttonText: context.tr('profile.logout'),
      secondaryButtonText: context.tr('common.cancel'),
      onButtonPressed: () async {
        Navigator.pop(context); // Close dialog
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CustomLoadingIndicator(size: 40)),
        );
        
        await AuthRepository.instance.logout();
        
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      },
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('common.link_open_failed'),
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade500,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}
