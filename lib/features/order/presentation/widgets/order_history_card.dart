import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_text.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/features/order/data/models/order_history_dto.dart';
import 'package:mytogetherapp/features/reviews/data/repositories/shop_review_repository.dart';
import 'package:mytogetherapp/features/reviews/presentation/screens/write_review_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/utils/file_url_util.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/features/cart/data/cart_repository.dart';
import 'package:mytogetherapp/features/cart/data/cart_manager.dart';
import 'package:mytogetherapp/features/cart/data/models/cart_dto.dart';
import 'package:mytogetherapp/core/presentation/widgets/menu_image_placeholder.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/image_skeleton_loader.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/cart_page.dart';

class OrderHistoryCard extends StatefulWidget {
  final OrderHistoryDto order;

  /// User's existing restaurant review rating for this order's shop, if any.
  final double? shopRating;

  /// Optional callback the parent can use to refresh shop ratings after submit.
  final VoidCallback? onReviewSubmitted;

  const OrderHistoryCard({
    super.key,
    required this.order,
    this.shopRating,
    this.onReviewSubmitted,
  });

  @override
  State<OrderHistoryCard> createState() => _OrderHistoryCardState();
}

class _OrderHistoryCardState extends State<OrderHistoryCard> {
  /// Locally cached rating after submit, before parent reloads shop ratings.
  double? _localRating;
  bool _isReordering = false;

  double? get _displayRating => _localRating ?? widget.shopRating;

  @override
  void didUpdateWidget(covariant OrderHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopRating != widget.shopRating) {
      _localRating = null;
    }
  }

  Color get primaryColor => AppColors.primary;

  String _getImageUrl(String? path) {
    return FileUrlUtil.resolve(path);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopRow(context),
                const SizedBox(height: 16),
                _buildMiddleRow(),
                const SizedBox(height: 16),
                _buildBottomRow(context),
              ],
            ),
          ),
          if (widget.order.status == 'DELIVERED') _buildRatingStrip(context),
        ],
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    Color labelColor = Colors.grey;
    if (widget.order.ongoing) labelColor = primaryColor;
    if (widget.order.status == 'DELIVERED') labelColor = primaryColor;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: widget.order.shopImageUrl != null && widget.order.shopImageUrl!.isNotEmpty
                ? CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                    imageUrl: _getImageUrl(widget.order.shopImageUrl),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[100]),
                    errorWidget: (context, url, error) =>
                        Container(
                    color: Colors.grey[100],
                    child: Icon(Icons.storefront_rounded, size: 20, color: Colors.grey[400]),
                  ),
                  )
                : Container(
                    color: Colors.grey[100],
                    child: Icon(Icons.storefront_rounded, size: 20, color: Colors.grey[400]),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.order.shopName ?? context.tr('common.shop'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          widget.order.displayStatusLabel,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMiddleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: _buildThumbnails(),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GradientText(
              widget.order.displayTotalAmount ?? '฿${widget.order.totalAmount}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.trArgs('orders.items_count', {'count': '${widget.order.items.length}'}),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildThumbnails() {
    List<Widget> thumbs = [];
    int maxDisplayCount = 3;
    bool hasOverflow = widget.order.items.length > maxDisplayCount;

    for (int i = 0; i < (hasOverflow ? maxDisplayCount : widget.order.items.length); i++) {
        bool isLast = i == widget.order.items.length - 1;
        bool isThird = i == maxDisplayCount - 1;
        final item = widget.order.items[i];

        Widget img = Container(
          width: 60,
          height: 60,
          margin: EdgeInsets.only(right: isLast ? 0 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildItemThumbnail(item),
          ),
        );

        if (hasOverflow && isThird) {
           thumbs.add(Stack(
             children: [
                img,
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                  child: Center(
                    child: Text(
                      '+${widget.order.items.length - maxDisplayCount}', // +X overlay
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
             ],
           ));
        } else {
           thumbs.add(img);
        }
    }

    return thumbs;
  }

  Widget _buildItemThumbnail(OrderHistoryItemDto item) {
    final imageUrl = item.menuItemImageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return MenuImagePlaceholder(title: item.menuItemName);
    }

    return CachedNetworkImage(
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      imageUrl: _getImageUrl(imageUrl),
      fit: BoxFit.cover,
      width: 60,
      height: 60,
      placeholder: (context, url) => const ImageSkeletonLoader(
        width: 60,
        height: 60,
      ),
      errorWidget: (context, url, error) =>
          MenuImagePlaceholder(title: item.menuItemName),
    );
  }

  Widget _buildBottomRow(BuildContext context) {
    if (widget.order.ongoing) {
       return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Spacer(),
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
               decoration: BoxDecoration(
                 color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
               ),
               child: Text(
                 context.tr('orders.in_progress'),
                 style: GoogleFonts.poppins(
                   fontWeight: FontWeight.w600,
                   fontSize: 12,
                   color: primaryColor,
                 ),
               ),
            ),
          ],
       );
    }

    // For completed and cancelled
    final btnLabel = widget.order.status == 'DELIVERED'
        ? context.tr('orders.reorder')
        : context.tr('orders.buy_again');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.order.dateDisplay,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[500],
          ),
        ),
        PrimaryGradientButton(
           onPressed: _isReordering ? null : _reorder,
           isLoading: _isReordering,
           height: 42,
           width: 120,
           borderRadius: BorderRadius.circular(12),
           child: Text(
             btnLabel,
             style: GoogleFonts.poppins(
               fontWeight: FontWeight.w600,
               fontSize: 13,
               color: Colors.white,
             ),
           ),
        ),
      ],
    );
  }

  Widget _buildRatingStrip(BuildContext context) {
    return Container(
       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
       decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC), // Light grey strip
          borderRadius: BorderRadius.only(
             bottomLeft: Radius.circular(16),
             bottomRight: Radius.circular(16),
          ),
       ),
       child: _displayRating != null
           ? _buildRatedContent(context, _displayRating!)
           : _buildPromptContent(context),
    );
  }

  /// Re-adds each line item from this past order to the cart via the existing
  /// cart API, then opens the cart so the user can proceed to checkout.
  Future<void> _reorder() async {
    if (_isReordering) return;

    final shopId = widget.order.shopId;
    final reorderable =
        widget.order.items.where((i) => i.menuItemId != null).toList();

    if (reorderable.isEmpty) {
      AppDialog.showToast(
        context,
        context.tr('orders.reorder_failed'),
        isError: true,
      );
      return;
    }

    setState(() => _isReordering = true);

    var added = 0;
    var failed = 0;
    CartDto? lastCart;

    for (final item in reorderable) {
      try {
        lastCart = await CartRepository.instance.addToCart(
          AddToCartRequest(
            menuItemId: item.menuItemId!,
            quantity: item.quantity,
            shopId: shopId,
          ),
        );
        added++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    setState(() => _isReordering = false);

    if (added == 0) {
      AppDialog.showToast(
        context,
        context.tr('orders.reorder_failed'),
        isError: true,
      );
      return;
    }

    if (lastCart != null) {
      CartManager.instance.updateCartFromDto(lastCart);
      await CartManager.instance.invalidateCache();
    } else {
      await CartManager.instance.syncWithApi();
    }

    if (!mounted) return;

    final message = failed > 0
        ? context.tr('orders.reorder_some_unavailable')
        : context.tr('orders.reorder_added');
    AppDialog.showToast(context, message);

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CartPage()),
    );
  }

  Future<void> _openReviewFlow({int initialRating = 0}) async {
    final shopId = widget.order.shopId;
    if (shopId == null) {
      AppDialog.showToast(
        context,
        context.tr('orders.invalid_reference'),
        isError: true,
      );
      return;
    }

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WriteReviewPage(
          shopId: shopId,
          shopName: widget.order.shopName,
          initialRating: initialRating,
        ),
      ),
    );

    if (submitted == true) {
      try {
        final reviews = await ShopReviewRepository.instance.getMyReviews(
          shopId: shopId,
          size: 1,
        );
        if (!mounted) return;
        if (reviews.isNotEmpty) {
          setState(() => _localRating = reviews.first.rating);
        }
      } catch (_) {
        if (mounted && initialRating > 0) {
          setState(() => _localRating = initialRating.toDouble());
        }
      }
      widget.onReviewSubmitted?.call();
    }
  }

  Widget _buildPromptContent(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.tr('orders.how_was_order'),
          style: GoogleFonts.poppins(
             fontSize: 13,
             color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 12),
        Row(
           children: List.generate(5, (index) => GestureDetector(
              onTap: () => _openReviewFlow(initialRating: index + 1),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.star_border_rounded, size: 24, color: Colors.grey[400]),
              ),
           )),
        ),
      ],
    );
  }

  Widget _buildRatedContent(BuildContext context, double rating) {
    final scoreLabel = rating == rating.roundToDouble()
        ? rating.toInt().toString()
        : rating.toStringAsFixed(1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.trArgs('orders.my_rating', {'score': scoreLabel}),
           style: GoogleFonts.poppins(
             fontSize: 13,
             color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.star_rounded, size: 20, color: primaryColor),
      ],
    );
  }
}

