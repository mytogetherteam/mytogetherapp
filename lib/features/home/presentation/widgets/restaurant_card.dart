import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'image_skeleton_loader.dart';
import 'shop_item_metadata_row.dart';
import 'order_unavailability_ui.dart';
import 'my_together_verified_badge.dart';
import '../../data/models/shop_dto.dart' show OperatingHourDto;
import '../../data/restaurant_order_availability.dart';
import '../../data/shop_order_state_cache.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import '../../../wishlist/data/repositories/wishlist_repository.dart';
import '../../../wishlist/presentation/wishlist_favorite_action.dart';

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
  /// When true (default) and a valid [shopId] is present, the heart manages
  /// itself against the shared wishlist (instant, cross-page in sync) and the
  /// [onFavoriteToggle] callback is treated as a no-op gate. Set false to keep
  /// the legacy parent-driven behaviour (used by the wishlist screen).
  final bool selfManageFavorite;
  final VoidCallback? onTap;
  final double? width;
  final EdgeInsetsGeometry? margin;
  final bool deliveryEnabled;
  final List<OperatingHourDto> operatingHours;
  final String status;
  final String? shopId;
  final bool isVerified;
  /// Horizontal carousel cards use a fixed height — keep copy on the image
  /// badge only to avoid overflow.
  final bool compact;

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
    this.selfManageFavorite = true,
    this.onTap,
    this.width,
    this.margin,
    this.deliveryEnabled = true,
    this.operatingHours = const [],
    this.status = 'Open',
    this.shopId,
    this.isVerified = false,
    this.compact = false,
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
    ShopOrderStateCache.instance.ensureListening();

    return ListenableBuilder(
      listenable: ShopOrderStateCache.instance,
      builder: (context, _) {
        final parsedShopId = int.tryParse(shopId ?? '') ?? 0;
        final availability = parsedShopId > 0
            ? ShopOrderStateCache.instance.availabilityForShopIdOrDefault(
                parsedShopId,
                deliveryEnabled: deliveryEnabled,
                operatingHours: operatingHours,
                status: status,
              )
            : RestaurantOrderAvailability.fromParts(
                deliveryEnabled: deliveryEnabled,
                operatingHours: operatingHours,
                status: status,
              );
        return _buildCard(context, availability);
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    RestaurantOrderAvailability availability,
  ) {
    final blockedLine = availability.cardStatusLine(context);
    final isBlocked = availability.isBlocked;
    final shouldDimImage = availability.shouldDimImage;
    final showStatusLine = isBlocked && !compact && blockedLine.isNotEmpty;
    const imageHeight = 160.0;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image with Favorite Button
          Stack(
            children: [
              UnavailableImageDim(
                active: shouldDimImage,
                borderRadius: BorderRadius.circular(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: (!isNetworkImage && !isAsset)
                      ? _buildFallbackImage(context, imageHeight)
                      : (isAsset
                          ? Image.asset(
                              imagePath,
                              height: imageHeight,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackImage(context, imageHeight),
                            )
                          : CachedNetworkImage(
                              imageUrl: networkUrl,
                              height: imageHeight,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              memCacheWidth: 600,
                              placeholder: (context, url) => ImageSkeletonLoader(
                                height: imageHeight,
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildFallbackImage(context, imageHeight),
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                            )),
                ),
              ),
              if (isBlocked)
                Positioned(
                  top: 12,
                  left: 12,
                  child: OrderStatusImageBadge(reason: availability.reason),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: _buildFavoriteButton(context),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Opacity(
                  opacity: shouldDimImage ? 0.55 : 1,
                  child: _buildLogoBadge(context),
                ),
              ),
            ],
          ),
          // Text Info Section with Padding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: compact ? 8 : 12),
                VerifiedRestaurantNameRow(
                  name: name,
                  isVerified: isVerified,
                  badgeSize: MyTogetherVerifiedBadge.cardSize,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),

                if (showStatusLine)
                  OrderBlockedStatusLine(
                    text: blockedLine,
                    reason: availability.reason,
                    maxLines: 1,
                  ),
                SizedBox(height: showStatusLine ? 2 : 4),
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

  /// Builds the favorite heart. When self-managing and a valid shop id is
  /// present, the heart reflects the shared wishlist reactively and toggles
  /// through it, so the saved state stays in sync across every screen.
  Widget _buildFavoriteButton(BuildContext context) {
    final int shopIdInt = int.tryParse(shopId ?? '') ?? 0;
    final bool selfManaged =
        selfManageFavorite && shopIdInt > 0 && onFavoriteToggle != null;

    if (selfManaged) {
      return ListenableBuilder(
        listenable: WishlistRepository.instance,
        builder: (context, _) {
          final saved = WishlistFavoriteAction.isSaved(
            WishlistKind.shop,
            shopIdInt,
            isFavorite,
          );
          return _favoriteIcon(
            saved: saved,
            onTap: () => WishlistFavoriteAction.toggle(
              context,
              WishlistKind.shop,
              shopIdInt,
              currentlySaved: saved,
              showToast: showFavoriteToast,
            ),
          );
        },
      );
    }

    return _favoriteIcon(
      saved: isFavorite,
      onTap: onFavoriteToggle != null
          ? () async {
              if (!await GuestAuthGuard.requireAccount(context)) return;
              if (!context.mounted) return;
              final willBeSaved = !isFavorite;
              onFavoriteToggle!.call();
              if (showFavoriteToast) {
                AppDialog.showToast(
                  context,
                  context.tr(
                    willBeSaved ? 'wishlist.saved' : 'wishlist.removed',
                  ),
                );
              }
            }
          : () => AppDialog.showUnavailable(context),
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

  Widget _buildFallbackImage(BuildContext context, double height) {
    return Container(
      height: height,
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


