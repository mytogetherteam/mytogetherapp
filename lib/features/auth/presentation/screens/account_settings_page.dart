import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_icon.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/delete_account_page.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/edit_profile_page.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('profile.account_settings'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _buildOptionTile(
            context,
            icon: PhosphorIcons.userCircle,
            title: context.tr('profile.edit_profile'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfilePage()),
            ),
          ),
          _buildOptionTile(
            context,
            icon: PhosphorIcons.shieldCheck,
            title: context.tr('profile.security'),
            onTap: () => AppDialog.showUnavailable(context),
          ),
          const SizedBox(height: 8),
          _buildDeleteAccountTile(context),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
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
          trailing:
              Icon(PhosphorIcons.caretRight, size: 18, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountTile(BuildContext context) {
    return Padding(
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
              context.tr('profile.delete_account'),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
            subtitle: Text(
              context.tr('profile.delete_account_sub'),
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
    );
  }
}
