import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/auth_entry_page.dart';

/// Compact promo strip shown above the bottom tab bar for guest users.
class GuestWelcomeBanner extends StatelessWidget {
  final VoidCallback? onAuthFlowComplete;

  const GuestWelcomeBanner({super.key, this.onAuthFlowComplete});

  Future<void> _openAuth(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthEntryPage()),
    );
    onAuthFlowComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService().isLoggedIn) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1C1C1E),
                AppColors.primary.withValues(alpha: 0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/logo_3d.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                      children: [
                        TextSpan(
                          text: context.tr('guest.welcome_banner_lead'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(text: context.tr('guest.welcome_banner_body')),
                        TextSpan(
                          text: context.tr('guest.welcome_banner_highlight'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                        TextSpan(text: context.tr('guest.welcome_banner_tail')),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => _openAuth(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    context.tr('guest.welcome_banner_cta'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
