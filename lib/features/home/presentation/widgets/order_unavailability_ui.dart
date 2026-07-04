import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../data/restaurant_order_availability.dart';
import '../../data/shop_order_state_cache.dart';
import 'restaurant_open_status.dart';

/// Wraps a card/cover image with a soft fade when the shop is closed.
///
/// Uses opacity + a light veil only (no [ColorFiltered] or blend modes) so
/// network images keep rendering correctly on web/PWA. Delivery-disabled items
/// keep the status badge but are not dimmed.
class UnavailableImageDim extends StatelessWidget {
  final bool active;
  final Widget child;
  final BorderRadius borderRadius;

  const UnavailableImageDim({
    super.key,
    required this.active,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Opacity(opacity: 0.52, child: child),
          Positioned.fill(
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.28),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill on the menu-item image — visible but not repetitive.
///
/// When [inset] is true the badge spans the bottom of the image (for small
/// search thumbnails) so long labels like "No delivery" stay inside the clip.
class OrderStatusImageBadge extends StatelessWidget {
  final OrderBlockReason reason;
  final bool inset;
  final BorderRadius imageBorderRadius;

  const OrderStatusImageBadge({
    super.key,
    required this.reason,
    this.inset = false,
    this.imageBorderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    if (reason == OrderBlockReason.none) return const SizedBox.shrink();

    final String label;
    switch (reason) {
      case OrderBlockReason.deliveryDisabled:
        label = context.tr('order.badge_delivery_off');
      case OrderBlockReason.closed:
        label = context.tr('common.closed');
      case OrderBlockReason.none:
        label = '';
    }

    if (inset) {
      return ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: imageBorderRadius.bottomLeft,
          bottomRight: imageBorderRadius.bottomRight,
        ),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Inset status chip above the restaurant info card (MyTogether styling).
class RestaurantOrderStatusStrip extends StatelessWidget {
  final String message;
  final OrderBlockReason reason;

  const RestaurantOrderStatusStrip({
    super.key,
    required this.message,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();

    final Color bg;
    final Color fg;
    final Color border;
    final IconData icon;

    switch (reason) {
      case OrderBlockReason.deliveryDisabled:
        bg = const Color(0xFFFFF5F7);
        fg = AppColors.primary;
        border = AppColors.primary.withValues(alpha: 0.18);
        icon = PhosphorIcons.truck;
      case OrderBlockReason.closed:
        bg = Colors.white;
        fg = RestaurantOpenStatus.closedColor;
        border = const Color(0xFFE5E7EB);
        icon = PhosphorIcons.clockCountdown;
      case OrderBlockReason.none:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 30,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fg,
                    height: 1.35,
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

/// @deprecated Use [RestaurantOrderStatusStrip] above the info card instead.
class RestaurantOrderBanner extends StatelessWidget {
  final String message;
  final OrderBlockReason reason;

  const RestaurantOrderBanner({
    super.key,
    required this.message,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return RestaurantOrderStatusStrip(message: message, reason: reason);
  }
}

/// Banner on the menu item detail page.
class MenuItemOrderBanner extends StatelessWidget {
  final String message;
  final OrderBlockReason reason;

  const MenuItemOrderBanner({
    super.key,
    required this.message,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();

    final Color bg;
    final Color fg;
    final IconData icon;

    switch (reason) {
      case OrderBlockReason.deliveryDisabled:
        bg = const Color(0xFFFFF5F7);
        fg = AppColors.primary;
        icon = PhosphorIcons.truck;
      case OrderBlockReason.closed:
        bg = Colors.white;
        fg = RestaurantOpenStatus.closedColor;
        icon = PhosphorIcons.clockCountdown;
      case OrderBlockReason.none:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: reason == OrderBlockReason.closed
              ? const Color(0xFFE5E7EB)
              : fg.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-time bottom sheet on the restaurant detail page when ordering is blocked.
class OrderUnavailableBottomSheet {
  static Future<void> showIfNeeded(
    BuildContext context, {
    required RestaurantOrderAvailability availability,
    required bool Function() alreadyShown,
    required void Function() markShown,
    int? shopId,
  }) async {
    if (!availability.isBlocked || alreadyShown()) return;
    if (shopId != null &&
        ShopOrderStateCache.instance.hasShownUnavailableSheet(shopId)) {
      return;
    }

    markShown();
    if (shopId != null) {
      ShopOrderStateCache.instance.markUnavailableSheetShown(shopId);
    }
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;

    final accent = _accentFor(availability.reason);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconFor(availability.reason),
                        size: 34,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      availability.bottomSheetTitle(ctx),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      availability.bottomSheetBody(ctx),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(16),
                            splashColor: Colors.white.withValues(alpha: 0.15),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                ctx.tr('order.got_it'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
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
  }

  static Color _accentFor(OrderBlockReason reason) {
    switch (reason) {
      case OrderBlockReason.deliveryDisabled:
        return AppColors.primary;
      case OrderBlockReason.closed:
        return RestaurantOpenStatus.closedColor;
      case OrderBlockReason.none:
        return AppColors.primary;
    }
  }

  static IconData _iconFor(OrderBlockReason reason) {
    switch (reason) {
      case OrderBlockReason.deliveryDisabled:
        return PhosphorIcons.truck;
      case OrderBlockReason.closed:
        return PhosphorIcons.storefront;
      case OrderBlockReason.none:
        return PhosphorIcons.info;
    }
  }
}

/// Status under restaurant list card titles.
class OrderBlockedStatusLine extends StatelessWidget {
  final String text;
  final OrderBlockReason reason;
  final int maxLines;

  const OrderBlockedStatusLine({
    super.key,
    required this.text,
    this.reason = OrderBlockReason.closed,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final Color color;
    switch (reason) {
      case OrderBlockReason.deliveryDisabled:
        color = AppColors.primary;
      case OrderBlockReason.closed:
        color = RestaurantOpenStatus.closedColor;
      case OrderBlockReason.none:
        color = RestaurantOpenStatus.closedColor;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 1),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.3,
        ),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// One-line hint under menu item title on feed cards when shop can't take orders.
class OrderBlockedMenuHint extends StatelessWidget {
  final String text;
  final OrderBlockReason reason;

  const OrderBlockedMenuHint({
    super.key,
    required this.text,
    this.reason = OrderBlockReason.closed,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final Color color;
    switch (reason) {
      case OrderBlockReason.deliveryDisabled:
        color = AppColors.primary;
      case OrderBlockReason.closed:
        color = RestaurantOpenStatus.closedColor;
      case OrderBlockReason.none:
        color = RestaurantOpenStatus.closedColor;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
          height: 1.25,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
