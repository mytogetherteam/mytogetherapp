import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/utils/paginated_list_controller.dart';
import 'package:mytogetherapp/core/presentation/widgets/menu_image_placeholder.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/file_url_util.dart';
import 'package:mytogetherapp/core/utils/price_formatter.dart';
import 'package:mytogetherapp/features/order/data/models/order_history_dto.dart';
import 'package:mytogetherapp/features/order/data/repositories/order_repository.dart';

/// What was ordered: dishes, quantities, and the fee breakdown.
/// Dishes load a page at a time. Courier tracking links are not shown here.
class OrderHistoryDetailPage extends StatefulWidget {
  final OrderHistoryDto order;

  const OrderHistoryDetailPage({super.key, required this.order});

  @override
  State<OrderHistoryDetailPage> createState() => _OrderHistoryDetailPageState();
}

class _OrderHistoryDetailPageState extends State<OrderHistoryDetailPage> {
  static const int _pageSize = 10;

  late final PaginatedListController<OrderHistoryItemDto> _items;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _items = PaginatedListController<OrderHistoryItemDto>(
      pageSize: _pageSize,
      initialPage: 1,
      itemKey: (item) =>
          item.id ??
          '${item.menuItemId}|${item.quantity}|${item.price}|${item.specialInstructions}',
      fetchPage: _fetchPage,
    )..addListener(_onItemsChanged);
    _items.attachScrollController(_scrollController);
    _items.loadInitial();
  }

  @override
  void dispose() {
    _items.removeListener(_onItemsChanged);
    _items.detachScrollController();
    _items.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onItemsChanged() {
    if (mounted) setState(() {});
  }

  Future<PaginatedPage<OrderHistoryItemDto>> _fetchPage(int page) async {
    final orderId = int.tryParse(widget.order.id);
    if (orderId == null) {
      return PaginatedPage(
        items: page == 1 ? widget.order.items : const [],
        hasMore: false,
      );
    }
    try {
      final result = await OrderRepository().getOrderItemsPage(
        orderId: orderId,
        page: page,
        size: _pageSize,
      );
      return PaginatedPage(items: result.items, hasMore: result.hasMore);
    } catch (_) {
      if (page == 1 && widget.order.items.isNotEmpty) {
        return PaginatedPage(items: widget.order.items, hasMore: false);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final tax = order.taxAmount ?? 0;
    final coupon = order.discountAmount ?? 0;
    final shopDiscount = order.transactionDiscount ?? 0;
    final dishes = _items.items;
    final showLoader = _items.isInitialLoading || _items.isLoadingMore;
    final showEmpty = !_items.isInitialLoading && dishes.isEmpty;
    final itemCount =
        1 + dishes.length + (showEmpty ? 1 : 0) + (showLoader ? 1 : 0) + 1;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          context.tr('order_status.view_summary'),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) return _header(context, order);
          var cursor = 1;
          if (index < cursor + dishes.length) {
            final dishIndex = index - cursor;
            if (dishIndex == dishes.length - 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _items.onItemVisible(dishIndex);
              });
            }
            return _dishRow(
              dishes[dishIndex],
              first: dishIndex == 0,
              last: dishIndex == dishes.length - 1,
            );
          }
          cursor += dishes.length;
          if (showEmpty && index == cursor) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _panel(
                child: Text(
                  context.tr('order_status.no_items'),
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
            );
          }
          if (showEmpty) cursor += 1;
          if (showLoader && index == cursor) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _fees(context, order, tax, coupon, shopDiscount);
        },
      ),
    );
  }

  Widget _dishRow(
    OrderHistoryItemDto item, {
    required bool first,
    required bool last,
  }) {
    return Container(
      margin: EdgeInsets.only(top: first ? 12 : 0),
      padding: EdgeInsets.fromLTRB(16, first ? 4 : 0, 16, last ? 4 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: first ? const Radius.circular(16) : Radius.zero,
          bottom: last ? const Radius.circular(16) : Radius.zero,
        ),
      ),
      child: Column(
        children: [
          if (!first) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _ItemRow(item: item),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, OrderHistoryDto order) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.shopName ?? context.tr('common.shop'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.displayStatusLabel,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            order.dateDisplay,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
          ),
          if ((order.lastOrderNo ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '#${order.lastOrderNo}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  /// Flexible delivery stores a fee for the rider. It is not inside the total.
  bool _deliveryFeeIsEstimate(OrderHistoryDto order) {
    if (order.isPickupFulfillment || order.isFreeDelivery) return false;
    final type = (order.orderDeliveryType ?? '').toUpperCase();
    return type == 'FLEXIBLE' || type == 'NORMAL';
  }

  Widget _fees(
    BuildContext context,
    OrderHistoryDto order,
    double tax,
    double coupon,
    double shopDiscount,
  ) {
    final foodTotal = order.itemPrice;
    final feeIsEstimate = _deliveryFeeIsEstimate(order);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _panel(
        child: Column(
          children: [
            if (foodTotal != null)
              _amountRow(
                context.tr('order_status.food_total'),
                foodTotal.toFormattedPrice(),
              ),
            if (!order.isPickupFulfillment &&
                (order.isFreeDelivery || order.deliveryFee != null)) ...[
              const SizedBox(height: 10),
              _amountRow(
                feeIsEstimate
                    ? context.tr('payment.est_delivery_fee')
                    : context.tr('order_status.delivery_fee'),
                order.isFreeDelivery
                    ? context.tr('common.free')
                    : order.deliveryFee!.toFormattedPrice(),
                valueColor:
                    order.isFreeDelivery ? const Color(0xFF10B981) : null,
              ),
            ],
            if (tax > 0) ...[
              const SizedBox(height: 10),
              _amountRow(
                context.tr('order_status.tax'),
                tax.toFormattedPrice(),
              ),
            ],
            if (coupon > 0) ...[
              const SizedBox(height: 10),
              _amountRow(
                context.tr('order_status.discount'),
                '-${coupon.toFormattedPrice()}',
              ),
            ],
            if (shopDiscount > 0) ...[
              const SizedBox(height: 10),
              _amountRow(
                context.tr('order_status.transaction_discount'),
                '-${shopDiscount.toFormattedPrice()}',
              ),
            ],
            const Divider(height: 22),
            _totalRow(context, order),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _totalRow(BuildContext context, OrderHistoryDto order) {
    final icon = order.paymentMethodIconUrl;
    final name = order.paymentMethodName;
    final label = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Colors.black87,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr('order_status.total_amount'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: label,
          ),
        ),
        if (icon != null) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96, maxHeight: 22),
            child: CachedNetworkImage(
              imageUrl: icon,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              imageBuilder: (_, provider) => Align(
                alignment: Alignment.centerRight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image(
                    image: provider,
                    width: 36,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              errorWidget: (_, _, _) => _paymentName(name),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (name != null) ...[
          Flexible(child: _paymentName(name)),
          const SizedBox(width: 8),
        ],
        Text(order.totalAmount.toFormattedPrice(), style: label),
      ],
    );
  }

  Widget _paymentName(String? name) {
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    return Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      ),
    );
  }

  Widget _amountRow(
    String label,
    String value, {
    bool emphasize = false,
    Color? valueColor,
  }) {
    final style = GoogleFonts.poppins(
      fontSize: emphasize ? 15 : 13,
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
      color: valueColor ?? (emphasize ? Colors.black : Colors.black87),
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: emphasize ? 15 : 13,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        Text(value, style: style),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderHistoryItemDto item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = FileUrlUtil.resolve(item.menuItemImageUrl);
    final note = item.specialInstructions?.trim();
    final choice = item.choiceLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 64,
            height: 64,
            child: imageUrl.isEmpty
                ? MenuImagePlaceholder(title: item.menuItemName)
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    errorWidget: (_, _, _) =>
                        MenuImagePlaceholder(title: item.menuItemName),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.menuItemName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if (choice != null) ...[
                const SizedBox(height: 2),
                Text(
                  choice,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '× ${item.quantity}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          item.lineTotal.toFormattedPrice(),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
