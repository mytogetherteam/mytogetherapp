import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/features/auth/data/repositories/auth_repository.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/login_page.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/delete_account_page.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/edit_profile_page.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/help_support_page.dart';
import 'package:mytogetherapp/features/wishlist/presentation/screens/wishlist_page.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_icon.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiClient.baseUrl}/$path';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Background
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, Color(0xFFF96232)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
              user?.fullName ?? user?.username ?? 'User Name',
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
              icon: PhosphorIcons.userCircle,
              title: 'Edit Profile',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                );
                if (mounted) setState(() {});
              },
            ),
            _buildOptionTile(
              icon: PhosphorIcons.heart,
              title: 'Saved Items',
              subtitle: 'Your wishlist of foods and shops',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WishlistPage()),
              ),
            ),
            _buildOptionTile(
              icon: PhosphorIcons.mapPin,
              title: 'My Addresses',
              onTap: () => AppDialog.showUnavailable(context),
            ),
            _buildOptionTile(
              icon: PhosphorIcons.bell,
              title: 'Notifications',
              onTap: () => AppDialog.showUnavailable(context),
            ),
            _buildOptionTile(
              icon: PhosphorIcons.shieldCheck,
              title: 'Security',
              onTap: () => AppDialog.showUnavailable(context),
            ),
            _buildOptionTile(
              icon: PhosphorIcons.question,
              title: 'Help Center',
              subtitle: 'အကူအညီနှင့် ဆက်သွယ်ရန်',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportPage()),
              ),
            ),
            
            const SizedBox(height: 8),
            // Delete Account tile (danger)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeleteAccountPage()),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: ListTile(
                    leading: Icon(
                      PhosphorIcons.trashFill,
                      color: Colors.red.shade500,
                      size: 22,
                    ),
                    title: Text(
                      'Delete Account',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade600,
                      ),
                    ),
                    subtitle: Text(
                      'အကောင့်ဖျက်ရန်',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red.shade400,
                      ),
                    ),
                    trailing: Icon(
                      PhosphorIcons.caretRight,
                      size: 18,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ),
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
                      'Logout',
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
            const SizedBox(height: 40),
          ],
        ),
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
      title: 'Logout',
      content: 'Are you sure you want to log out?',
      buttonText: 'Logout',
      secondaryButtonText: 'Cancel',
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
}
