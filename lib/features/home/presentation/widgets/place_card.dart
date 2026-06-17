import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'image_skeleton_loader.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';

class PlaceCard extends StatelessWidget {
  final String name;
  final String category;
  final String distance;
  final String imagePath;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onTap;

  const PlaceCard({
    super.key,
    required this.name,
    required this.category,
    required this.distance,
    required this.imagePath,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Hero(
                tag: 'top_places_$name',
                child: CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                  imageUrl: imagePath,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const ImageSkeletonLoader(height: 320, width: 240),
                  errorWidget: (context, url, error) => Container(
                    width: 240,
                    height: 320,
                    color: Colors.grey[200],
                    child: Icon(PhosphorIcons.image, color: Colors.grey),
                  ),
                ),
              ),
            ),

            // Favorite Button
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: onFavoriteToggle ??
                    () => AppDialog.showUnavailable(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavorite
                        ? PhosphorIcons.heartFill
                        : PhosphorIcons.heart,
                    color: isFavorite ? AppColors.primary : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // Bottom Info Overlay
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                category,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                              ),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            Icon(
                              PhosphorIcons.car,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distance,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

