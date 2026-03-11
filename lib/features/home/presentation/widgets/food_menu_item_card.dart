import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/utils/price_formatter.dart';

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
    this.onFavoriteToggle,
    this.isHighlighted = false,
    this.forceRestaurantNavigation = false,
    this.targetMenuItemId,
  });

  @override
  State<FoodMenuItemCard> createState() => _FoodMenuItemCardState();
}

class _FoodMenuItemCardState extends State<FoodMenuItemCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _floatAnimation;
  late Animation<double> _borderAnimation;

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

    _borderAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 2.5).chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 2.5, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 60),
    ]).animate(_controller);

    if (widget.isHighlighted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isNetworkImage = widget.imagePath.startsWith('http');
    final bool hasDiscount = widget.originalPrice != null && widget.originalPrice! > widget.price;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return FractionalTranslation(
          translation: _floatAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: () {
                if (widget.forceRestaurantNavigation || (widget.targetMenuItemId != null && widget.targetMenuItemId != widget.id)) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RestaurantDetailPage(
                        id: widget.restaurantId,
                        name: widget.restaurantName,
                        targetMenuItemId: widget.id,
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
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFED3A72),
                                width: _borderAnimation.value,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip.antiAlias,
                              child: (widget.imagePath.isEmpty || widget.imagePath.trim().isEmpty)
                                ? _buildFallbackImage()
                                : (isNetworkImage
                                    ? CachedNetworkImage(
                                      imageUrl: widget.imagePath,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const ImageSkeletonLoader(),
                                      errorWidget: (context, url, error) => _buildFallbackImage(),
                                      fadeInDuration: const Duration(milliseconds: 300),
                                    )
                                  : Image.asset(
                                      widget.imagePath,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildFallbackImage();
                                      },
                                    )),
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
                          widget.isFavorite ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(),
                          color: widget.isFavorite ? const Color(0xFFED3A72) : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Text Info Section with Padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Title Section
                  Text(
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Restaurant & Rating Row
                  Row(
                    children: [
                      if (widget.showRestaurantName && widget.restaurantName.isNotEmpty) ...[
                        Expanded(
                          child: Text(
                            widget.restaurantName,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (widget.rating > 0) ...[
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          widget.rating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Price Section
                  Row(
                    children: [
                      Text(
                        widget.displayPrice ?? widget.price.toStringAsFixed(0).toFormattedPrice(currency: widget.currency),
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFED3A72),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text(
                          widget.originalPrice!.toStringAsFixed(0).toFormattedPrice(currency: widget.currency),
                          style: GoogleFonts.poppins(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w400,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
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
  }

  Widget _buildFallbackImage() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
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
