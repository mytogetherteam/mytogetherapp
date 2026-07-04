import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'image_skeleton_loader.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/auth/guest_auth_guard.dart';
import '../../../wishlist/data/repositories/wishlist_repository.dart';
import '../../../wishlist/presentation/wishlist_favorite_action.dart';

class PlaceCard extends StatelessWidget {
  final String name;
  final String category;
  final String distance;
  final String imagePath;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onTap;
  /// Place id used to keep the heart in sync with the shared wishlist across
  /// screens. When present (and [selfManageFavorite] is true), the card toggles
  /// the wishlist itself.
  final int? placeId;
  /// When true (default) and [placeId] is present, the heart manages itself
  /// against the shared wishlist. Set false for the legacy parent-driven
  /// behaviour (used by the wishlist screen).
  final bool selfManageFavorite;

  const PlaceCard({
    super.key,
    required this.name,
    required this.category,
    required this.distance,
    required this.imagePath,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.onTap,
    this.placeId,
    this.selfManageFavorite = true,
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
              child: _buildFavoriteButton(context),
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
                            if (distance.isNotEmpty) ...[
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

  /// Builds the favorite heart. When self-managing with a valid place id, the
  /// heart reflects the shared wishlist reactively and toggles through it, so
  /// the saved state stays in sync across every screen.
  Widget _buildFavoriteButton(BuildContext context) {
    final int id = placeId ?? 0;
    final bool selfManaged =
        selfManageFavorite && id > 0 && onFavoriteToggle != null;

    if (selfManaged) {
      return ListenableBuilder(
        listenable: WishlistRepository.instance,
        builder: (context, _) {
          final saved = WishlistFavoriteAction.isSaved(
            WishlistKind.place,
            id,
            isFavorite,
          );
          return _favoriteIcon(
            saved: saved,
            onTap: () => WishlistFavoriteAction.toggle(
              context,
              WishlistKind.place,
              id,
              currentlySaved: saved,
            ),
          );
        },
      );
    }

    return _favoriteIcon(
      saved: isFavorite,
      onTap: () async {
        if (onFavoriteToggle == null) {
          AppDialog.showUnavailable(context);
          return;
        }
        if (!await GuestAuthGuard.requireAccount(context)) return;
        onFavoriteToggle!();
      },
    );
  }

  Widget _favoriteIcon({required bool saved, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          saved ? PhosphorIcons.heartFill : PhosphorIcons.heart,
          color: saved ? AppColors.primary : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

