import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

class MenuImagePlaceholder extends StatelessWidget {
  final String title;

  const MenuImagePlaceholder({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    // Determine initials
    final String initial = title.trim().isNotEmpty 
        ? title.trim().substring(0, 1).toUpperCase() 
        : 'M';

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Stack(
        children: [
          // Logo Overlay Design
          Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scale(3.0)
                ..rotateZ(0.3),
              child: Image.asset(
                'assets/images/logo_white.png',
                width: 100,
                height: 100,
              ),
            ),
          ),
          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
