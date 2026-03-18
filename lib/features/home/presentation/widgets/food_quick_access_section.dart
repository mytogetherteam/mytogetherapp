import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
                  title: 'Nearby Shops',
                  subtitle: 'Get it quick',
                  color: const Color(0xFFFDE6ED), // Soft pink
                  iconAsset: 'assets/images/services/places.png', // Temporary placeholder
                  emoji: '📍',
                  onTap: onNearbyTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickCard(
                  title: 'For You',
                  subtitle: 'Handpicked for you',
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
                  title: 'Trending',
                  subtitle: 'Hot right now',
                  color: const Color(0xFFD1FAE5), // Mint green
                  emoji: '🔥',
                  onTap: onTrendingTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickCard(
                  title: 'Popular',
                  subtitle: 'Fan favorites',
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
                  ? Image.asset(iconAsset, width: 36, height: 36)
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
