import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';


class CategoryCard extends StatelessWidget {
  final String title;
  final String assetPath;
  final String? badgeText;
  final bool isAnimatedBadge;
  final bool isComingSoon;
  final VoidCallback? onTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.assetPath,
    this.badgeText,
    this.isAnimatedBadge = false,
    this.isComingSoon = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isComingSoon
            ? null
            : LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.secondary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isComingSoon ? Colors.grey[100] : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Opacity(
        opacity: isComingSoon ? 0.5 : 1.0,
        child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isComingSoon ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon Section
                    Center(
                      child: Image.asset(
                        assetPath,
                        width: 60, // Slightly reduced to prevent overflow
                        height: 60,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.apps, size: 40, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title Section
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (badgeText != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: isAnimatedBadge
                      ? _PulsingBadge(text: badgeText!)
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            badgeText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
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

class _PulsingBadge extends StatefulWidget {
  final String text;
  const _PulsingBadge({required this.text});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          widget.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
