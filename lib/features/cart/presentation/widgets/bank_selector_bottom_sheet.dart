import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';

class BankSelectorBottomSheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Header & Tutorial
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: ShaderMask(
                          shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                          blendMode: BlendMode.srcIn,
                          child: const Icon(
                            Icons.check_circle,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'QR Saved Successfully!',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Professional Stepper UI
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            _buildTutorialStep(
                              step: '1',
                              icon: Icons.account_balance_outlined,
                              text: 'Open your banking app',
                            ),
                            _buildStepDivider(),
                            _buildTutorialStep(
                              step: '2',
                              icon: Icons.qr_code_scanner,
                              text: 'Tap "Scan" inside the app',
                            ),
                            _buildStepDivider(),
                            _buildTutorialStep(
                              step: '3',
                              icon: Icons.image_outlined,
                              text: 'Select the QR image from gallery',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                Divider(color: Colors.grey[200], height: 1),
                
                // Bank List (Scrollable if needed)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBankTile(
                          context,
                          name: 'K PLUS',
                          urlScheme: 'kplus://',
                          iconColor: const Color(0xFF00A950),
                          iconText: 'K',
                        ),
                        Divider(color: Colors.grey[200], height: 1, indent: 24, endIndent: 24),
                        
                        _buildBankTile(
                          context,
                          name: 'SCB EASY',
                          urlScheme: 'scbeasy://',
                          iconColor: const Color(0xFF4E2A84),
                          iconText: 'S',
                        ),
                        Divider(color: Colors.grey[200], height: 1, indent: 24, endIndent: 24),
                        
                        _buildBankTile(
                          context,
                          name: 'Krungthai NEXT',
                          urlScheme: 'ktbnext://',
                          iconColor: const Color(0xFF1BA6E5),
                          iconText: 'K',
                        ),
                        Divider(color: Colors.grey[200], height: 1, indent: 24, endIndent: 24),

                        _buildBankTile(
                          context,
                          name: 'Bualuang mBanking',
                          urlScheme: 'bualuangm://',
                          iconColor: const Color(0xFF1E4598),
                          iconText: 'B',
                        ),
                        Divider(color: Colors.grey[200], height: 1, indent: 24, endIndent: 24),

                        _buildBankTile(
                          context,
                          name: 'KMA (Krungsri)',
                          urlScheme: 'kma://',
                          iconColor: const Color(0xFFFDB913),
                          iconText: 'K',
                        ),
                        Divider(color: Colors.grey[200], height: 1, indent: 24, endIndent: 24),

                        _buildBankTile(
                          context,
                          name: 'ttb touch',
                          urlScheme: 'ttbtouch://',
                          iconColor: const Color(0xFF005087),
                          iconText: 't',
                        ),
                        Divider(color: Colors.grey[200], height: 1, indent: 24, endIndent: 24),

                        _buildBankTile(
                          context,
                          name: 'MyMo by GSB',
                          urlScheme: 'mymo://',
                          iconColor: const Color(0xFFEB008B),
                          iconText: 'M',
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'I will open it myself',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildBankTile(
    BuildContext context, {
    required String name,
    required String urlScheme,
    required Color iconColor,
    required String iconText,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            iconText,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ),
      ),
      title: Text(
        'Open $name',
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () async {
        try {
          final launched = await launchUrlString(
            urlScheme,
            mode: LaunchMode.externalApplication,
          );
          if (!launched && context.mounted) {
            AppDialog.showToast(context, 'Could not open $name', isError: true);
          }
        } catch (e) {
          if (context.mounted) {
            AppDialog.showToast(context, 'Could not open $name', isError: true);
          }
        }
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  static Widget _buildTutorialStep({
    required String step,
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildStepDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 13, top: 4, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 2,
          height: 16,
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
