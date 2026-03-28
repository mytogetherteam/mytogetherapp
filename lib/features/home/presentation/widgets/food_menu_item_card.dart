import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../cart/data/cart_manager.dart';
import 'shop_item_metadata_row.dart';

import 'image_skeleton_loader.dart';
import '../screens/menu_detail_page.dart';
import '../screens/restaurant_detail_page.dart';

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
  final bool isHighlighted;
  final bool forceRestaurantNavigation;
  final String? targetMenuItemId;

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
    this.isHighlighted = false,
    this.forceRestaurantNavigation = false,
    this.targetMenuItemId,
  });

  @override
  State<FoodMenuItemCard> createState() => _FoodMenuItemCardState();
}

class _FoodMenuItemCardState extends State<FoodMenuItemCard> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _borderController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _floatAnimation;
  bool _imageLoadFailed = false;

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

  void _onImageError() {
    if (mounted && !_imageLoadFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _imageLoadFailed = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // DO NOT hide the card anymore even if image is missing
    final bool hasInvalidImage = widget.imagePath.trim().isEmpty;

    final bool isNetworkImage = widget.imagePath.startsWith('http');
    final bool hasDiscount = widget.originalPrice != null && widget.originalPrice! > widget.price;

    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, _) {
        // Consider it favorite/filled if explicitly favorite OR if already in cart
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
                child: GestureDetector(
                  onTap: () {
                    if (widget.forceRestaurantNavigation) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RestaurantDetailPage(
                            id: widget.restaurantId,
                            name: widget.restaurantName,
                            targetMenuItemId: widget.id,
                            isFavorite: false, // Fallback
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
                          price: widget.price,
                          currency: widget.currency,
                          imagePath: widget.imagePath,
                          restaurantName: widget.restaurantName,
                          displayPrice: widget.displayPrice,
                          description: '', // Will be fetched via API in MenuDetailPage
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
                                      // Sweep a diagonal shine from top-left to bottom-right
                                      // Animation goes from -1.0 to 1.0 (hidden to hidden)
                                      final double slide = (_borderController.value * 3) - 1.5; 
                                      
                                      return LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.0),
                                          Colors.white.withValues(alpha: 0.0),
                                          Colors.white.withValues(alpha: 0.6), // The shine core
                                          Colors.white.withValues(alpha: 0.8), // The shine center
                                          Colors.white.withValues(alpha: 0.6), // The shine core
                                          Colors.white.withValues(alpha: 0.0),
                                          Colors.white.withValues(alpha: 0.0),
                                        ],
                                        stops: const [0.0, 0.35, 0.45, 0.5, 0.55, 0.65, 1.0],
                                        transform: GradientRotation(0.35), // Slight tilt
                                        // Move the gradient based on slide
                                        tileMode: TileMode.clamp,
                                      ).createShader(
                                        Rect.fromLTWH(
                                          bounds.width * slide, 
                                          bounds.height * slide, 
                                          bounds.width, 
                                          bounds.height
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
                                    child: hasInvalidImage || _imageLoadFailed || widget.imagePath.isEmpty
                                        ? _buildFallbackImage()
                                        : (isNetworkImage
                                            ? CachedNetworkImage(
                                              imageUrl: widget.imagePath,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => const ImageSkeletonLoader(),
                                                errorWidget: (context, url, error) {
                                                  _onImageError();
                                                  return _buildFallbackImage();
                                                },
                                              fadeInDuration: const Duration(milliseconds: 300),
                                            )
                                          : Image.asset(
                                              widget.imagePath,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                _onImageError();
                                                return _buildFallbackImage();
                                              },
                                            )),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: widget.onFavoriteToggle,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  showFilledHeart ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(),
                                  color: showFilledHeart ? const Color(0xFFED3A72) : Colors.white,
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
                              if (widget.price > 0 || hasDiscount || (widget.displayPrice != null && widget.displayPrice != '฿ 0' && widget.displayPrice != '฿0' && widget.displayPrice != '0')) ...[
                                const SizedBox(width: 4),
                                Flexible(
                                  flex: 0,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (hasDiscount) ...[
                                        Flexible(
                                          child: Text(
                                            widget.originalPrice!.toStringAsFixed(0).toFormattedPrice(currency: widget.currency),
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey[400],
                                              fontWeight: FontWeight.w400,
                                              fontSize: 9,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        widget.displayPrice ?? widget.price.toStringAsFixed(0).toFormattedPrice(currency: widget.currency),
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFED3A72),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
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
          );
        },
      );
    },
  );
}

  Widget _buildFallbackImage() {
    return Container(
      width: double.infinity,
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 32),
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

// Previous _BorderPainter removed in favor of mirror reflection ShaderMask logic inside Build.
