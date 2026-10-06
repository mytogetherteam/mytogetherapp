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
  final String? primaryActivity;
  final String? startingPrice;
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
    this.primaryActivity,
    this.startingPrice,
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

            // Activity Badge
            if (primaryActivity != null && primaryActivity!.isNotEmpty)
              Positioned(
                top: 16,
                left: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _activityIcon(primaryActivity!),
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatActivity(primaryActivity!),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
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
                        if (startingPrice != null && startingPrice!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                PhosphorIcons.tag,
                                size: 11,
                                color: Color(0xFFFFE082),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                startingPrice!,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFFE082),
                                ),
                              ),
                            ],
                          ),
                        ],
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
  static String _activityIcon(String key) {
    switch (key.toUpperCase()) {
      case "BADMINTON": return "🏸";
      case "SWIMMING": return "🏊";
      case "FOOTBALL": return "⚽";
      case "FUTSAL": return "🥅";
      case "GYM": return "🏋️";
      case "MUAY_THAI": return "🥊";
      case "TENNIS": return "🎾";
      case "ICE_SKATING": return "🧊";
      case "GAMES": return "🎳";
      case "ROOFTOP_VIEW": return "🏙️";
      case "SHOPPING": return "🛍️";
      case "NIGHT_MARKET": return "🏮";
      case "PARK": return "🌳";
      case "KARAOKE": return "🎤";
      case "BOWLING": return "🎳";
      case "CINEMA": return "🎬";
      default: return "📍";
    }
  }

  static String _formatActivity(String key) {
    return key
        .replaceAll("_", " ")
        .split(" ")
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : "")
        .join(" ");
  }
}
