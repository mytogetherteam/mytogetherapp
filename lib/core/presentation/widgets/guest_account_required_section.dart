import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../auth/guest_auth_guard.dart';
import '../../localization/app_translations.dart';
import '../../theme/app_colors.dart';
import 'primary_gradient_button.dart';

/// Inline placeholder shown instead of authenticated home/food sections for
/// guests. Tapping the CTA opens the sign-in / register flow.
class GuestAccountRequiredSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double height;

  const GuestAccountRequiredSection({
    super.key,
    required this.title,
    this.subtitle,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.userCircle,
              size: 36,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PrimaryGradientButton(
                onPressed: () => GuestAuthGuard.requireAccount(context),
                child: Text(
                  context.tr('guest.create_or_login'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-tab body for guests on screens that require an account (e.g. News).
class GuestAccountRequiredPage extends StatelessWidget {
  final String? title;

  const GuestAccountRequiredPage({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: GuestAccountRequiredSection(
            title: title ?? context.tr('guest.need_account_title'),
            subtitle: context.tr('guest.need_account_message'),
            height: 220,
          ),
        ),
      ),
    );
  }
}

/// Compact banner for detail pages where guests can browse but some actions
/// need an account.
class GuestAuthBanner extends StatelessWidget {
  const GuestAuthBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => GuestAuthGuard.requireAccount(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.userCircle,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('guest.sign_in_prompt'),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  PhosphorIcons.caretRight,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
