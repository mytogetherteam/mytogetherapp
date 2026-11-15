import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
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
                child: CachedNetworkImage(
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  imageUrl: imagePath,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const ImageSkeletonLoader(height: 320, width: 240),
                  errorWidget: (context, url, error) => Container(
                    width: 240,
                    height: 320,
                    color: Colors.grey[200],
                    child: const Icon(PhosphorIcons.image, color: Colors.grey),
                  ),
                ),
              ),
            ),

            // Activity Badge
            if (primaryActivity != null && primaryActivity!.isNotEmpty)
              Positioned(
                top: 14,
                left: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
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
                            style: AppFonts.poppins(
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
              top: 14,
              right: 14,
              child: _buildFavoriteButton(context),
            ),

            // Bottom Info Overlay
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: AppFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.25,
                            shadows: const [
                              Shadow(
                                color: Colors.black45,
                                offset: Offset(0, 1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              PhosphorIcons.mapPinFill,
                              size: 12,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _cleanLocation(category),
                                style: AppFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (distance.isNotEmpty ||
                            (startingPrice != null &&
                                startingPrice!.isNotEmpty)) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (distance.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        PhosphorIcons.carFill,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        distance,
                                        style: AppFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (distance.isNotEmpty &&
                                  startingPrice != null &&
                                  startingPrice!.isNotEmpty)
                                const SizedBox(width: 6),
                              if (startingPrice != null &&
                                  startingPrice!.isNotEmpty)
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7)
                                          .withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.4),
                                        width: 0.7,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          PhosphorIcons.tagFill,
                                          size: 10,
                                          color: Color(0xFFFFE082),
                                        ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            startingPrice!,
                                            style: AppFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFFFE082),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
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

  static String _cleanLocation(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final parts = trimmed
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.length <= 1) {
      return trimmed;
    }

    // Strip postal codes (5 digits) from each part
    final withoutZip = parts
        .map((p) => p.replaceAll(RegExp(r'\s*\b\d{5}\b'), '').trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // Filter out parts that are mostly numbers (house/soi numbers like '734, 736', '88', '13/3', '222', etc.)
    final meaningful = withoutZip.where((p) {
      final lettersOnly = p.replaceAll(RegExp(r'[\d\s\-\/#,.]'), '');
      return lettersOnly.length >= 2;
    }).toList();

    if (meaningful.isEmpty) {
      return withoutZip.isNotEmpty ? withoutZip.last : trimmed;
    }

    // In Thai addresses: [Road/Soi, Subdistrict, District, Province/City]
    if (meaningful.length >= 2) {
      final city = meaningful.last;
      final area = meaningful[meaningful.length - 2];
      final isRoad =
          RegExp(r'\b(Rd|Road|Soi|Thanon)\b', caseSensitive: false).hasMatch(area);
      if (!isRoad) {
        return '$area, $city';
      } else if (meaningful.length >= 3) {
        final deeperArea = meaningful[meaningful.length - 3];
        return '$deeperArea, $city';
      }
      return '$area, $city';
    }

    return meaningful.first;
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
      case "SIGHTSEEING": return "🗺️";
      case "CAFE": return "☕";
      case "RESTAURANT": return "🍽️";
      case "BEACH": return "🏖️";
      case "TEMPLE": return "🛕";
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
