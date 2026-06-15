import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../data/active_order_state.dart';
import 'revise_unavailable_items_section.dart';

enum OrderActionDialogKind { slipReupload, unavailableItems }

/// Global modal shown when the shop requests a new payment slip or marks items
/// unavailable. Styled as a compact action sheet dialog.
class OrderActionDialog extends StatelessWidget {
  final OrderActionDialogKind kind;
  final ActiveOrderItem order;

  const OrderActionDialog({
    super.key,
    required this.kind,
    required this.order,
  });

  static Future<OrderActionDialogResult?> show(
    BuildContext context, {
    required OrderActionDialogKind kind,
    required ActiveOrderItem order,
  }) {
    return showDialog<OrderActionDialogResult>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => OrderActionDialog(kind: kind, order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSlip = kind == OrderActionDialogKind.slipReupload;
    final resolved = order.resolvedReviseInfo;
    final reasonText = resolved.reason.isNotEmpty
        ? resolved.reason
        : (isSlip
            ? context.tr('payment.receipt_requested')
            : context.tr('revise.reason_default'));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIcons.warningCircle,
                    color: Colors.orange.shade800,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isSlip
                          ? context.tr('order_action.slip_title')
                          : context.tr('order_action.revise_title'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(
                      context,
                      OrderActionDialogResult.later,
                    ),
                    child: Icon(Icons.close, size: 20, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isSlip && resolved.items.isNotEmpty) ...[
                ReviseUnavailableItemsSection(items: resolved.items),
                const SizedBox(height: 10),
                Text(
                  context.tr('revise.reason_title'),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                reasonText,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryGradientButton(
                onPressed: () => Navigator.pop(
                  context,
                  isSlip
                      ? OrderActionDialogResult.uploadSlip
                      : OrderActionDialogResult.reviewOrder,
                ),
                height: 48,
                child: Text(
                  isSlip
                      ? context.tr('order_action.slip_upload_now')
                      : context.tr('order_action.revise_review'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!isSlip)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      OrderActionDialogResult.cancelOrder,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(
                      context.tr('order_action.revise_cancel'),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    OrderActionDialogResult.later,
                  ),
                  child: Text(
                    context.tr('order_action.later'),
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum OrderActionDialogResult {
  uploadSlip,
  reviewOrder,
  cancelOrder,
  later,
}
