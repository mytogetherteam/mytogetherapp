import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'image_skeleton_loader.dart';
import 'shop_item_metadata_row.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';

class RestaurantCard extends StatelessWidget {
  final String name;
  final String category;
  final double rating;
  final int reviewCount;
  final String distance; // the formatted distance
  final String? deliveryTime;
  final String? deliveryFee;
  final String? originalDeliveryFee;
  final String imagePath;
  final String? logoPath;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  /// When true (default) a "saved/removed" toast is shown automatically on
  /// favorite tap. Set false when the parent already shows its own toast.
  final bool showFavoriteToast;
  final VoidCallback? onTap;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const RestaurantCard({
    super.key,
    required this.name,
    required this.category,
    required this.rating,
    this.reviewCount = 0,
    required this.distance,
    this.deliveryTime,
    this.deliveryFee,
    this.originalDeliveryFee,
    required this.imagePath,
    this.logoPath,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.showFavoriteToast = true,
    this.onTap,
    this.width,
    this.margin,
  });

  /// Resolves an image path (asset path, absolute URL, or server-relative
  /// path) to a usable URL, or returns null when there is nothing to show.
  String? _resolveNetworkUrl(String? path) {
    if (path == null) return null;
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed.startsWith('assets/')) return null;
    if (trimmed.startsWith('http')) return trimmed;
    return '${ApiClient.baseUrl}/${trimmed.startsWith('/') ? trimmed.substring(1) : trimmed}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isAsset = imagePath.startsWith('assets/');
    final bool isNetworkImage = !isAsset && imagePath.trim().isNotEmpty;
    
    String networkUrl = imagePath;
    if (isNetworkImage && !networkUrl.startsWith('http')) {
      networkUrl = '${ApiClient.baseUrl}/${networkUrl.startsWith('/') ? networkUrl.substring(1) : networkUrl}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? 240,
        margin: margin ?? const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with Favorite Button
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: (!isNetworkImage && !isAsset)
                    ? _buildFallbackImage(context)
                    : (isAsset
                        ? Image.asset(
                            imagePath,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildFallbackImage(context),
                          )
                        : CachedNetworkImage(
                            imageUrl: networkUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const ImageSkeletonLoader(
                              height: 160,
                            ),
                            errorWidget: (context, url, error) => _buildFallbackImage(context),
                            fadeInDuration: Duration.zero, 
                            fadeOutDuration: Duration.zero,
                          )),
              ),

              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: onFavoriteToggle != null
                      ? () {
                          final willBeSaved = !isFavorite;
                          onFavoriteToggle!.call();
                          if (showFavoriteToast) {
                            AppDialog.showToast(
                              context,
                              context.tr(
                                willBeSaved
                                    ? 'wishlist.saved'
                                    : 'wishlist.removed',
                              ),
                            );
                          }
                        }
                      : () => AppDialog.showUnavailable(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? PhosphorIcons.heartFill : PhosphorIcons.heart,
                      color: isFavorite ? AppColors.primary : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: _buildLogoBadge(context),
              ),
            ],
          ),
          // Text Info Section with Padding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Restaurant Name
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Metadata Row
                Transform.translate(
                  offset: const Offset(-1.5, 0),
                  child: ShopItemMetadataRow(
                    rating: rating > 0 ? rating : null,
                    reviewCount: reviewCount,
                    // Since distance is a string here ('5.0 km'), we will just parse it
                    distanceKm: double.tryParse(distance.replaceAll(RegExp(r'[^0-9.]'), '')),
                    deliveryTime: deliveryTime,
                    deliveryFee: deliveryFee,
                    originalDeliveryFee: originalDeliveryFee,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  /// Circular brand/profile badge shown over the cover image so the user can
  /// recognise the restaurant even when the cover photo is generic.
  Widget _buildLogoBadge(BuildContext context) {
    const double size = 48;
    final logoUrl = _resolveNetworkUrl(logoPath);
    final coverUrl = _resolveNetworkUrl(imagePath);
    final primaryUrl = logoUrl ?? coverUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: primaryUrl == null
            ? _buildLogoFallback()
            : CachedNetworkImage(
                imageUrl: primaryUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildLogoPlaceholder(),
                errorWidget: (context, url, error) {
                  // If the logo failed, try the cover before the letter avatar.
                  if (logoUrl != null &&
                      coverUrl != null &&
                      coverUrl != logoUrl) {
                    return CachedNetworkImage(
                      imageUrl: coverUrl,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildLogoPlaceholder(),
                      errorWidget: (context, url, error) =>
                          _buildLogoFallback(),
                      fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                      memCacheWidth: 200,
                    );
                  }
                  return _buildLogoFallback();
                },
                fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                memCacheWidth: 200,
              ),
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(color: Colors.grey.shade200);
  }

  Widget _buildLogoFallback() {
    final String initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildFallbackImage(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 32),
            const SizedBox(height: 4),
            Text(
              context.tr('common.no_image'),
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



