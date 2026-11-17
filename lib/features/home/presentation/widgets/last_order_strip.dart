import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/menu_image_placeholder.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/price_formatter.dart';
import 'package:mytogetherapp/features/food/data/order_again.dart';
import 'package:mytogetherapp/features/home/data/models/shop_feed_item_dto.dart';

/// Clean, high-clarity "Your last order" section.
class LastOrderStrip extends StatelessWidget {
  final List<LastOrderDish> dishes;
  final ShopFeedItemDto? Function(int menuItemId) liveItem;
  final Set<int>? orderableIds;
  final bool canAdd;
  final bool addingAll;
  final int? addingIndex;
  final VoidCallback onAddAll;
  final void Function(int index) onAdd;
  final void Function(int index) onOpen;

  const LastOrderStrip({
    super.key,
    required this.dishes,
    required this.liveItem,
    required this.orderableIds,
    required this.canAdd,
    required this.addingAll,
    required this.addingIndex,
    required this.onAddAll,
    required this.onAdd,
    required this.onOpen,
  });

  bool _removed(LastOrderDish dish) {
    final live = liveItem(dish.menuItemId);
    if (live != null && !live.isAvailable) return true;
    final orderable = orderableIds;
    if (orderable == null) return false;
    return !orderable.contains(dish.menuItemId);
  }

  @override
  Widget build(BuildContext context) {
    final busy = addingAll || addingIndex != null;
    final anyOrderable = dishes.any((dish) => !_removed(dish));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header (Clean & Simple)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('food.last_order'),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: canAdd && !busy && anyOrderable ? onAddAll : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    disabledForegroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.tr('food.add_all_to_basket'),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Dishes Horizontal Carousel
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dishes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final dish = dishes[index];
                final live = liveItem(dish.menuItemId);
                final removed = _removed(dish);
                return _LastOrderCard(
                  dish: dish,
                  live: live,
                  removed: removed,
                  enabled: canAdd && !removed && !busy,
                  adding: addingAll || addingIndex == index,
                  onAdd: () => onAdd(index),
                  onOpen: () => onOpen(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LastOrderCard extends StatelessWidget {
  final LastOrderDish dish;
  final ShopFeedItemDto? live;
  final bool removed;
  final bool enabled;
  final bool adding;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  const _LastOrderCard({
    required this.dish,
    required this.live,
    required this.removed,
    required this.enabled,
    required this.adding,
    required this.onAdd,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = (live?.imageUrl ?? dish.imageUrl).trim();
    final price = live?.price ?? dish.price;
    final original = live?.originalPrice;
    final crossedOut =
        original != null && original > price && price > 0 ? original : null;
    final qty = dish.quantity > 0 ? dish.quantity : 1;

    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: removed ? null : onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dish Image with "Last Ordered" Tag and Floating + Button
                SizedBox(
                  height: 102,
                  width: 140,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: removed ? 0.45 : 1,
                        child: imageUrl.isEmpty
                            ? MenuImagePlaceholder(title: dish.name)
                            : CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 400,
                                placeholder: (_, _) =>
                                    const MenuImagePlaceholder(),
                                errorWidget: (_, _, _) =>
                                    MenuImagePlaceholder(title: dish.name),
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                              ),
                      ),

                      // "Ordered" Tag in top-left corner
                      Positioned(
                        left: 7,
                        top: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                PhosphorIcons.clockCounterClockwiseBold,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${qty}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Floating Add Button (+)
                      if (!removed)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Material(
                            color: enabled
                                ? AppColors.primary
                                : Colors.grey.shade400,
                            shape: const CircleBorder(),
                            elevation: 2.5,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: enabled ? onAdd : null,
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: adding
                                    ? const Padding(
                                        padding: EdgeInsets.all(6.5),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Dish Name & Price Info
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: removed
                              ? Colors.grey
                              : const Color(0xFF1E293B),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (removed)
                        Text(
                          context.tr('food.no_longer_available'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            height: 1.2,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                price.toFormattedPrice(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (crossedOut != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                crossedOut.toFormattedPrice(),
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                  height: 1.2,
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
      ),
    );
  }
}
