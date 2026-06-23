import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../localization/app_translations.dart';
import 'primary_gradient_button.dart';

class PermissionRationaleModal extends StatelessWidget {
  final bool locationOnly;

  const PermissionRationaleModal({super.key, this.locationOnly = false});

  static Future<void> show(
    BuildContext context, {
    bool locationOnly = false,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionRationaleModal(locationOnly: locationOnly),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleKey =
        locationOnly ? 'permission.title_location' : 'permission.title';
    final descKey =
        locationOnly ? 'permission.desc_location' : 'permission.desc';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/app_icon_small.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              context.tr(titleKey),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Description (uses basic markdown-like replacements for bold)
            RichText(
              text: _buildRichText(context, context.tr(descKey)),
            ),
            const SizedBox(height: 32),
            
            PrimaryGradientButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                context.tr('permission.continue'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _buildRichText(BuildContext context, String text) {
    // Simple parser to bold text between **
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        // Bold
        spans.add(TextSpan(
          text: parts[i],
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1.5,
          ),
        ));
      } else {
        // Normal
        spans.add(TextSpan(
          text: parts[i],
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Colors.black87,
            height: 1.5,
          ),
        ));
      }
    }
    return TextSpan(children: spans);
  }
}
