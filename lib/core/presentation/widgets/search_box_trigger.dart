import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../theme/app_colors.dart';

class SearchBoxTrigger extends StatelessWidget {
  final String hintText;
  final VoidCallback onTap;
  final double height;
  final double borderRadius;
  final Color backgroundColor;
  final Color contentColor;
  final double shadowAlpha;
  final bool isGlassStyle;

  const SearchBoxTrigger({
    super.key,
    required this.hintText,
    required this.onTap,
    this.height = 48,
    this.borderRadius = 24,
    this.backgroundColor = Colors.white,
    this.contentColor = const Color(0xFF9E9E9E), // Colors.grey.shade500
    this.shadowAlpha = 0.05,
    this.isGlassStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Row(
      children: [
        Icon(
          PhosphorIcons.magnifyingGlass,
          color: isGlassStyle ? Colors.white : contentColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            hintText,
            style: GoogleFonts.poppins(
              color: isGlassStyle ? Colors.white : contentColor,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (isGlassStyle) {
      content = Opacity(
        opacity: 0.65,
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
          child: content,
        ),
      );
    }

    Widget container = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isGlassStyle ? Colors.white.withValues(alpha: 0.2) : backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isGlassStyle ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowAlpha),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isGlassStyle ? Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1.5) : null,
      ),
      child: content,
    );

    if (isGlassStyle) {
      container = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: container,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: container,
    );
  }
}
