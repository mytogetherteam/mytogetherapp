import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class SearchBoxTrigger extends StatelessWidget {
  final String hintText;
  final VoidCallback onTap;
  final double height;
  final double borderRadius;
  final Color backgroundColor;
  final Color contentColor;
  final double shadowAlpha;

  const SearchBoxTrigger({
    super.key,
    required this.hintText,
    required this.onTap,
    this.height = 48,
    this.borderRadius = 24,
    this.backgroundColor = Colors.white,
    this.contentColor = const Color(0xFF9E9E9E), // Colors.grey.shade500
    this.shadowAlpha = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowAlpha),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.magnifyingGlass,
              color: contentColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hintText,
                style: GoogleFonts.poppins(
                  color: contentColor,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
