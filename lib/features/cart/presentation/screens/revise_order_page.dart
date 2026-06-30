import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/price_formatter.dart';
import '../../data/active_order_state.dart';
import '../../data/cart_manager.dart';
import '../../../order/data/repositories/order_repository.dart';
import '../widgets/revise_unavailable_items_section.dart';
import 'order_cancel_page.dart';

/// Lets the user review and re-submit an order the shop has marked REVISED.
/// Backend: PATCH /api/user/orders/:id/items (UserOrdersController.respondRevise).
class ReviseOrderPage extends StatefulWidget {
  static bool isCurrentlyVisible = false;

  final String orderId;

  const ReviseOrderPage({super.key, required this.orderId});

  @override
  State<ReviseOrderPage> createState() => _ReviseOrderPageState();
}

class _ReviseOrderPageState extends State<ReviseOrderPage> {
  // Mutable editable copy of the order's items, keyed by CartItem.id.
  late final List<_EditableItem> _items;
  late final ({List<String> items, String reason}) _reviseInfo;
  bool _isSubmitting = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    ReviseOrderPage.isCurrentlyVisible = true;
    final order = ActiveOrderState.instance.getOrder(widget.orderId);
    _reviseInfo = order?.resolvedReviseInfo ??
        (items: const <String>[], reason: '');
    final unavailableNames = _reviseInfo.items
        .map((name) => name.toLowerCase().trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    _items = (order?.orderItems ?? const <CartItem>[])
        .where(
          (c) => !unavailableNames.contains(
            (c.titleEn ?? c.titleKey).toLowerCase().trim(),
          ),
        )
        .map((c) => _EditableItem(source: c, quantity: c.quantity))
        .toList();
  }

  @override
  void dispose() {
    ReviseOrderPage.isCurrentlyVisible = false;
    super.dispose();
  }

  double get _estimatedTotal => _items.fold(
        0,
        (sum, e) => sum + e.source.price * e.quantity,
      );

  bool get _hasItems => _items.any((e) => e.quantity > 0);

  Future<void> _submit() async {
    final payload = _items
        .where((e) => e.quantity > 0)
        .map((e) => {
              'menuItemId': e.source.menuItemId,
              'quantity': e.quantity,
              if (e.source.optionIds != null && e.source.optionIds!.isNotEmpty)
                'menuItemOptionId': e.source.optionIds,
              if (e.source.specialInstructions != null &&
                  e.source.specialInstructions!.trim().isNotEmpty)
                'specialInstructions': e.source.specialInstructions,
              if (e.source.variantId != null) 'variantId': e.source.variantId,
            })
        .toList();

    if (payload.isEmpty) return;

    final orderIdInt =
        int.tryParse(widget.orderId.replaceAll('#', '').trim());
    if (orderIdInt == null) return;

    setState(() => _isSubmitting = true);
    try {
      final ok = await OrderRepository().reviseOrderItems(
        orderId: orderIdInt,
        items: payload,
      );
      if (!mounted) return;
      if (ok) {
        await ActiveOrderState.instance.syncActiveOrder(orderId: widget.orderId);
        if (!mounted) return;
        AppDialog.showToast(context, context.tr('revise.resubmitted'));
        Navigator.pop(context, true);
      } else {
        AppDialog.showToast(
          context,
          context.tr('revise.resubmit_failed'),
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('revise.resubmit_failed'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmCancelOrder() async {
    if (_isCancelling || _isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          ctx.tr('order_action.cancel_confirm_title'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          ctx.tr('order_action.cancel_confirm_message'),
          style: GoogleFonts.poppins(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              ctx.tr('order_action.keep_order'),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              ctx.tr('order_action.revise_cancel'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _cancelOrder();
    }
  }

  Future<void> _cancelOrder() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);

    final order = ActiveOrderState.instance.getOrder(widget.orderId);

    try {
      final success = await ActiveOrderState.instance.cancelActiveOrder(
        orderId: widget.orderId,
      );
      if (!mounted) return;
      if (success) {
        AppDialog.showToast(context, context.tr('payment.cancel_success'));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderCancelPage(
              orderId: order?.orderId ?? widget.orderId,
              reason: order?.cancelReason,
              shopId: order?.shopId,
              shopName: order?.shopNameEn ??
                  order?.shopName ??
                  order?.restaurantName ??
                  order?.storeName,
              shopNameMm: order?.shopNameMm,
              shopNameTh: order?.shopNameTh,
              shopLogo: order?.shopLogo ?? order?.logoPath,
              shopImageUrl: order?.shopImageUrl,
              cancelledByUser: true,
            ),
          ),
        );
      } else {
        AppDialog.showToast(
          context,
          context.tr('payment.cancel_failed'),
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('payment.connection_error'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('revise.title'),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
      body: _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.tr('revise.no_items'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isCancelling ? null : _confirmCancelOrder,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isCancelling
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                context.tr('order_action.revise_cancel'),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildReasonBanner(),
                const SizedBox(height: 16),
                Text(
                  context.tr('revise.items_title'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ..._items.map(_buildItemRow),
              ],
            ),
      bottomNavigationBar: _items.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryGradientButton(
                    onPressed: (_isSubmitting || _isCancelling || !_hasItems)
                        ? null
                        : _submit,
                    isLoading: _isSubmitting,
                    child: Text(
                      context.trArgs('revise.resubmit', {
                        'total': _estimatedTotal.toStringAsFixed(2),
                      }),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: (_isSubmitting || _isCancelling)
                          ? null
                          : _confirmCancelOrder,
                      child: _isCancelling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              context.tr('order_action.revise_cancel'),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReasonBanner() {
    final reasonText = _reviseInfo.reason.isNotEmpty
        ? _reviseInfo.reason
        : context.tr('revise.reason_default');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIcons.warningCircle,
              color: Colors.orange.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_reviseInfo.items.isNotEmpty) ...[
                  ReviseUnavailableItemsSection(items: _reviseInfo.items),
                  const SizedBox(height: 8),
                ],
                Text(
                  context.tr('revise.reason_title'),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reasonText,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(_EditableItem item) {
    final c = item.source;
    final imageUrl = c.imageUrl ?? c.imagePath;
    final optionsText = c.options;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                    imageUrl: imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _imgPlaceholder(),
                  )
                : _imgPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (optionsText != null && optionsText.trim().isNotEmpty)
                  Text(
                    optionsText,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                Text(
                  (c.price * item.quantity).toFormattedPrice(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          _QuantityStepper(
            quantity: item.quantity,
            onChanged: (q) => setState(() => item.quantity = q),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      color: Colors.grey.shade100,
      child: Icon(Icons.fastfood, size: 20, color: Colors.grey.shade300),
    );
  }
}

class _EditableItem {
  final CartItem source;
  int quantity;
  _EditableItem({required this.source, required this.quantity});
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleButton(
          icon: Icons.remove,
          onTap: quantity > 0 ? () => onChanged(quantity - 1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _circleButton(
          icon: Icons.add,
          onTap: () => onChanged(quantity + 1),
        ),
      ],
    );
  }

  Widget _circleButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null
              ? Colors.grey.shade200
              : AppColors.primary.withValues(alpha: 0.12),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? Colors.grey : AppColors.primary,
        ),
      ),
    );
  }
}

