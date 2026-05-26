import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../cart/data/cart_manager.dart';
import 'shop_item_metadata_row.dart';

import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_text.dart';
import 'image_skeleton_loader.dart';
import '../screens/menu_detail_page.dart';
import '../screens/restaurant_detail_page.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';

class FoodMenuItemCard extends StatefulWidget {
  final String id;
  final String restaurantId;
  final String title;
  final double price;
  final String currency;
  final String imagePath;
  final String restaurantName;
  final bool isFavorite;
  final double rating;
  final double? originalPrice;
  final String? displayPrice;
  final bool showRestaurantName;
  final int reviewCount;
  final double? distanceKm;
  final String? estimatedTime;
  final String? deliveryFee;
  final String? originalDeliveryFee;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onAddToCart;
  final bool isHighlighted;
  final bool forceRestaurantNavigation;
  final String? targetMenuItemId;
  // Real-time status fields
  final bool isAvailable;
  final String publishStatus;

  const FoodMenuItemCard({
    super.key,
    required this.id,
    required this.restaurantId,
    required this.title,
    required this.price,
    required this.currency,
    required this.imagePath,
    required this.restaurantName,
    this.isFavorite = false,
    this.rating = 0.0,
    this.originalPrice,
    this.displayPrice,
    this.showRestaurantName = true,
    this.distanceKm,
    this.reviewCount = 0,
    this.estimatedTime,
    this.deliveryFee,
    this.originalDeliveryFee,
    this.onFavoriteToggle,
    this.onAddToCart,
    this.isHighlighted = false,
    this.forceRestaurantNavigation = false,
    this.targetMenuItemId,
    this.isAvailable = true,
    this.publishStatus = 'PUBLISHED',
  });

  @override
  State<FoodMenuItemCard> createState() => _FoodMenuItemCardState();
}

class _FoodMenuItemCardState extends State<FoodMenuItemCard> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _borderController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05).chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
    ]).animate(_controller);

    _floatAnimation = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(0, -0.06)).chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: const Offset(0, -0.06), end: Offset.zero).chain(CurveTween(curve: Curves.bounceOut)), weight: 60),
    ]).animate(_controller);

    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.isHighlighted) {
      _controller.forward();
      // Start border tracing animation after a slight delay
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _borderController.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isNetworkImage = widget.imagePath.startsWith('http');
    final double effectivePrice = (widget.price == 0 && widget.originalPrice != null && widget.originalPrice! > 0)
        ? widget.originalPrice!
        : widget.price;
    final bool hasDiscount = widget.originalPrice != null && widget.originalPrice! > effectivePrice;

    final bool effectiveIsHidden = (widget.publishStatus == 'UNPUBLISHED' || 
                                   widget.publishStatus == 'ARCHIVED' || 
                                   widget.publishStatus == 'DRAFT');
    final bool effectiveIsDisabled = !effectiveIsHidden && !widget.isAvailable;

    if (effectiveIsHidden) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, _) {
        final isInCart = CartManager.instance.getStoreItemCount(widget.restaurantName) > 0 &&
            CartManager.instance.findItem(widget.restaurantName, int.tryParse(widget.id) ?? 0) != null;
        final showFilledHeart = widget.isFavorite || isInCart;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return FractionalTranslation(
              translation: _floatAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: _OutOfStockWrapper(
                  isDisabled: effectiveIsDisabled,
                  child: GestureDetector(
                    onTap: effectiveIsDisabled
                        ? null
                        : () {
                            if (widget.forceRestaurantNavigation) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RestaurantDetailPage(
                                    id: widget.restaurantId,
                                    name: widget.restaurantName,
                                    targetMenuItemId: widget.id,
                                    isFavorite: false,
                                  ),
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MenuDetailPage(
                                  id: widget.id,
                                  restaurantId: widget.restaurantId,
                                  title: widget.title,
                                  price: effectivePrice,
                                  currency: widget.currency,
                                  imagePath: widget.imagePath,
                                  restaurantName: widget.restaurantName,
                                  displayPrice: widget.displayPrice,
                                  description: '',
                                  isFavorite: showFilledHeart,
                                ),
                              ),
                            );
                          },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Section
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: _borderController,
                                  builder: (context, child) {
                                    return ShaderMask(
                                      blendMode: BlendMode.srcATop,
                                      shaderCallback: (Rect bounds) {
                                        final double slide = (_borderController.value * 3) - 1.5;
                                        return LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withValues(alpha: 0.0),
                                            Colors.white.withValues(alpha: 0.0),
                                            Colors.white.withValues(alpha: 0.6),
                                            Colors.white.withValues(alpha: 0.8),
                                            Colors.white.withValues(alpha: 0.6),
                                            Colors.white.withValues(alpha: 0.0),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                          stops: const [0.0, 0.35, 0.45, 0.5, 0.55, 0.65, 1.0],
                                          transform: GradientRotation(0.35),
                                          tileMode: TileMode.clamp,
                                        ).createShader(
                                          Rect.fromLTWH(
                                            bounds.width * slide,
                                            bounds.height * slide,
                                            bounds.width,
                                            bounds.height,
                                          ),
                                        );
                                      },
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      clipBehavior: Clip.antiAlias,
                                      child: (widget.imagePath.isEmpty || widget.imagePath.trim().isEmpty)
                                          ? _buildFallbackImage()
                                          : (isNetworkImage
                                              ? Image.network(
                                                  widget.imagePath,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return const ImageSkeletonLoader();
                                                  },
                                                )
                                              : Image.asset(
                                                  widget.imagePath,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
                                                )),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: GestureDetector(
                                  onTap: () => AppDialog.showUnavailable(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      showFilledHeart
                                          ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                                          : PhosphorIcons.heart(),
                                      color: showFilledHeart ? AppColors.primary : Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.onAddToCart != null)
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: effectiveIsDisabled ? null : widget.onAddToCart,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Text Info Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (effectivePrice > 0 ||
                                      hasDiscount ||
                                      (widget.displayPrice != null &&
                                          widget.displayPrice != '฿ 0' &&
                                          widget.displayPrice != '฿0' &&
                                          widget.displayPrice != '0')) ...[
                                    const SizedBox(width: 4),
                                    if (hasDiscount) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          widget.originalPrice!
                                              .toStringAsFixed(0)
                                              .toFormattedPrice(currency: widget.currency),
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[400],
                                            fontWeight: FontWeight.w400,
                                            fontSize: 10,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    GradientText(
                                      widget.displayPrice ??
                                          effectivePrice
                                              .toStringAsFixed(0)
                                              .toFormattedPrice(currency: widget.currency),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              if (widget.showRestaurantName && widget.restaurantName.isNotEmpty) ...[
                                Text(
                                  widget.restaurantName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Transform.translate(
                                offset: const Offset(-1.5, 0),
                                child: ShopItemMetadataRow(
                                  rating: widget.rating > 0 ? widget.rating : null,
                                  reviewCount: widget.reviewCount,
                                  distanceKm: widget.distanceKm,
                                  deliveryTime: widget.estimatedTime,
                                  deliveryFee: widget.deliveryFee,
                                  originalDeliveryFee: widget.originalDeliveryFee,
                                  fontSize: 10,
                                  iconSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              'No Image',
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

class _OutOfStockWrapper extends StatelessWidget {
  final bool isDisabled;
  final Widget child;

  const _OutOfStockWrapper({required this.isDisabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isDisabled) return child;
    return Stack(
      children: [
        // Grayscale effect for the whole card when disabled
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      1, 0,
          ]),
          child: Opacity(opacity: 0.5, child: child),
        ),
        // "Unavailable" overlay centered specifically over the image area
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The image section usually takes the top ~60-70% of the card
              // We want to center the label in that area.
              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Text(
                          'Unavailable',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(), // Pushes the center above the text info area
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
