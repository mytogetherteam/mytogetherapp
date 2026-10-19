import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/menu_image_placeholder.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/price_formatter.dart';
import 'package:mytogetherapp/features/food/data/order_again.dart';
import 'package:mytogetherapp/features/home/data/models/shop_feed_item_dto.dart';

/// Grab-style "Your last order" row at the top of a restaurant menu.
class LastOrderStrip extends StatelessWidget {
  final List<LastOrderDish> dishes;
  final ShopFeedItemDto? Function(int menuItemId) liveItem;
  /// Ids that can still be ordered. `null` means the check did not finish,
  /// so a dish is gray only when the loaded menu already says it is unavailable.
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
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
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
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
          const SizedBox(height: 8),
          SizedBox(
            height: 196,
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

    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: removed ? null : onOpen,
            child: SizedBox(
              height: 112,
              width: 132,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 112,
                      width: 132,
                      child: Opacity(
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
                    ),
                  ),
                  if (!removed)
                    Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: enabled
                          ? AppColors.primary
                          : Colors.grey.shade400,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: enabled ? onAdd : null,
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: adding
                              ? const Padding(
                                  padding: EdgeInsets.all(6),
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
          ),
          const SizedBox(height: 6),
          Text(
            dish.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: removed ? Colors.grey : Colors.black,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 2),
          if (removed)
            Text(
              context.tr('food.no_longer_available'),
              maxLines: 2,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
              ),
              if (crossedOut != null) ...[
                const SizedBox(width: 6),
                Text(
                  crossedOut.toFormattedPrice(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
