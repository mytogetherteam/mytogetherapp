import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_text.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/features/order/data/models/order_history_dto.dart';
import 'package:mytogetherapp/features/reviews/data/models/order_review_dto.dart';
import 'package:mytogetherapp/features/reviews/data/repositories/order_review_repository.dart';
import 'package:mytogetherapp/features/reviews/presentation/screens/write_review_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/features/cart/data/cart_repository.dart';
import 'package:mytogetherapp/features/cart/data/cart_manager.dart';
import 'package:mytogetherapp/features/cart/data/models/cart_dto.dart';
import 'package:mytogetherapp/features/cart/presentation/screens/cart_page.dart';

class OrderHistoryCard extends StatefulWidget {
  final OrderHistoryDto order;

  /// Optional callback the parent can use to refresh the list after a review
  /// is created (so the rating strip flips to "My rating …").
  final VoidCallback? onReviewSubmitted;

  const OrderHistoryCard({
    super.key,
    required this.order,
    this.onReviewSubmitted,
  });

  @override
  State<OrderHistoryCard> createState() => _OrderHistoryCardState();
}

class _OrderHistoryCardState extends State<OrderHistoryCard> {
  /// Locally-cached review (either from the order list response or the
  /// one we just created). Initialized from the order's embedded review,
  /// then overwritten when the user submits one.
  OrderReviewDto? _review;
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _review = widget.order.orderReview;
  }

  @override
  void didUpdateWidget(covariant OrderHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.orderReview != widget.order.orderReview) {
      _review = widget.order.orderReview;
    }
  }

  Color get primaryColor => AppColors.primary;

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiClient.baseUrl}/$path';
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
            Row(
              children: [
                Text(
                  '${context.trArgs('orders.items_count', {'count': '${widget.order.items.length}'})} ',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
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
            color: Colors.grey[100],
          ),
          child: ClipRRect(
             borderRadius: BorderRadius.circular(8),
             child: item.menuItemImageUrl != null && item.menuItemImageUrl!.isNotEmpty
                ? CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                    imageUrl: _getImageUrl(item.menuItemImageUrl),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[100]),
                    errorWidget: (context, url, error) =>
                        Container(color: Colors.grey[200]),
                  )
                : Container(color: Colors.grey[200]),
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
       child: _review != null
           ? _buildRatedContent(context, _review!)
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
    final orderIdInt = int.tryParse(widget.order.id);
    if (orderIdInt == null) {
      AppDialog.showToast(context, context.tr('orders.invalid_reference'), isError: true);
      return;
    }

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WriteReviewPage(
          orderId: orderIdInt,
          shopName: widget.order.shopName,
          initialRating: initialRating,
        ),
      ),
    );

    if (submitted == true) {
      // Pull the saved review so the strip flips locally without waiting
      // for the parent list to refresh.
      try {
        final fresh = await OrderReviewRepository.instance
            .getReviewForOrder(orderIdInt);
        if (!mounted) return;
        if (fresh != null) {
          setState(() => _review = fresh);
        }
      } catch (_) {
        // Best-effort refresh — leave the strip as-is on failure.
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

  Widget _buildRatedContent(BuildContext context, OrderReviewDto review) {
    final score = review.rating;
    final scoreLabel = score == score.roundToDouble()
        ? score.toInt().toString()
        : score.toStringAsFixed(1);
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

