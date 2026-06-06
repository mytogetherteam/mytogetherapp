import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';

class FoodQuickAccessSection extends StatelessWidget {
  final VoidCallback onNearbyTap;
  final VoidCallback onForYouTap;
  final VoidCallback onTrendingTap;
  final VoidCallback onPopularTap;

  const FoodQuickAccessSection({
    super.key,
    required this.onNearbyTap,
    required this.onForYouTap,
    required this.onTrendingTap,
    required this.onPopularTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQuickCard(
                  title: context.tr('food.nearby_shops'),
                  subtitle: context.tr('food.nearby_shops_sub'),
                  color: const Color(0xFFFDE6ED), // Soft pink
                  emoji: '📍',
                  onTap: onNearbyTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickCard(
                  title: context.tr('food.for_you'),
                  subtitle: context.tr('food.for_you_sub'),
                  color: const Color(0xFFFEF3C7), // Peach / Warm Yellow
                  emoji: '✨',
                  onTap: onForYouTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickCard(
                  title: context.tr('food.trending'),
                  subtitle: context.tr('food.trending_sub'),
                  color: const Color(0xFFD1FAE5), // Mint green
                  emoji: '🔥',
                  onTap: onTrendingTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickCard(
                  title: context.tr('food.popular'),
                  subtitle: context.tr('food.popular_sub'),
                  color: const Color(0xFFDBEAFE), // Light blue
                  emoji: '👑',
                  onTap: onPopularTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required String emoji,
    String? iconAsset,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 85,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.black54,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: iconAsset != null
                  ? Image.asset(
                      iconAsset,
                      width: 36,
                      height: 36,
                      errorBuilder: (context, error, stackTrace) => Text(
                        emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                    )
                  : Text(
                      emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
